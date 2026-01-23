#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="egov"
RESTART_WINDOW_SECONDS=600

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
