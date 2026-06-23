# Gateway Service

Spring Cloud Gateway deployed as the API gateway for all backend services.

---

## Rate Limiting

The gateway uses Spring Cloud Gateway's **Redis token-bucket rate limiter**. Each backend service exposes three Kubernetes Service annotations that the gateway reads at runtime:

| Annotation | Values key | Description |
|---|---|---|
| `gateway-replenishRate` | `rateLimit.gatewayReplenishRate` | Tokens added back to the bucket per second |
| `gateway-burstCapacity` | `rateLimit.gatewayBurstCapacity` | Maximum tokens the bucket can ever hold |
| `gateway-requestedTokens` | `rateLimit.gatewayRequestedTokens` | Tokens each request costs (default: 1) |
| `gateway-keyResolver` | `rateLimit.gatewayKeyResolver` | Key resolver bean name (e.g. `userKeyResolver`, `otpKeyResolver`) |

These are configured per service in `environments/pucar-stg-config.yaml` under each service's `rateLimit:` block.

### Effective rate formula

```
effective rate = replenishRate / requestedTokens
```

The Redis limiter works natively in tokens-per-second. `requestedTokens` lets you express slower limits (e.g. per-minute) without a native per-minute knob:

```
effective rate = replenishRate (token/sec) ÷ requestedTokens (tokens/request)
              = req/sec
```

### Standard services (default)

Most services use:

```yaml
rateLimit:
  gatewayReplenishRate: "30"
  gatewayBurstCapacity: "30"
  gatewayRequestedTokens: "30"
```

```
effective rate = 30 / 30 = 1 req/sec per key
```

### Per-minute limiting trick — user-otp example

The token-bucket limiter has no native per-minute mode. To enforce **3 requests/minute** on the OTP endpoint (`/user-otp/**`):

```yaml
rateLimit:
  gatewayReplenishRate: "1"     # 1 token/sec refill
  gatewayBurstCapacity: "20"    # bucket max (must be >= requestedTokens)
  gatewayRequestedTokens: "20"  # each request costs 20 tokens
```

```
effective rate = 1 token/sec ÷ 20 tokens/request
              = 0.05 req/sec
              = 3 req/min  ✓
```

**How the cooldown works:**

- The bucket starts full at 20 tokens.
- One OTP request drains the bucket to 0.
- Tokens refill at 1/sec, so 20 seconds pass before the bucket holds 20 tokens again.
- Result: strictly **1 request per 20 seconds** (3/min), no bursting possible.

**Rejected requests (HTTP 429):**

- Blocked at the gateway — the backend never receives them and no OTP is generated/sent.
- Rejected requests do not consume tokens, so hammering the endpoint does not extend the lockout.
- The bucket keeps refilling at 1/sec regardless of rejections.
- Response includes `X-RateLimit-*` headers showing remaining tokens.

**Before / After for user-otp:**

| Param | Before | After |
|---|---|---|
| `replenishRate` | `3` | `1` |
| `burstCapacity` | `3` | `20` |
| `requestedTokens` | *(absent, default 1)* | `20` |
| Effective limit | 3 req/sec | 3 req/min |

### Constraint: burstCapacity ≥ requestedTokens

`burstCapacity` must be at least as large as `requestedTokens`. If it is smaller, the bucket can never accumulate enough tokens for a single request and **every call returns 429 immediately**.

Setting `burstCapacity == requestedTokens` (as in user-otp) means zero burst — one request at a time, evenly spaced.

---

## gateway-kubernetes-discovery init container

On startup, an init container (`gateway-kubernetes-discovery`) reads all Kubernetes Services in the namespace and generates a `routes.properties` file at `/etc/zuul/routes.properties`. The gateway uses this file to build its routing table.

The image tag is overridden per environment in `environments/pucar-stg-config.yaml`:

```yaml
gateway:
  initContainers:
    extraInitContainers: |
      - name: "gateway-kubernetes-discovery"
        image: {{ .Values.global.containerRegistry }}/gateway-kubernetes-discovery:<tag>
        ...
```

The default tag lives in `gateway/values.yaml`.
