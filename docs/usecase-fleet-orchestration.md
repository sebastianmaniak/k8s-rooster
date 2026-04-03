# Use Case 1: Fleet-Wide Sandbox Orchestration with Automatic Host Scheduling

## Overview

Moat's fleet controller distributes sandboxes across a pool of bare-metal and VM hosts, automatically selecting the best host based on capacity, labels, and health. Combined with kagent on Kubernetes, AI agents can spin up isolated Linux environments on-demand without knowing or caring which physical machine runs them.

## Architecture

```
   kagent Agent (K8s)
         │
         ▼
   AgentGateway ──xDS routes──▶ Fleet Controller (Go)
         │                            │
         │                     ┌──────┼──────┐
         ▼                     ▼      ▼      ▼
   x-sandbox-id          Host A   Host B   Host C
   header routing         (bwrap)  (fc VM)  (bwrap)
         │                  │        │        │
         └──────────────────┘        │        │
                                     │        │
              sandbox-abc ◄──────────┘        │
              sandbox-def ◄───────────────────┘
```

## How It Works

1. **Host Registration** — Each Proxmox host runs `moat serve` with a fleet agent that auto-detects platform credentials (Kubernetes SA token, GCP identity token, or AWS SigV4) and registers with the fleet controller, reporting its capacity and labels.

2. **Lease-Based Health** — Hosts send periodic heartbeats. The controller tracks lease expiry and transitions hosts through Ready -> Suspect -> Dead. If a host goes dark, its sandboxes are cleaned up and xDS routes removed — no stale traffic.

3. **Scheduling** — When an agent calls `create_sandbox`, the fleet controller picks the least-loaded host matching label requirements, atomically reserves capacity in PostgreSQL, and writes an assignment. The host picks it up via streaming gRPC and creates the sandbox locally.

4. **xDS Routing** — The fleet controller pushes sandbox routes to AgentGateway via xDS. Clients send `x-sandbox-id` headers and get routed directly to the host running that sandbox — zero configuration, zero DNS entries.

## Demo Scenario

```
User: "Set up a Python data pipeline that processes CSV files"

Agent (moat-sandbox-coder):
  1. Calls create_sandbox → fleet schedules to least-loaded host
  2. Writes pipeline code via write_file
  3. Uploads test CSV, runs pipeline via shell
  4. Takes snapshot of working state
  5. Agent has no idea which host it ran on — fleet handled it
```

## Why This Matters

- **Zero-touch scaling** — Add a host, it registers, fleet uses it automatically
- **Self-healing** — Dead hosts are fenced, sandboxes rescheduled
- **Multi-cloud ready** — AWS, GCP, and bare-metal hosts authenticate natively
- **Unified API** — Agents see one pool, not individual machines
