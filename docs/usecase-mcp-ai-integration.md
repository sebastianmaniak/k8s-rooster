# Use Case 4: MCP-Native AI Agent Integration — From Chat to Running Code in Seconds

## Overview

Moat exposes its entire API as an MCP (Model Context Protocol) server, making it a first-class tool for AI agents. Any MCP-compatible client — Claude Desktop, kagent, or custom agents — can create sandboxes, write code, execute it, manage snapshots, and clean up, all through natural language conversation.

## Architecture

```
  ┌──────────────────────────────────────────────────┐
  │  kagent Cluster (Kubernetes)                     │
  │                                                  │
  │  ┌─────────────┐    ┌──────────────────────┐     │
  │  │ Claude       │    │ AgentGateway         │     │
  │  │ Sonnet 4.6   │───▶│ (policies, tracing,  │     │
  │  │              │    │  JWT auth, PII guard) │     │
  │  └─────────────┘    └──────────┬───────────┘     │
  │                                │                  │
  │  ┌─────────────┐    ┌─────────▼────────────┐     │
  │  │ moat-sandbox │    │ RemoteMCPServer      │     │
  │  │ -coder Agent │───▶│ (STREAMABLE_HTTP)    │     │
  │  └─────────────┘    └──────────┬───────────┘     │
  └────────────────────────────────┼──────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  Moat MCP Server             │
                    │  (172.16.10.173:8000/mcp)    │
                    │                              │
                    │  15 tools:                   │
                    │  - Lifecycle (create/delete)  │
                    │  - Code (shell/run_code)      │
                    │  - Files (read/write/list)    │
                    │  - Snapshots (take/restore)   │
                    │  - Sessions (list/delete)     │
                    │  - Diagnostics (get_logs)     │
                    └──────────────────────────────┘
```

## The 15 MCP Tools

| Tool | Purpose |
|------|---------|
| `get_pool_status` | Pool capacity, active sandboxes, host health |
| `list_sandboxes` | All sandboxes with status, host, creation time |
| `create_sandbox` | Create with optional image, profile, labels |
| `get_sandbox` | Detailed sandbox info (IP, host, resource usage) |
| `delete_sandbox` | Clean teardown with resource release |
| `shell` | Execute any command inside the sandbox |
| `run_code` | Auto-lifecycle: create -> write -> run -> cleanup |
| `list_files` | Directory listing inside the sandbox |
| `read_file` | Read any file from the sandbox filesystem |
| `write_file` | Write files into the sandbox |
| `take_snapshot` | SHA-256 content-addressable workspace snapshot |
| `list_snapshots` | All snapshots with timestamps and sizes |
| `restore_snapshot` | Restore workspace to any previous snapshot |
| `list_sessions` | Named sessions for persistent work across conversations |
| `delete_session` | Clean up completed sessions |

## Demo Scenario: Full Development Workflow

```
User: "Create a REST API in Go that manages a todo list,
       with tests, and show me the test results"

Agent (moat-sandbox-coder):
  1. get_pool_status → "8/10 slots available, 3 hosts healthy"
  2. create_sandbox(image: "golang:1.24") → sandbox-abc on host-2
  3. write_file("main.go", go_api_code)
  4. write_file("main_test.go", go_test_code)
  5. write_file("go.mod", go_mod_contents)
  6. shell("go test -v ./...") → shows test output
  7. shell("go build -o todo-api && ./todo-api &")
  8. shell("curl -s localhost:8080/todos | jq .") → empty list
  9. shell("curl -s -X POST -d '{\"title\":\"Buy milk\"}' localhost:8080/todos")
  10. shell("curl -s localhost:8080/todos | jq .") → shows the todo
  11. take_snapshot("working-todo-api")
  12. "Your Go REST API is built, tested, and running.
       All 5 tests pass. Snapshot saved."
```

## Enterprise Security Layer

The kagent + AgentGateway stack wraps every MCP call with:
- **JWT authentication** — Only authorized agents can access moat tools
- **RBAC policies** — Scope which tools each agent can use
- **PII detection** — Prevent sensitive data from leaking into sandboxes
- **Prompt injection guard** — Block attempts to manipulate agent behavior
- **OpenTelemetry tracing** — Every tool call traced end-to-end through Langfuse

## Why This Matters

- **Natural language to running code** — No CLI, no SSH, no manual setup
- **Enterprise-grade security** — Every tool call passes through policy enforcement
- **Observable** — Full trace from user prompt to sandbox execution in Langfuse
- **Stateful** — Sessions and snapshots preserve work across conversations
- **Protocol-native** — MCP means any AI client can use moat, not just kagent
