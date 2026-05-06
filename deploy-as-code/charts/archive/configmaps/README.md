# ConfigMaps and Secrets Management

This chart manages the deployment of ConfigMaps and Secrets for the environment. It supports injecting sensitive data from encrypted helmfile secret files directly into Kubernetes Secrets.

## Requirements

Ensure your environment meets the following version requirements for compatibility:

* **Helm**: `v3.19.1` or later
* **Helmfile**: `v0.165.0` or later
* **Helm Plugin**: `helm-secrets` (v4.6.0 or later)
* **Helm Plugin**: `diff` (v3.10.0) - Preview helm upgrade changes as a diff

> **Note**: Please check [Prerequisites](prerequisites.md) for detailed tool installation and configuration guides.

## Secret Management Workflow

The secret management strategy relies on merging values from three sources:

1. **Chart Default Values** (`values.yaml`): Defines the `name` and `namespace` for the secret.
2. **Environment Values** (`solutions-<env>.yaml`): Can override defaults (though usually doesn't for secrets).
3. **Encrypted Secrets** (`solutions-<env>-secrets.yaml`): Contains the actual sensitive data (usernames, passwords, keys), encrypted with SOPS.

### Data Flow

1. **Encryption**: Sensitive data is stored in `solutions-<env>-secrets.yaml` files within the `environments` directory. These files are encrypted using SOPS.

    ```yaml
    # solutions-dev-secrets.yaml
    secrets:
      db:
        username: ENC[...]
        password: ENC[...]
    ```

2. **Merging**: When running `helmfile`, the encrypted secrets are decrypted/unlocked and merged with the chart's values.
    * `values.yaml` provides:

        ```yaml
        secrets:
          db:
            name: db
            namespace: egov
        ```

    * The merged result available to the chart looks like:

        ```yaml
        secrets:
          db:
            name: db
            namespace: egov
            username: <decrypted-username>
            password: <decrypted-password>
        ```

3. **Template Generation**: The templates in `templates/secrets/` iterate over these merged values to generate Kubernetes Secret manifests.

    * Example Template (`templates/secrets/db-secrets.yaml`):

        ```yaml
        {{- with index .Values "secrets" "db" }}
        apiVersion: v1
        kind: Secret
        metadata:
          name: {{ .name }}
          namespace: {{ .namespace }}
        data:
          username: {{ .username | b64enc | quote }}
          password: {{ .password | b64enc | quote }}
        {{- end }}
        ```

## How to Add a New Secret

To add a new secret to the deployment:

1. **Update Chart Values (`values.yaml`)**:
    Add an entry for your new secret to define its metadata (name and namespace).

    ```yaml
    secrets:
      my-new-service:
        name: my-new-service-secret
        namespace: egov
    ```

2. **Update ConfigMap Templates**:
    Create a new template file in `templates/secrets/my-new-service.yaml`.

    ```yaml
    {{- with index .Values "secrets" "my-new-service" }}
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ .name }}
      namespace: {{ .namespace }}
    type: Opaque
    data:
      api-key: {{ .apiKey | b64enc | quote }}
    {{- end }}
    ```

    **Alternative: Using `stringData`** (Avoids manual base64 encoding in the template):

    ```yaml
    {{- with index .Values "secrets" "my-new-service" }}
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ .name }}
      namespace: {{ .namespace }}
    type: Opaque
    stringData:
      api-key: {{ .apiKey | quote }}
    {{- end }}
    ```

3. **Add Encrypted Values**:
    Edit the `solutions-<env>-secrets.yaml` file for your target environment using `sops`.

    ```bash
    sops solutions-dev-secrets.yaml
    ```

    Add the sensitive data under the same hierarchy:

    ```yaml
    secrets:
      my-new-service:
        apiKey: "super-secret-value"
    ```

4. **Deploy**:
    Run your deployment command (e.g., `helmfile sync` or `apply`). The values will correspond, and the Kubernetes Secret will be created with the decrypted data.

## Working with Encrypted Secrets (SOPS)

To verify usage or edit secrets, you will use the `sops` CLI.

> **Prerequisite**: Ensure you have configured your `SOPS_AGE_KEY_FILE` environment variable pointing to your age private key.

### Editing Secrets

To edit an existing encrypted file (decrypt -> edit -> encrypt):

```bash
sops <path-to-file>
# Example:
sops ../../environments/solutions-dev-secrets.yaml
```

This opens the file in your default editor. Upon saving and exiting, `sops` automatically re-encrypts the file.

### Adding New Values

1. Run the edit command above.
2. Add your new key-value pairs in the YAML structure.

    ```yaml
    secrets:
      my-new-service:
        apiKey: "my-plain-text-value"
    ```

3. Save and close the editor. SOPS will encrypt the new values.

## Verification

To verify how the secrets will be formatted and injected into the Kubernetes manifests without applying them, use `helm template`.

Since secrets are injected via values, you can simulate this by passing the secrets file (if you have a decrypted copy) or by creating a dummy values file.

**Dry Run with Helm (using actual environment files):**

To verify with actual encrypted secrets and environment values, use the `helm secrets` plugin (wrapper for `helm`).

```bash
# Verify using the sample environment values
helm template configmaps . \
    -f values.yaml \
    -f ../../environments/sample.yaml \
    -f ../../environments/sample-secret.yaml
```

**Note**: You must have the `helm-secrets` plugin installed and your SOPS key configured for this to work.

Check the output to ensure the `Secret` resource is generated correctly with Base64 encoded values.
