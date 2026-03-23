#!/bin/bash
# kagent Bank Demo Environment Setup
# Run this 30 minutes before the demo call.
#
# Usage: ./setup.sh [apply|delete|status]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-apply}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_prerequisites() {
    info "Checking prerequisites..."

    if ! command -v kubectl &>/dev/null; then
        error "kubectl not found"; exit 1
    fi

    if ! kubectl cluster-info &>/dev/null; then
        error "Cannot reach cluster"; exit 1
    fi

    # Check kagent is running
    if kubectl get pods -n kagent -l app.kubernetes.io/name=kagent 2>/dev/null | grep -q Running; then
        info "kagent is running"
    else
        warn "kagent pods not found or not running in namespace 'kagent'"
    fi

    # Check Prometheus
    if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>/dev/null | grep -q Running; then
        info "Prometheus is running"
    else
        warn "Prometheus not found in 'monitoring' namespace — Scenario 3 (capacity forecasting) won't work"
        warn "Deploy with: kubectl apply -f $SCRIPT_DIR/prometheus-stack.yaml"
    fi
}

apply_demo() {
    info "Deploying bank demo environment..."

    # 1. Namespaces first
    kubectl apply -f "$SCRIPT_DIR/namespaces.yaml"
    info "Namespaces created"

    # 2. Demo workloads
    kubectl apply -f "$SCRIPT_DIR/resource-quotas.yaml"
    kubectl apply -f "$SCRIPT_DIR/crashloop-pod.yaml"
    kubectl apply -f "$SCRIPT_DIR/stateless-workloads.yaml"
    kubectl apply -f "$SCRIPT_DIR/istio-virtualservice.yaml" 2>/dev/null || warn "Istio CRDs not found — VirtualService not created (Scenario 4 needs Istio)"
    info "Demo workloads deployed"

    # 3. Prometheus MCP server + RemoteMCPServer CR
    kubectl apply -f "$SCRIPT_DIR/prometheus-mcp-server.yaml"
    kubectl apply -f "$SCRIPT_DIR/prometheus-mcp-remote.yaml"
    info "Prometheus MCP tool server deployed"

    # 4. Bank platform agent
    kubectl apply -f "$SCRIPT_DIR/bank-platform-agent.yaml"
    info "bank-platform-agent deployed"

    # 5. Wait for crashloop to start cycling
    info "Waiting for payment-service to enter CrashLoopBackOff..."
    sleep 15

    check_status
}

check_status() {
    echo ""
    info "=== Demo Environment Status ==="
    echo ""

    info "--- Namespaces ---"
    kubectl get ns finance-payments risk-management compliance-ops 2>/dev/null || warn "Some namespaces missing"
    echo ""

    info "--- finance-payments pods ---"
    kubectl get pods -n finance-payments -o wide 2>/dev/null || true
    echo ""

    info "--- risk-management pods ---"
    kubectl get pods -n risk-management -o wide 2>/dev/null || true
    echo ""

    info "--- compliance-ops pods ---"
    kubectl get pods -n compliance-ops -o wide 2>/dev/null || true
    echo ""

    info "--- kagent agents ---"
    kubectl get agents -n kagent 2>/dev/null || true
    echo ""

    info "--- MCP tool servers ---"
    kubectl get remotemcpservers -n kagent 2>/dev/null || true
    echo ""

    info "--- Prometheus MCP server ---"
    kubectl get pods -n kagent -l app=prometheus-mcp-server 2>/dev/null || true
    echo ""

    info "--- VirtualServices ---"
    kubectl get virtualservices -n finance-payments 2>/dev/null || warn "No VirtualServices (Istio CRDs may not be installed)"
    echo ""

    info "--- Resource Quotas ---"
    kubectl get resourcequota -A -l demo=bank 2>/dev/null || true
    echo ""

    # Verify crashloop is happening
    RESTART_COUNT=$(kubectl get pod -n finance-payments -l app=payment-service -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    if [ "$RESTART_COUNT" -gt 0 ]; then
        info "payment-service is crash-looping (restarts: $RESTART_COUNT) — ready for Scenario 1"
    else
        warn "payment-service has not restarted yet — give it a minute"
    fi

    # Verify bank-platform-agent exists
    if kubectl get agent bank-platform-agent -n kagent &>/dev/null; then
        info "bank-platform-agent registered — select it in kagent UI"
    else
        warn "bank-platform-agent not found"
    fi
}

delete_demo() {
    warn "Tearing down bank demo environment..."
    kubectl delete -f "$SCRIPT_DIR/bank-platform-agent.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/prometheus-mcp-remote.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/prometheus-mcp-server.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/istio-virtualservice.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/stateless-workloads.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/crashloop-pod.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/resource-quotas.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/namespaces.yaml" --ignore-not-found
    info "Demo environment cleaned up"
}

case "$ACTION" in
    apply)
        check_prerequisites
        apply_demo
        ;;
    delete|teardown|cleanup)
        delete_demo
        ;;
    status|check)
        check_status
        ;;
    *)
        echo "Usage: $0 [apply|delete|status]"
        exit 1
        ;;
esac
