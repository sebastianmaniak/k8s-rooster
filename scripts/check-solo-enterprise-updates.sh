#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required binary: $1" >&2
    exit 90
  }
}

require_bin gh
require_bin kubectl
require_bin python3

read_target_revision() {
  local file="$1"
  awk '/targetRevision:/ {print $2; exit}' "$file"
}

release_field() {
  local repo="$1"
  local endpoint="$2"
  local field="$3"
  gh api "repos/$repo/$endpoint" --jq ".${field}"
}

latest_prerelease_tag() {
  local repo="$1"
  gh api "repos/$repo/releases" --jq 'map(select(.prerelease == true)) | .[0].tag_name // empty'
}

latest_prerelease_published_at() {
  local repo="$1"
  gh api "repos/$repo/releases" --jq 'map(select(.prerelease == true)) | .[0].published_at // empty'
}

latest_prerelease_url() {
  local repo="$1"
  gh api "repos/$repo/releases" --jq 'map(select(.prerelease == true)) | .[0].html_url // empty'
}

normalize_version() {
  local version="$1"
  if [[ "$version" == v* ]]; then
    printf '%s\n' "${version#v}"
  else
    printf '%s\n' "$version"
  fi
}

version_gt() {
  python3 - "$1" "$2" <<'PY'
from packaging.version import Version
import sys

a = sys.argv[1].lstrip('v')
b = sys.argv[2].lstrip('v')
print('true' if Version(a) > Version(b) else 'false')
PY
}

KAGENT_APP="$REPO_ROOT/kagent/kagent-application.yaml"
KAGENT_CRDS_APP="$REPO_ROOT/kagent/kagent-crds-application.yaml"
KAGENT_MGMT_APP="$REPO_ROOT/kagent/kagent-mgmt-application.yaml"
AGENTGATEWAY_APP="$REPO_ROOT/kagent/enterprise-agentgateway-application.yaml"
AGENTGATEWAY_CRDS_APP="$REPO_ROOT/kagent/enterprise-agentgateway-crds-application.yaml"

kagent_current="$(read_target_revision "$KAGENT_APP")"
kagent_crds_current="$(read_target_revision "$KAGENT_CRDS_APP")"
kagent_mgmt_current="$(read_target_revision "$KAGENT_MGMT_APP")"
agentgateway_current="$(read_target_revision "$AGENTGATEWAY_APP")"
agentgateway_crds_current="$(read_target_revision "$AGENTGATEWAY_CRDS_APP")"

kagent_latest_stable_tag="$(release_field solo-io/kagent-enterprise releases/latest tag_name)"
kagent_latest_stable_published="$(release_field solo-io/kagent-enterprise releases/latest published_at)"
kagent_latest_stable_url="$(release_field solo-io/kagent-enterprise releases/latest html_url)"
kagent_latest_prerelease_tag="$(latest_prerelease_tag solo-io/kagent-enterprise)"
kagent_latest_prerelease_published="$(latest_prerelease_published_at solo-io/kagent-enterprise)"
kagent_latest_prerelease_url="$(latest_prerelease_url solo-io/kagent-enterprise)"

agentgateway_latest_stable_tag="$(release_field solo-io/agentgateway-enterprise releases/latest tag_name)"
agentgateway_latest_stable_published="$(release_field solo-io/agentgateway-enterprise releases/latest published_at)"
agentgateway_latest_stable_url="$(release_field solo-io/agentgateway-enterprise releases/latest html_url)"
agentgateway_latest_prerelease_tag="$(latest_prerelease_tag solo-io/agentgateway-enterprise)"
agentgateway_latest_prerelease_published="$(latest_prerelease_published_at solo-io/agentgateway-enterprise)"
agentgateway_latest_prerelease_url="$(latest_prerelease_url solo-io/agentgateway-enterprise)"

if [[ -n "$kagent_latest_prerelease_tag" ]] && { [[ "$kagent_latest_prerelease_tag" == "$kagent_latest_stable_tag" ]] || [[ "$(version_gt "$kagent_current" "$kagent_latest_prerelease_tag")" == "true" ]]; }; then
  kagent_latest_prerelease_tag=""
  kagent_latest_prerelease_published=""
  kagent_latest_prerelease_url=""
fi

if [[ -n "$agentgateway_latest_prerelease_tag" ]] && { [[ "$agentgateway_latest_prerelease_tag" == "$agentgateway_latest_stable_tag" ]] || [[ "$(version_gt "$agentgateway_current" "$agentgateway_latest_prerelease_tag")" == "true" ]]; }; then
  agentgateway_latest_prerelease_tag=""
  agentgateway_latest_prerelease_published=""
  agentgateway_latest_prerelease_url=""
fi

updates=()
if [[ "$(version_gt "$kagent_latest_stable_tag" "$kagent_current")" == "true" ]]; then
  updates+=("kagent stable ${kagent_current} -> ${kagent_latest_stable_tag}")
fi
if [[ "$(version_gt "$agentgateway_latest_stable_tag" "$agentgateway_current")" == "true" ]]; then
  updates+=("enterprise-agentgateway stable ${agentgateway_current} -> ${agentgateway_latest_stable_tag}")
fi
if [[ -n "$agentgateway_latest_prerelease_tag" ]] && [[ "$(version_gt "$agentgateway_latest_prerelease_tag" "$agentgateway_current")" == "true" ]]; then
  updates+=("enterprise-agentgateway prerelease ${agentgateway_current} -> ${agentgateway_latest_prerelease_tag}")
fi
if [[ -n "$kagent_latest_prerelease_tag" ]] && [[ "$kagent_latest_prerelease_tag" != "$kagent_latest_stable_tag" ]] && [[ "$(version_gt "$kagent_latest_prerelease_tag" "$kagent_current")" == "true" ]]; then
  updates+=("kagent prerelease ${kagent_current} -> ${kagent_latest_prerelease_tag}")
fi

validate_dirs=(
  "kagent"
  "agents"
  "models"
  "tool-servers"
  "policies"
  "gateways"
  "mcp"
)

validation_failures=()
validation_warnings=()
validation_ok=()
for dir in "${validate_dirs[@]}"; do
  stderr_file="$TMP_DIR/${dir//\//_}.stderr"
  if kubectl kustomize "$REPO_ROOT/$dir" >/dev/null 2>"$stderr_file"; then
    validation_ok+=("$dir")
    if [[ -s "$stderr_file" ]]; then
      first_warning="$(head -n 1 "$stderr_file")"
      validation_warnings+=("$dir: $first_warning")
    fi
  else
    failure_msg="$(tr '\n' ' ' < "$stderr_file" | sed 's/[[:space:]]\+/ /g' | sed 's/^ //; s/ $//')"
    validation_failures+=("$dir: ${failure_msg:-kubectl kustomize failed}")
  fi
done

status="ok"
exit_code=0
if (( ${#updates[@]} > 0 )) && (( ${#validation_failures[@]} > 0 )); then
  status="updates-and-validation-failures"
  exit_code=4
elif (( ${#updates[@]} > 0 )); then
  status="updates-available"
  exit_code=2
elif (( ${#validation_failures[@]} > 0 )); then
  status="validation-failures"
  exit_code=3
fi

cat <<EOF
STATUS: ${status}

Current pinned versions
- kagent chart: ${kagent_current}
- kagent CRDs chart: ${kagent_crds_current}
- kagent management chart: ${kagent_mgmt_current}
- enterprise-agentgateway chart: ${agentgateway_current}
- enterprise-agentgateway CRDs chart: ${agentgateway_crds_current}

Latest upstream releases
- kagent stable: ${kagent_latest_stable_tag} (${kagent_latest_stable_published})
  ${kagent_latest_stable_url}
- kagent prerelease: ${kagent_latest_prerelease_tag:-none} (${kagent_latest_prerelease_published:-n/a})
  ${kagent_latest_prerelease_url:-n/a}
- enterprise-agentgateway stable: ${agentgateway_latest_stable_tag} (${agentgateway_latest_stable_published})
  ${agentgateway_latest_stable_url}
- enterprise-agentgateway prerelease: ${agentgateway_latest_prerelease_tag:-none} (${agentgateway_latest_prerelease_published:-n/a})
  ${agentgateway_latest_prerelease_url:-n/a}
EOF

if (( ${#updates[@]} > 0 )); then
  echo
  echo "Detected upgrade candidates"
  for line in "${updates[@]}"; do
    echo "- ${line}"
  done
fi

if (( ${#validation_failures[@]} == 0 )); then
  echo
  echo "ArgoCD/GitOps render checks"
  echo "- All checked kustomizations rendered successfully: ${validation_ok[*]}"
else
  echo
  echo "ArgoCD/GitOps render failures"
  for line in "${validation_failures[@]}"; do
    echo "- ${line}"
  done
fi

if (( ${#validation_warnings[@]} > 0 )); then
  echo
  echo "Render warnings"
  for line in "${validation_warnings[@]}"; do
    echo "- ${line}"
  done
fi

exit "$exit_code"
