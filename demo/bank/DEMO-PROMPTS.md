# kagent Bank Demo — Prompts Cheat Sheet

> Use the **bank-platform-agent** in kagent UI for all scenarios.

---

## Scenario 1 — Crash Loop Diagnosis (3 min) — THE HOOK

**Prompt:**
```
There's a pod crash-looping in the finance-payments namespace. Can you diagnose what's going wrong and tell me the root cause?
```

**What kagent does:** describe pod → events → logs → finds NullPointerException + OOM at PaymentProcessor.java:314

**Follow-up (if time):**
```
What would you recommend to fix the OutOfMemoryError? Should we increase the heap or is the caching strategy the real problem?
```

---

## Scenario 2 — Migration Candidate Identification (3 min)

**Prompt:**
```
We're planning a workload migration to a new cluster. Which workloads across all namespaces are stateless and would be safe to migrate first?
```

**Expected:** kagent queries PVCs, correlates with pods, identifies risk-api and compliance-batch as stateless. Flags market-data-store as stateful.

**Follow-up:**
```
For risk-api specifically, what dependencies or risks should we be aware of before migrating it?
```

**Expected:** Checks resource quota, replicas, ConfigMaps, service dependencies, istio injection status.

---

## Scenario 3 — Cluster Capacity Forecasting (2 min)

> Requires Prometheus + kube-state-metrics (deploy prometheus-stack.yaml if not present)

**Prompt:**
```
Based on current resource consumption trends, when will this cluster run out of allocatable CPU or memory?
```

**What kagent does:** Queries Prometheus via the prometheus-mcp tool, analyses node metrics, projects fill date.

---

## Scenario 4 — Istio Troubleshooting (3 min)

**Prompt:**
```
The payment-service in finance-payments isn't receiving any traffic through the mesh. Can you check the Istio configuration and find what's wrong?
```

**Expected:** Checks VirtualServices, DestinationRules, Services. Finds payment-vs routes to payment-svc-v2 which doesn't exist as a k8s Service.

---

## Scenario 5 — Extensibility Teaser (2 min)

> Narrate this while showing kagent agent config screen. No live API call needed.

**Talking points:**
- "kagent supports custom MCP tool servers — we can wire any internal API"
- "Imagine adding your internal migration API as a tool"
- "Agent identifies candidate → human approves → API executes migration"
- "Same pattern works for Ansible Tower, ServiceNow, or any REST API"

---

## Pre-Demo Checklist (30 min before)

- [ ] `./setup.sh apply` — deploy everything
- [ ] `./setup.sh status` — verify all green
- [ ] payment-service is in CrashLoopBackOff with restarts > 2
- [ ] bank-platform-agent shows up in kagent UI
- [ ] prometheus-mcp-server pod is Running in kagent namespace
- [ ] kagent UI accessible and responsive
- [ ] Run Scenario 1 prompt once to warm up / verify output
- [ ] Observability dashboard shows agent traces
- [ ] Close unnecessary browser tabs / notifications

## Teardown

```bash
./setup.sh delete
```
