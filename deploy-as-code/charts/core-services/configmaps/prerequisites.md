# Prerequisites

Before proceeding, ensure you have the following tools installed and configured on your system:

- **Helm**: (Package manager for Kubernetes)
- **Helmfile**: (Deploy Kubernetes Helm Charts)
- **SOPS**: (Secret Management)
- **age**: (Encryption tool)

## Configuration

To work with encrypted secrets, you must configure your `age` key.

### 1. Key Setup

Ensure you have your `age` secret key file (usually named `keys.txt` or similar).

### 2. Environment Variable

Export the `SOPS_AGE_KEY_FILE` environment variable to point to your key file location. This allows `sops` and `helmfile` to automatically decrypt secrets.

```bash
export SOPS_AGE_KEY_FILE=/path/to/your/keys.txt
```

> **Tip**: Add this line to your shell profile (`.bashrc` or `.zshrc`) to make it persistent.
