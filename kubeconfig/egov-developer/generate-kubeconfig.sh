#!/bin/bash

# Configuration
NAMESPACE="egov"
SERVICE_ACCOUNT_NAME="egov-developer-sa"
SECRET_NAME="egov-developer-token"
OUTPUT_FILE="qaconfig-devs"

# Get the current context
CONTEXT=$(kubectl config current-context)

# Get the cluster name from the context
CLUSTER_NAME=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CONTEXT\")].context.cluster}")

# Get the server URL
SERVER_URL=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.server}")

echo "Applying RBAC and Secret manifests..."
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
- name: $NAMESPACE-developer
  context:
    cluster: $CLUSTER_NAME
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT_NAME
current-context: $NAMESPACE-developer
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: $TOKEN
EOF

echo "Kubeconfig generated: $OUTPUT_FILE"
echo "You can now distribute this file to developers."
echo "They can use it by running: export KUBECONFIG=\$(pwd)/$OUTPUT_FILE"
