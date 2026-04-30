# Kubernetes Environment - Rooster

> *"Talk to me, Goose."*
> *"Goose is dead. I'm Rooster now. And I brought Kubernetes."*

This repository contains Kubernetes configurations for the `maniak-rooster` Talos-based cluster, managed entirely via ArgoCD. It covers Longhorn storage, HashiCorp Vault, Istio service mesh, Ansible infrastructure automation, and supporting infrastructure.

## Repository Structure

```
k8s-rooster/
├── manifests/                    # ArgoCD app-of-apps (top-level Applications)
│   └── vault/                    # Vault + external-secrets ArgoCD applications
├── vault/                        # HashiCorp Vault + External Secrets Operator
│   ├── vault-application.yaml
│   └── external-secrets-application.yaml
├── external-secrets/             # ExternalSecret CRs (cluster secret store + per-namespace secrets)
│   ├── cluster-secret-store.yaml
│   ├── slack-secrets.yaml
│   └── kustomization.yaml
├── istio/                        # Istio service mesh ArgoCD applications
│   ├── istio-base-application.yaml
│   ├── istiod-application.yaml
│   ├── istio-cni-application.yaml
│   ├── ztunnel-application.yaml
│   ├── kiali-application.yaml
│   └── kustomization.yaml
├── monitoring/                   # Monitoring stack
│   └── prometheus-application.yaml
├── ansible/                      # Ansible playbooks + roles for infrastructure automation
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── archive/                      # Stale raw resource dumps (not referenced by ArgoCD)
├── scripts/                      # Utility scripts
│   └── vault-init.sh             # Vault initialization script
├── f5vip/                        # F5 BIG-IP VIP Terraform configs
│   ├── main.tf                   # Virtual servers, pools, pool members, monitors
│   ├── variables.tf              # BIG-IP connection + backend node variables
│   ├── outputs.tf                # VIP -> service mapping output
│   ├── provider.tf               # BIG-IP provider config
│   ├── versions.tf               # Terraform + provider version constraints
│   ├── terraform.tfvars.example  # Example credentials file
│   └── README.md                 # VIP assignment table + usage
├── docs/                         # Reference documentation and agent HTML pages
│   ├── architecture.html         # Architecture overview
│   ├── DEPLOYMENT_GUIDE.md       # Deployment guide
│   └── *.html                    # Per-agent documentation pages
├── issues/                       # Known issues and bug tracking
├── .github/workflows/            # GitHub Actions (Ansible deploy, F5 Terraform)
├── clean-configs.py              # Strips runtime metadata and sensitive data from captured YAML configs
└── README.md
```

## Architecture Overview

### Namespaces

| Namespace | Purpose |
|---|---|
| `argocd` | ArgoCD GitOps controller |
| `longhorn-system` | Longhorn distributed storage |
| `vault` | HashiCorp Vault + External Secrets Operator |
| `istio-system` | Istio service mesh (ambient mode) |
| `kiali` | Kiali service mesh dashboard |
| `monitoring` | Prometheus monitoring |

### Component Stack

- **HashiCorp Vault** — Secrets management with External Secrets Operator integration
- **Istio** — Service mesh (ambient mode with ztunnel + CNI) + Kiali dashboard
- **Prometheus** — Monitoring stack
- **Longhorn** — Distributed block storage

## ArgoCD Applications

| Application | Source Path | Namespace | Description |
|---|---|---|---|
| `vault-apps` | `vault/` | argocd | HashiCorp Vault + External Secrets Operator |
| `vault-external-secrets` | `external-secrets/` | various | ExternalSecret CRs (cluster store + per-namespace secrets) |

All applications use **auto-sync**, **selfHeal**, **prune**, and **ServerSideApply**.

## Quick Commands

```bash
# Check all ArgoCD apps
kubectl get applications -n argocd

# Check Vault status
kubectl get pods -n vault

# Check Istio sidecars
kubectl get pods -n istio-system

# Check Longhorn
kubectl get pods -n longhorn-system

# Force ArgoCD sync
kubectl annotate app <app-name> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## F5 BIG-IP VIPs

All services are exposed via F5 BIG-IP virtual servers using Layer 4 (fastL4) profiles, backed by Kubernetes NodePorts across all Talos nodes. Managed via Terraform in `f5vip/`.

| DNS | VIP IP | Port | Backend Service |
|-----|--------|------|-----------------|
| `argo.rooster.maniak.io` | 172.16.20.121 | 443/80 | argocd-server (NP 31988/32178) |
| `ui.rooster.maniak.com` | 172.16.20.130 | 80 | solo-enterprise-ui (NP 31211) |
| `vault.rooster.maniak.com` | 172.16.20.126 | 8200 | vault (NP 30820) |
| `kiali.rooster.maniak.com` | 172.16.20.127 | 20001 | kiali (NP 31094) |

**Pool members:** All 4 Talos nodes (172.16.10.130, .132, .133, .136)
**DNS:** Managed on FortiGate (172.16.10.1) DNS server for maniak.com and maniak.io zones
**BIG-IP:** 172.16.10.10 — **v21.0.0** (upgraded 2026-02-20)

```bash
cd f5vip/
cp terraform.tfvars.example terraform.tfvars  # add BIG-IP creds
terraform init && terraform apply
```

## Key Decisions

- **Vault-backed secrets** — External Secrets Operator pulls secrets from Vault into Kubernetes
- **ArgoCD with ServerSideApply** — required for CRDs that preserve unknown fields
- **F5 BIG-IP for ingress** — No Ingress Controller; L4 VIPs front NodePorts across all Talos nodes
- **Istio ambient mode** — ztunnel + CNI, no sidecar injection sidecars

---

**Last Updated**: April 30, 2026
**Cluster**: maniak-rooster (Talos)
**Cluster Name (mgmt)**: rooster.maniak.io
**Maintainer**: Seb (@ProfessorSeb)
