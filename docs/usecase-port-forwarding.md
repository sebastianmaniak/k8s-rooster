# Use Case 3: Ephemeral Port Forwarding — Access Sandbox Services from Your Browser

## Overview

Moat's port forwarding creates ephemeral TCP tunnels to any port inside a sandbox — just like `kubectl port-forward`, but for sandboxes. No firewall rules, no DNS, no persistent state. Open a tunnel, use it, close it — everything cleans up automatically.

## Architecture

```
  Browser / curl                    Sandbox (10.200.3.2)
  localhost:8080                    :8080 (Flask app)
       │                                 ▲
       ▼                                 │
  moatctl port-forward              TCP connect via
  abc-123 8080:8080                 veth pair
       │                                 │
       ▼                                 │
  gRPC bidirectional stream ────────────▶│
  (PortForwardRequest/Response)
```

## How It Works

1. **Client opens tunnel** — `moatctl port-forward <sandbox_id> 8080:8080` starts a local TCP listener on port 8080.

2. **Per-connection streaming** — Each incoming TCP connection opens a new bidirectional gRPC stream to the moat server.

3. **Server-side TCP connect** — The server validates the sandbox is running, connects to `sandbox_ip:target_port` through the veth pair, and proxies all data bidirectionally.

4. **Zero cleanup** — When the stream closes, everything is torn down. No nftables rules were created, no iptables entries, no agentgateway routes. Pure ephemeral.

## Demo Scenario

```
User: "Build a Flask dashboard and let me see it in my browser"

Agent (moat-sandbox-coder):
  1. create_sandbox(image: "python:3.12-slim")
  2. write_file("app.py", flask_dashboard_code)
  3. shell("pip install flask plotly && python app.py &")
  4. "Your dashboard is running on sandbox port 5000.
     Run: moatctl port-forward <sandbox-id> 5000:5000
     Then open http://localhost:5000 in your browser"

User runs the port-forward command, opens browser, sees live dashboard.
Closes the terminal → tunnel gone, no cleanup needed.
```

## Advanced: Multiple Concurrent Tunnels

```bash
# Terminal 1: Forward the web app
moatctl port-forward abc-123 8080:8080

# Terminal 2: Forward the database
moatctl port-forward abc-123 5432:5432

# Terminal 3: Forward the Redis cache
moatctl port-forward abc-123 6379:6379
```

Each tunnel is independent. Close one, the others keep running.

## Why This Matters

- **Zero configuration** — No DNS, no ingress, no firewall rules
- **Ephemeral by design** — Nothing to clean up, no state drift
- **Multiple tunnels** — Forward as many ports as you need, independently
- **Secure** — Traffic stays within the gRPC stream; sandbox network isolation is preserved
- **Works across the fleet** — Port forward to a sandbox on any host; the fleet routes it
