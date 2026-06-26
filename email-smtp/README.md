# SMTP Server — emailsmtp.pucar.org

Self-hosted mail stack for emailsmtp.pucar.org applications.

| Service | Image | Purpose |
|---|---|---|
| mailserver | docker-mailserver | Postfix MTA — SMTP ports 25 / 465 / 587 |
| roundcube | roundcube/roundcubemail | Web UI at https://emailsmtp.pucar.org |

Both containers join `docker-setup_egov-network` (the same network as the main docker-setup stack), so Caddy can reach Roundcube at `roundcube:80` without any host port binding.

---

## Traffic flow

```
Browser
  │  HTTPS :443
  ▼
VM nginx  (stream block — TLS passthrough, no termination)
  │  raw TCP → 127.0.0.1:10443
  ▼
Caddy  (sole TLS authority — auto-obtains and renews cert for emailsmtp.pucar.org)
  │  HTTP → roundcube:80  (on docker-setup_egov-network, by container name)
  ▼
Roundcube container  →  mailserver:993/465  (IMAP/SMTP, on docker-setup_egov-network)

Application SMTP (ports 25 / 465 / 587) — bypasses nginx and Caddy entirely,
bound directly to host. TLS cert is read from the caddy_data volume (shared
between the main docker-setup stack and this stack).
```

Port 80 ACME challenges for `emailsmtp.pucar.org`:
- nginx forwards `/.well-known/acme-challenge/` to Caddy at `127.0.0.1:10080`
- Caddy answers the challenge and stores the cert in the `caddy_data` named volume
- The mailserver reads the cert from that same volume (`SSL_TYPE: manual`)

---

## Prerequisites

- Main `docker-setup` stack is running (creates `docker-setup_egov-network` and `caddy_data`)
- Ports **25**, **465**, **587** open in the VM firewall
- Domain **emailsmtp.pucar.org** has an `A` record pointing to the VM IP

---

## Step 1 — DNS records

Add these records in your DNS provider before doing anything else. Cert issuance and mail delivery will fail without them.

| Type | Name | Value |
|---|---|---|
| A | `emailsmtp.pucar.org` | `<VM public IP>` |
| MX | `emailsmtp.pucar.org` | `emailsmtp.pucar.org` (priority 10) |
| TXT | `emailsmtp.pucar.org` (SPF) | `v=spf1 ip4:<VM public IP> ~all` |

DKIM and DMARC records are added in Step 7 after the mailserver starts.

### SPF record — how to add in Cloudflare

**Cloudflare → DNS → Records → Add record**

| Field | Value |
|---|---|
| Type | `TXT` |
| Name | `emailsmtp.pucar.org` |
| Content | `v=spf1 ip4:178.236.185.120 ~all` |
| TTL | Auto |

> **Do not use Cloudflare's SPF wizard.** It generates `include:emailsmtp.pucar.org` as the include — that subdomain has no SPF record of its own, so the include always fails. It also defaults to `+all` (allows anyone to send as your domain). Enter the raw TXT value manually instead.

**SPF values explained:**
- `ip4:178.236.185.120` — authorises the VM IP to send mail for `emailsmtp.pucar.org`
- `~all` — softfail: mail from other IPs is flagged but not rejected (safe starting point)
- `-all` — hardfail: mail from other IPs is rejected; switch to this after confirming delivery works

If you also send from Google Workspace, add `include:_spf.google.com` before the `~all`:
```
v=spf1 ip4:178.236.185.120 include:_spf.google.com ~all
```

Verify after DNS propagates:
```bash
dig TXT emailsmtp.pucar.org +short
# should include: "v=spf1 ip4:178.236.185.120 ~all"
```

---

## Step 2 — Install nginx site (VM nginx, not Docker)

Copy the nginx config to sites-enabled and reload:

```bash
# From the repo email-smtp/ directory
sudo cp nginx-emailsmtp.conf /etc/nginx/sites-enabled/emailsmtp.pucar.org

sudo nginx -t && sudo systemctl reload nginx
```

This config:
- Forwards `/.well-known/acme-challenge/` to Caddy at `127.0.0.1:10080` (so Caddy can obtain the TLS cert)
- Redirects all other port 80 traffic to HTTPS
- HTTPS passthrough is handled by the `stream` block in `/etc/nginx/nginx.conf` — Caddy receives the raw TLS connection and terminates it

> **Reference:** `nginx.conf.reference` in this directory shows the complete `/etc/nginx/nginx.conf` including the `stream {}` block with all SMTP ports. Use it as a guide when setting up the VM nginx from scratch.

### Port 587 (SMTP submission) — manual nginx.conf edit required

Port 587 is raw TCP (SMTP), not HTTP. It cannot go in the sites-enabled file. Add the following server blocks **inside the `stream { }` block** in `/etc/nginx/nginx.conf`:

```nginx
server {
    listen 25;
    proxy_pass 127.0.0.1:10025;  # Docker binds 127.0.0.1:10025:25
    proxy_timeout 3600s;
    proxy_connect_timeout 10s;
}
server {
    listen 465;
    proxy_pass 127.0.0.1:10465;  # Docker binds 127.0.0.1:10465:465
    proxy_timeout 3600s;
    proxy_connect_timeout 10s;
}
server {
    listen 587;
    proxy_pass 127.0.0.1:10587;  # Docker binds 127.0.0.1:10587:587
    proxy_timeout 3600s;
    proxy_connect_timeout 10s;
}
```

> **No port conflict:** Docker binds mailserver ports to offset ports on `127.0.0.1` (10025/10465/10587), so nginx can own the standard external ports (25/465/587) without conflict.

> **Why not Caddy?** Caddy is HTTP/HTTPS only. SMTP traffic bypasses Caddy entirely: `client :587 → nginx stream → mailserver :587 → Postfix (STARTTLS)`.

After editing:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## Step 3 — TLS (managed entirely by Caddy)

No manual cert issuance needed. Caddy automatically obtains and renews the TLS certificate for `emailsmtp.pucar.org` via ACME HTTP-01 the first time traffic hits it.

The cert is stored in the `caddy_data` named Docker volume. The mailserver mounts this same volume read-only (`SSL_TYPE: manual`) — both the web UI and SMTP TLS use the same certificate with a single renewal process.

**The mailserver checks for the cert on every startup and will crash-loop if it is missing.** Trigger Caddy to obtain the cert before starting the email-smtp stack:

```bash
# Trigger cert issuance
curl -I https://emailsmtp.pucar.org

# Verify the cert landed in the volume
docker run --rm -v caddy_data:/data alpine \
  ls /data/certificates/acme-v02.api.letsencrypt.org-directory/emailsmtp.pucar.org/
# Must show: emailsmtp.pucar.org.crt  emailsmtp.pucar.org.key
```

---

## Step 4 — Configure environment

Edit `.env` before starting the stack:

```bash
cd email-smtp
```

Required:
```env
# Generate with: openssl rand -hex 24
ROUNDCUBEMAIL_DES_KEY=<24-char hex string>
```

Optional (relay outbound mail through AWS SES, SendGrid, etc.):
```env
RELAY_HOST=[email-smtp.us-east-1.amazonaws.com]:587
RELAY_USER=AKIAIOSFODNN7EXAMPLE
RELAY_PASSWORD=your-ses-smtp-password
```

Leave `RELAY_HOST` empty to deliver directly via MX records.

---

## Step 5 — Start the stack

```bash
cd email-smtp
docker compose up -d
```

Check status:

```bash
docker compose ps
docker logs mailserver --tail 50
```

---

## Step 6 — Create mailbox accounts

The mailserver gives a **120-second window** after first startup to create at least one account. If the window closes with no accounts, Dovecot aborts and the container restarts. Add the account immediately:

```bash
docker exec -it mailserver setup email add emailsmtp-noreply@emailsmtp.pucar.org <strong-password>

# Additional addresses as needed
docker exec -it mailserver setup email add postmaster@emailsmtp.pucar.org <strong-password>
```

List all accounts:

```bash
docker exec -it mailserver setup email list
```

---

## Step 7 — Generate DKIM keys and fix signing table

`setup config dkim` only creates the private key when Rspamd is also enabled (it warns about a conflict and stops short of writing the public key file). Use `opendkim-genkey` directly instead:

```bash
docker exec -it mailserver sh

# Create key directory and generate keypair
mkdir -p /etc/opendkim/keys/emailsmtp.pucar.org
opendkim-genkey -D /etc/opendkim/keys/emailsmtp.pucar.org/ -d emailsmtp.pucar.org -s mail

# Fix permissions — opendkim-genkey creates the key owned by root (mode 600).
# OpenDKIM runs as the opendkim user and cannot read it without this fix.
chown opendkim:opendkim /etc/opendkim/keys/emailsmtp.pucar.org/mail.private

# The KeyTable and SigningTable in /etc/opendkim/ are created empty on first
# startup (before keys exist). Populate them manually:
echo "mail._domainkey.emailsmtp.pucar.org emailsmtp.pucar.org:mail:/etc/opendkim/keys/emailsmtp.pucar.org/mail.private" > /etc/opendkim/KeyTable
echo "*@emailsmtp.pucar.org mail._domainkey.emailsmtp.pucar.org" > /etc/opendkim/SigningTable

# Reload OpenDKIM to pick up the new config
supervisorctl restart opendkim

# Print the public key for DNS
cat /etc/opendkim/keys/emailsmtp.pucar.org/mail.txt
exit
```

The output looks like:
```
mail._domainkey IN TXT ( "v=DKIM1; h=sha256; k=rsa; "
        "p=MIIBIjANBgkq..." )
```

Join the quoted strings (strip line breaks and quote marks) and add as a DNS TXT record:

| Type | Name | Value |
|---|---|---|
| TXT | `mail._domainkey.emailsmtp.pucar.org` | `v=DKIM1; h=sha256; k=rsa; p=<full key>` |

Verify after DNS propagation:
```bash
dig TXT mail._domainkey.emailsmtp.pucar.org +short
```

> **Persistence:** `/etc/opendkim/` is bind-mounted to `./data/opendkim/` so changes written there (keys, KeyTable, SigningTable) survive restarts. After the first run the startup script seeds this directory; once you populate KeyTable and SigningTable with the `echo` commands above, those files persist on disk and OpenDKIM signing continues working across restarts.

---

## Step 8 — Add DMARC record

**Cloudflare → DNS → Records → Add record**

| Field | Value |
|---|---|
| Type | `TXT` |
| Name | `_dmarc.emailsmtp.pucar.org` |
| Content | `v=DMARC1; p=none; rua=mailto:postmaster@emailsmtp.pucar.org` |
| TTL | Auto |

Click **Save**.

Verify after DNS propagates:
```bash
dig TXT _dmarc.emailsmtp.pucar.org +short
# should return: "v=DMARC1; p=none; rua=mailto:postmaster@emailsmtp.pucar.org"
```

**DMARC policy explained:**
- `p=none` — monitoring only, no mail is rejected. Start here.
- `p=quarantine` — failed mail goes to spam. Switch to this after confirming SPF and DKIM both pass.
- `p=reject` — failed mail is rejected outright. Use only when fully confident in your setup.
- `rua=` — email address to receive aggregate DMARC reports (daily digest of pass/fail stats)

Once SPF and DKIM are confirmed passing, tighten the policy:

**Cloudflare → DNS → Records** — edit the `_dmarc.emailsmtp.pucar.org` TXT record, change content to:
```
v=DMARC1; p=quarantine; rua=mailto:postmaster@emailsmtp.pucar.org
```

---

## Step 9 — Verify Caddy and web UI

Restart Caddy after starting this stack so it picks up the `roundcube` container on the network:

```bash
cd docker-setup
docker compose restart caddy
```

`https://emailsmtp.pucar.org` should load the Roundcube login page.

---

## Step 10 — Test end-to-end mail delivery

Send a test mail from inside the mailserver container:

```bash
docker exec -it mailserver sh

# Port 587 + STARTTLS (correct for submission)
swaks --to test@gmail.com \
      --from emailsmtp-noreply@emailsmtp.pucar.org \
      --server localhost --port 587 \
      --auth LOGIN \
      --auth-user emailsmtp-noreply@emailsmtp.pucar.org \
      --auth-password <password> \
      --tls
```

> **Port note:** Port 465 uses implicit TLS (SSL from the start). If testing against port 465, use `--tlsc` instead of `--tls`. Port 587 + `--tls` (STARTTLS) is the modern standard and preferred.

In the mailserver logs, a successful send looks like:

```
opendkim: DKIM-Signature field added (s=mail, d=emailsmtp.pucar.org)   ← DKIM signing
postfix/smtp: status=sent (250 2.0.0 OK ...)                 ← Gmail accepted
```

---

## Connecting applications to the SMTP server

| Setting | Value |
|---|---|
| SMTP host | `emailsmtp.pucar.org` (external) or `mailserver` (from inside Docker) |
| SMTP port | `587` |
| Encryption | STARTTLS |
| Username | full email address, e.g. `emailsmtp-noreply@emailsmtp.pucar.org` |
| Password | set in Step 6 |
| From address | `emailsmtp-noreply@emailsmtp.pucar.org` |

For containers on `docker-setup_egov-network`, use `mailserver` as the hostname and port `587`.

---

## Known issues and workarounds

### DKIM KeyTable/SigningTable reset on container restart

`/etc/opendkim/` is bind-mounted to `./data/opendkim/` in the compose file, so any files written there persist across restarts.

However, the startup script creates empty `KeyTable` and `SigningTable` on the **very first run** (before any key exists). After running `opendkim-genkey` for the first time (Step 7), the echo commands write the correct content into the bind-mounted directory. From the second restart onwards, those files survive and OpenDKIM signing works without any manual intervention.

If DKIM stops signing after a restart, re-populate and reload:

```bash
docker exec -it mailserver sh
echo "mail._domainkey.emailsmtp.pucar.org emailsmtp.pucar.org:mail:/etc/opendkim/keys/emailsmtp.pucar.org/mail.private" > /etc/opendkim/KeyTable
echo "*@emailsmtp.pucar.org mail._domainkey.emailsmtp.pucar.org" > /etc/opendkim/SigningTable
supervisorctl restart opendkim
exit
```

### DKIM key permission denied — `can't load key: Permission denied`

`opendkim-genkey` creates `mail.private` owned by `root` with mode `600`. OpenDKIM runs as the `opendkim` user and cannot read it, causing every outbound mail to be rejected with:

```
opendkim: can't load key from /etc/opendkim/keys/emailsmtp.pucar.org/mail.private: Permission denied
opendkim: milter-reject: 4.7.1 Service unavailable - try again later
```

Fix:
```bash
docker exec -it mailserver sh
chown opendkim:opendkim /etc/opendkim/keys/emailsmtp.pucar.org/mail.private
supervisorctl restart opendkim
exit
```

This is already included in Step 7 but must be re-applied if keys are regenerated manually.

### Rspamd + OpenDKIM conflict warnings

The following warnings appear on every startup and are harmless — OpenDKIM wins and handles DKIM signing:

```
WARN: Running OpenDKIM & Rspamd at the same time is discouraged
WARN: Running OpenDMARC & Rspamd at the same time is discouraged
WARN: Running policyd-spf & Rspamd at the same time is discouraged
```

To silence them, add to the mailserver environment in `docker-compose.yaml`:
```yaml
ENABLE_OPENDKIM: "0"
ENABLE_OPENDMARC: "0"
ENABLE_POLICYD_SPF: "0"
```
But only do this if you have configured Rspamd's own DKIM signing — otherwise outgoing mail will be unsigned.

### sedfile errors on restart

Lines like `ERROR sedfile: No difference after call to 'sed'` are harmless. They appear because config substitutions were already applied on the first run.

---

## Useful commands

```bash
# Tail mail logs
docker logs -f mailserver

# Check Postfix queue
docker exec mailserver postqueue -p

# Flush queue (retry deferred messages)
docker exec mailserver postqueue -f

# List mailbox accounts
docker exec -it mailserver setup email list

# Reload OpenDKIM after config changes
docker exec mailserver supervisorctl restart opendkim

# Reload Postfix after config changes
docker exec mailserver postfix reload

# Force Caddy to renew the cert early
docker exec caddy-gateway caddy renew --force

# Reload mailserver to pick up renewed cert
docker exec mailserver postfix reload

# Inspect Caddy cert volume
docker run --rm -v caddy_data:/data alpine \
  ls /data/certificates/acme-v02.api.letsencrypt.org-directory/emailsmtp.pucar.org/

# Verify SPF record
dig TXT emailsmtp.pucar.org +short

# Verify DKIM public key in DNS
dig TXT mail._domainkey.emailsmtp.pucar.org +short

# Verify DMARC record
dig TXT _dmarc.emailsmtp.pucar.org +short
```

---

## Folder layout

```
email-smtp/
├── docker-compose.yaml       # mailserver + roundcube services
├── .env                      # relay credentials and Roundcube key
├── nginx-emailsmtp.conf      # VM nginx config — copy to /etc/nginx/sites-enabled/emailsmtp.pucar.org
├── README.md                 # this file
└── data/                     # created on first run by Docker
    ├── mail-data/            # mailbox storage
    ├── mail-state/           # Postfix/Dovecot state
    ├── mail-logs/            # mail logs
    ├── config/               # DKIM keys, OpenDKIM config, aliases
    └── roundcube/            # Roundcube SQLite database
```
