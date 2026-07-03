#!/bin/bash

# Configuration
NAMESPACE="egov"
SERVICE_ACCOUNT_NAME="egov-cluster-developer-sa"
SECRET_NAME="egov-cluster-developer-token"
OUTPUT_FILE="cluster-developer.kubeconfig"

# Get the current context
CONTEXT=$(kubectl config current-context)

# Get the cluster name from the context
CLUSTER_NAME=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CONTEXT\")].context.cluster}")

# Get the server URL
SERVER_URL=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.server}")

echo "Applying Cluster RBAC and Secret manifests..."
kubectl apply -f rbac.yaml
kubectl apply -f secret.yaml

echo "Waiting for token to be generated in secret..."
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
    if [ ! -z "$TOKEN" ]; then
        break
    fi
    echo "Still waiting for token... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to retrieve token from secret $SECRET_NAME in namespace $NAMESPACE."
    exit 1
fi

# Get CA certificate
CA_CERT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')

# Create the kubeconfig
cat <<EOF > $OUTPUT_FILE
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster:
    certificate-authority-data: $CA_CERT
    server: $SERVER_URL
contexts:
- name: cluster-developer
  context:
    cluster: $CLUSTER_NAME
    user: $SERVICE_ACCOUNT_NAME
current-context: cluster-developer
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: $TOKEN
EOF

echo "Cluster Kubeconfig generated: $OUTPUT_FILE"
echo "This profile has cluster-level permissions for deployments, pods, services, ingresses, configmaps, and secrets."
