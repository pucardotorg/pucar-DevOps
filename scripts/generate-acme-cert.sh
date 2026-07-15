#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Name: generate-acme-cert.sh
#
# Purpose:
#   Issue a Let's Encrypt certificate for an oncourts environment using the
#   acme-challenge pod's HTTP-01 webroot, then pull the resulting cert files
#   down to this machine.
#
# How it works:
#   1. Prompts you to pick an environment (pucar-stg / pucar-prod)
#   2. Validates that an Ingress in that namespace routes
#      /.well-known/acme-challenge to the acme-challenge Service/pod
#   3. Runs `certbot certonly --webroot` inside the acme-challenge pod's
#      certbot container (non-interactively, via kubectl exec - there's no
#      way to script keystrokes into an -it shell, so this runs the same
#      certbot command directly instead of exec'ing into "sh" first)
#   4. certbot's live/<domain>/*.pem files are symlinks into ../../archive/,
#      which would dangle if copied as-is without that archive tree. So
#      inside the pod we first dereference them (cp -L) into a flat
#      directory, then copy just that flat directory out.
#   5. Saves cert.pem as both cert.pem and cert.crt, then prints/opens the
#      local output folder.
#
# Requirements: kubectl (pointed at the right cluster/context), jq
#
# Usage:
#   ./generate-acme-cert.sh
#
# Env overrides:
#   CERTBOT_EMAIL   (default: test@gmail.com)
#   OUT_DIR         (default: ./certs)
###############################################################################

CERTBOT_EMAIL="${CERTBOT_EMAIL:-test@gmail.com}"
OUT_DIR="${OUT_DIR:-./certs}"
CHALLENGE_PATH="/.well-known/acme-challenge"
CONTAINER="certbot"
REMOTE_CERTBOT_DIR="/tmp/letsencrypt"
REMOTE_EXPORT_DIR="/tmp/cert-export"

# --- helpers -----------------------------------------------------------------
die() { echo "❌ $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found on PATH"
}

open_folder() {
  local dir=$1
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$dir" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$dir" >/dev/null 2>&1 &
  else
    echo "ℹ️  Open this folder manually: $dir"
  fi
}

require_cmd kubectl
require_cmd jq

# --- 1. environment selection -------------------------------------------------
echo "Select environment:"
echo "  1. pucar-stg   (oncourts-staging.kerala.gov.in)"
echo "  2. pucar-prod  (oncourts.kerala.gov.in)"
read -rp "Enter choice [1-2]: " CHOICE

case "$CHOICE" in
  1) NAMESPACE="backbone-stg";  DOMAIN="oncourts-staging.kerala.gov.in"; ENV_NAME="pucar-stg" ;;
  2) NAMESPACE="backbone-prod"; DOMAIN="oncourts.kerala.gov.in";         ENV_NAME="pucar-prod" ;;
  *) die "Invalid choice: $CHOICE" ;;
esac

echo ""
echo "Environment  : $ENV_NAME"
echo "Namespace    : $NAMESPACE"
echo "Domain       : $DOMAIN"
CURRENT_CTX=$(kubectl config current-context 2>/dev/null || echo "<none>")
echo "kube context : $CURRENT_CTX"
read -rp "Proceed with this kube context/namespace? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user"

# --- 2. validate ingress -> service -> pod ------------------------------------
echo ""
echo "🔍 Looking for an Ingress routing ${CHALLENGE_PATH} ..."

INGRESS_JSON=$(kubectl get ingress -n "$NAMESPACE" -o json)

MATCH=$(echo "$INGRESS_JSON" | jq -c --arg path "$CHALLENGE_PATH" '
  [.items[] as $ing |
   ($ing.spec.rules // [])[] as $rule |
   ($rule.http.paths // [])[] |
   select(.path == $path or (.path // "" | startswith($path))) |
   {ingress: $ing.metadata.name, host: ($rule.host // "*"), service: .backend.service.name}
  ] | first // empty
')

[[ -n "$MATCH" ]] || die "No Ingress in namespace '$NAMESPACE' routes ${CHALLENGE_PATH}. Deploy the acme-challenge chart first."

ING_NAME=$(echo "$MATCH" | jq -r .ingress)
ING_HOST=$(echo "$MATCH" | jq -r .host)
SVC_NAME=$(echo "$MATCH" | jq -r .service)

SELECTOR=$(kubectl get svc "$SVC_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.selector | to_entries | map("\(.key)=\(.value)") | join(",")')
[[ -n "$SELECTOR" ]] || die "Service '$SVC_NAME' has no selector"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$POD_NAME" ]] || die "No pod found behind service '$SVC_NAME' (selector: $SELECTOR)"

POD_PHASE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
[[ "$POD_PHASE" == "Running" ]] || die "Pod '$POD_NAME' is not Running (phase: $POD_PHASE)"

kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' | grep -qw "$CONTAINER" \
  || die "Pod '$POD_NAME' has no '$CONTAINER' container"

echo "✅ Ingress '$ING_NAME' (host: $ING_HOST) routes $CHALLENGE_PATH -> Service '$SVC_NAME' -> Pod '$POD_NAME' (Running)"

# --- 3. run certbot inside the pod --------------------------------------------
echo ""
echo "🔐 Requesting certificate for $DOMAIN via certbot in pod '$POD_NAME'..."

kubectl exec "$POD_NAME" -n "$NAMESPACE" -c "$CONTAINER" -- \
  certbot certonly \
    --webroot \
    -w /acme \
    -d "$DOMAIN" \
    --config-dir "$REMOTE_CERTBOT_DIR" \
    --work-dir "$REMOTE_CERTBOT_DIR" \
    --logs-dir "$REMOTE_CERTBOT_DIR" \
    --key-type rsa \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --non-interactive

echo "✅ Certificate issued in pod at ${REMOTE_CERTBOT_DIR}/live/${DOMAIN}/"

# --- 4. flatten symlinks, then copy files locally -----------------------------
echo ""
echo "📦 Flattening symlinked cert files inside the pod..."
kubectl exec "$POD_NAME" -n "$NAMESPACE" -c "$CONTAINER" -- \
  sh -c "mkdir -p '$REMOTE_EXPORT_DIR' && cp -L '$REMOTE_CERTBOT_DIR/live/$DOMAIN'/*.pem '$REMOTE_EXPORT_DIR/'"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOCAL_DIR="${OUT_DIR}/${DOMAIN}-${TIMESTAMP}"
mkdir -p "$LOCAL_DIR"

echo ""
echo "📥 Copying certificate files to $LOCAL_DIR ..."
kubectl cp "${NAMESPACE}/${POD_NAME}:${REMOTE_EXPORT_DIR}" "$LOCAL_DIR" -c "$CONTAINER"

if [[ -f "$LOCAL_DIR/cert.pem" ]]; then
  cp "$LOCAL_DIR/cert.pem" "$LOCAL_DIR/cert.crt"
  echo "✅ Saved cert.pem as cert.crt"
else
  echo "⚠️  cert.pem not found in copied output — check $LOCAL_DIR"
fi

# --- 5. done -------------------------------------------------------------------
echo ""
echo "🎉 Done. Certificate files:"
ls -la "$LOCAL_DIR"
echo ""
echo "📂 $LOCAL_DIR"
open_folder "$LOCAL_DIR"
