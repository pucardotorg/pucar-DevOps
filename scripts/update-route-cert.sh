#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Name: update-route-cert.sh
#
# Purpose:
#   Apply a previously-generated Let's Encrypt certificate (see
#   generate-acme-cert.sh) to the OpenShift edge Route that terminates TLS
#   for an oncourts environment, backing up whatever certificate/key/CA the
#   Route currently has before overwriting it.
#
# Route mapping:
#   pucar-stg  -> Route 'oncourts-staging' in namespace 'backbone-stg'
#   pucar-prod -> Route 'oncourts'         in namespace 'backbone-prod'
#
# Field mapping (Route spec.tls.* <- local file, in the directory you point
# this script at):
#   certificate   <- cert.pem
#   key           <- privkey.pem
#   caCertificate <- fullchain.pem
#
# The patch is written to a temp file and applied via --patch-file rather
# than -p '<json>' on the command line, since a cert+chain payload can be
# several KB and inline args get unwieldy (and truncation-prone on Windows).
#
# Requirements: kubectl (pointed at the right cluster/context), jq
#
# Usage:
#   ./update-route-cert.sh
#
# Env overrides:
#   BACKUP_DIR (default: ./certs-backup)
###############################################################################

BACKUP_DIR="${BACKUP_DIR:-./certs-backup}"

die() { echo "❌ $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found on PATH"; }

require_cmd kubectl
require_cmd jq

# --- 1. environment selection -------------------------------------------------
echo "Select environment:"
echo "  1. pucar-stg   (Route 'oncourts-staging' in namespace backbone-stg)"
echo "  2. pucar-prod  (Route 'oncourts' in namespace backbone-prod)"
read -rp "Enter choice [1-2]: " CHOICE

case "$CHOICE" in
  1) NAMESPACE="backbone-stg";  ROUTE_NAME="oncourts-staging"; ENV_NAME="pucar-stg" ;;
  2) NAMESPACE="backbone-prod"; ROUTE_NAME="oncourts";         ENV_NAME="pucar-prod" ;;
  *) die "Invalid choice: $CHOICE" ;;
esac

echo ""
echo "Environment  : $ENV_NAME"
echo "Namespace    : $NAMESPACE"
echo "Route        : $ROUTE_NAME"
CURRENT_CTX=$(kubectl config current-context 2>/dev/null || echo "<none>")
echo "kube context : $CURRENT_CTX"

kubectl get route "$ROUTE_NAME" -n "$NAMESPACE" >/dev/null 2>&1 \
  || die "Route '$ROUTE_NAME' not found in namespace '$NAMESPACE'"

read -rp "Proceed with this kube context/namespace/route? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user"

# --- 2. path to generated certs -----------------------------------------------
echo ""
read -rp "Path to the generated certificate directory (contains cert.pem, privkey.pem, fullchain.pem): " CERT_DIR
CERT_DIR="${CERT_DIR/#\~/$HOME}"

[[ -d "$CERT_DIR" ]] || die "Directory not found: $CERT_DIR"

CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/privkey.pem"
CA_FILE="$CERT_DIR/fullchain.pem"

for f in "$CERT_FILE" "$KEY_FILE" "$CA_FILE"; do
  [[ -f "$f" ]] || die "Missing expected file: $f"
done

echo "✅ Found cert.pem, privkey.pem, fullchain.pem in $CERT_DIR"

# --- 3. back up the route's current certificate --------------------------------
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${ROUTE_NAME}-${TIMESTAMP}"
mkdir -p "$BACKUP_PATH"

echo ""
echo "💾 Backing up current Route certificate to $BACKUP_PATH ..."
kubectl get route "$ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls.certificate}' | cat > "$BACKUP_PATH/cert.pem"
kubectl get route "$ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls.key}' | cat > "$BACKUP_PATH/privkey.pem"
kubectl get route "$ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tls.caCertificate}' | cat > "$BACKUP_PATH/fullchain.pem"

if [[ ! -s "$BACKUP_PATH/cert.pem" ]]; then
  echo "⚠️  Route had no existing certificate to back up (file is empty)."
fi
echo "✅ Backed up old certificate to $BACKUP_PATH"

# --- 4. apply the new certificate -----------------------------------------------
echo ""
echo "🔐 Applying new certificate to Route '$ROUTE_NAME'..."

PATCH_FILE=$(mktemp)
trap 'rm -f "$PATCH_FILE"' EXIT

jq -n \
  --rawfile cert "$CERT_FILE" \
  --rawfile key "$KEY_FILE" \
  --rawfile ca "$CA_FILE" \
  '{spec: {tls: {certificate: $cert, key: $key, caCertificate: $ca}}}' > "$PATCH_FILE"

kubectl patch route "$ROUTE_NAME" -n "$NAMESPACE" --type=merge --patch-file="$PATCH_FILE"

echo "✅ Route '$ROUTE_NAME' updated"

# --- 5. done ---------------------------------------------------------------------
echo ""
echo "🎉 Done."
echo "Route host        : $(kubectl get route "$ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
echo "Backup of old cert: $BACKUP_PATH"
