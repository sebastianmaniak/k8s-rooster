# Vertex AI gateway (on-prem / non-GKE)

This gateway config adds a Vertex AI backend + HTTPRoute.

## Auth (recommended for VMware/Talos/K3s/etc.)

Because this cluster is not GKE, the simplest approach is a **GCP service account key JSON** mounted into the agentgateway proxy pods.

Create a secret in `agentgateway-system`:

```bash
kubectl -n agentgateway-system create secret generic gcp-vertex-sa \
  --from-file=key.json=/path/to/vertex-service-account.json
```

This repo config mounts it at:

- `/var/secrets/google/key.json`

And sets:

- `GOOGLE_APPLICATION_CREDENTIALS=/var/secrets/google/key.json`

> Note: the volume is marked `optional: true` so existing gateways won't break if the secret isn't created yet.

## Configure the backend

Edit `backend.yaml`:
- `projectId`
- `region`
- `model`

## Call pattern

Once deployed, the route is:

- `http://<gateway-ip>:8080/vertex/v1/chat/completions`

(Depending on how you expose the `agentgateway-proxy` Gateway service in your environment.)
