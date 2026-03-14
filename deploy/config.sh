#!/bin/bash
# Shared configuration for all deploy scripts.
# Source this file; do not execute it directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env.local for AGENT_SSH_KEY, AGENT_SERVER_IP, and API keys
if [ -f "$REPO_ROOT/.env.local" ]; then
  set +u  # .env.local may reference unset vars
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env.local"
  set -u
fi

# SSH key: AGENT_SSH_KEY env var (can be set in .env.local), or default path
SSH_KEY="${AGENT_SSH_KEY:-$HOME/.ssh/agent_ed25519}"

# Resolve the server IP from (in order):
#   1. First CLI argument passed to this function
#   2. AGENT_SERVER_IP env var
#   3. Terraform state file (infra/terraform.tfstate)
#   4. Empty string (caller should error)
resolve_server_ip() {
  local cli_arg="${1:-}"

  if [ -n "$cli_arg" ]; then
    echo "$cli_arg"
    return
  fi

  if [ -n "${AGENT_SERVER_IP:-}" ]; then
    echo "$AGENT_SERVER_IP"
    return
  fi

  local tfstate="$REPO_ROOT/infra/terraform.tfstate"
  if [ -f "$tfstate" ]; then
    local ip
    ip=$(python3 -c "
import json, sys
with open('$tfstate') as f:
    state = json.load(f)
for res in state.get('resources', []):
    if res.get('type') == 'hcloud_server':
        for inst in res.get('instances', []):
            ip = inst.get('attributes', {}).get('ipv4_address', '')
            if ip:
                print(ip)
                sys.exit(0)
" 2>/dev/null)
    if [ -n "$ip" ]; then
      echo "$ip"
      return
    fi
  fi

  echo ""
}
