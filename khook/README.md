# khook Auth Proxy

## Problem

[khook](https://github.com/kagent-dev/khook) is a Kubernetes event watcher that triggers kagent agents via A2A when cluster events (pod restarts, OOM kills) are detected. It communicates with the kagent controller API to create sessions and send messages.

**kagent-enterprise** wraps the OSS controller with OIDC authentication middleware. khook makes direct server-to-server API calls without browser sessions or OIDC tokens, so all requests fail with `HTTP 400 "Failed to get user ID: no session found"`.

The enterprise controller's `AUTO_AUTH_ENABLED=true` only enables automatic OIDC auth for browser-based UI access — it does not help server-to-server clients.

## Solution

A lightweight Python reverse proxy sits between khook and the kagent-enterprise controller. It intercepts every request and injects:

1. **`Authorization: Bearer <k8s-sa-token>`** — the proxy's own Kubernetes ServiceAccount token, read from the standard mounted path
2. **`X-User-Id: admin`** — identity header that the enterprise controller uses for session ownership

The enterprise controller validates the K8s SA token via JWKS and accepts the combination for session creation, bypassing the OIDC requirement.

## Architecture

```
khook (port 8083)
  │
  ▼
khook-auth-proxy (port 8083)          ← Injects SA token + X-User-Id
  │
  ▼
kagent-controller (port 8083)         ← Enterprise controller validates token
  │
  ▼
Agent triggered via A2A
```

## Components

| File | Resource | Description |
|------|----------|-------------|
| `auth-proxy-script.yaml` | ConfigMap `khook-auth-proxy-script` | Python reverse proxy script |
| `auth-proxy-deployment.yaml` | ServiceAccount, Deployment, Service | Proxy runtime (python:3.12-slim) |
| `kustomization.yaml` | Kustomization | Bundles both resources |

## Configuration

The proxy is configured via environment variables in `auth-proxy-deployment.yaml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `UPSTREAM_URL` | `http://kagent-controller.kagent.svc.cluster.local:8083` | kagent controller URL |
| `USER_ID` | `admin` | Value injected as `X-User-Id` header |
| `SA_TOKEN_PATH` | `/var/run/secrets/kubernetes.io/serviceaccount/token` | Path to mounted SA token |
| `LISTEN_PORT` | `8083` | Proxy listen port (set via script default) |

## How khook Connects

The khook ArgoCD application (`kagent/khook-application.yaml`) points khook at the proxy instead of the controller directly:

```yaml
helm:
  valuesObject:
    kagent:
      apiUrl: http://khook-auth-proxy.kagent.svc.cluster.local:8083
      userId: admin@kagent.dev
```

## Deployment

Deployed via ArgoCD application `khook-auth-proxy` defined in `manifests/kagent/khook-auth-proxy-application.yaml`:

```yaml
source:
  repoURL: https://github.com/ProfessorSeb/k8s-rooster.git
  targetRevision: main
  path: khook
```

Auto-sync, prune, and selfHeal are enabled.

## Request Flow

1. Cluster event occurs (e.g., pod enters CrashLoopBackOff)
2. khook detects the event and matches it against configured hooks
3. khook sends `POST /api/sessions?user_id=admin` to the proxy
4. Proxy reads SA token from mounted file (cached by mtime)
5. Proxy strips existing `Authorization` and `X-User-Id` headers
6. Proxy injects `Authorization: Bearer <sa-token>` and `X-User-Id: admin`
7. Proxy forwards request to kagent-controller
8. Controller validates SA token, creates session, returns 201
9. khook sends A2A message to the target agent with event context

## Health Checks

The proxy runs a separate health server on port 8084:

- **Readiness:** `GET :8084/healthz` (3s initial delay, 5s period)
- **Liveness:** `GET :8084/healthz` (5s initial delay, 15s period)

## Troubleshooting

```bash
# Check proxy is running
kubectl get pods -n kagent -l app=khook-auth-proxy

# Check proxy logs (should show "Proxy ready" and SA token loaded)
kubectl logs -n kagent -l app=khook-auth-proxy

# Verify SA token is mounted
kubectl exec -n kagent deploy/khook-auth-proxy -- \
  wc -c /var/run/secrets/kubernetes.io/serviceaccount/token

# Test proxy health
kubectl exec -n kagent deploy/khook-auth-proxy -- \
  python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8084/healthz').read())"

# Check khook is pointed at proxy (not controller directly)
kubectl get configmap khook-config -n kagent -o jsonpath='{.data.config\.yaml}' | grep apiUrl
```

## Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 25m | 100m |
| Memory | 32Mi | 64Mi |
