#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Script Name: restart-service.sh
#
# Purpose:
#   Safely restart Kubernetes services in a dependency-aware order.
#
# How it works:
#   1. Restarts core dependency services FIRST:
#        - egov-user
#        - egov-mdms-service
#   2. Waits until each rollout is fully complete (blocking)
#   3. Restarts dependent services ONLY after core services are ready
#   4. Uses "restartedAt" annotation as a fallback to avoid unnecessary restarts
#
# Why this is needed:
#   Many services depend on egov-user and egov-mdms-service.
#   Restarting services out of order can lead to failures or bad state.
#
# Safety guarantees:
#   - No rollout timeouts (waits indefinitely until ready or failed)
#   - Safe to re-run (idempotent)
#   - Exits immediately on any error
#
# Usage:
#   chmod +x restart-service.sh
#   ./restart-service.sh
#
###############################################################################

NAMESPACE="egov"
RESTART_WINDOW_SECONDS=900  # 15 minutes

#######################################
# Phase 1: Core dependency services
#######################################
CORE_SERVICES=(
  egov-user
  egov-mdms-service
)

#######################################
# Phase 2: Dependent services
#######################################
DEPENDENT_SERVICES=(
  scheduler
  ab-diary
  case
  transformer
  openapi
  analytics
  order
  epost-tracker
  casemanagement
  task
  egov-access-control
  egov-hrms
)

#######################################
# Helpers
#######################################
was_restarted_recently() {
  local deployment=$1

  restartedAt=$(kubectl get deployment "$deployment" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.metadata.annotations.kubectl\.kubernetes\.io/restartedAt}' 2>/dev/null || true)

  if [ -z "$restartedAt" ]; then
    return 1
  fi

  restarted_epoch=$(date -d "$restartedAt" +%s)
  now_epoch=$(date +%s)

  (( now_epoch - restarted_epoch <= RESTART_WINDOW_SECONDS ))
}

restart_and_wait() {
  local deployment=$1

  echo "🔄 Restarting $deployment"
  kubectl rollout restart deployment "$deployment" -n "$NAMESPACE"

  echo "⏳ Waiting for $deployment rollout to complete"
  kubectl rollout status deployment "$deployment" -n "$NAMESPACE"

  echo "✅ $deployment is ready"
}

process_service() {
  local deployment=$1

  if was_restarted_recently "$deployment"; then
    echo "⏭️  $deployment restarted recently — skipping"
  else
    restart_and_wait "$deployment"
  fi
}

#######################################
# Execution
#######################################
echo "🚀 Starting dependency-aware restart"
echo "Namespace: $NAMESPACE"
echo "------------------------------------"

echo "🔑 Phase 1: Restarting core services"
for svc in "${CORE_SERVICES[@]}"; do
  process_service "$svc"
done

echo "------------------------------------"
echo "📦 Phase 2: Restarting dependent services"
for svc in "${DEPENDENT_SERVICES[@]}"; do
  process_service "$svc"
done

echo "------------------------------------"
echo "🎉 All services processed successfully"
