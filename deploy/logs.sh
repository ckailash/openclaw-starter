#!/bin/bash
# View OpenClaw logs
# Usage: ./logs.sh [container] [server_ip]
# Examples: ./logs.sh openclaw | ./logs.sh chromium | ./logs.sh (all)

CONTAINER="${1:-}"

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

SERVER_IP=$(resolve_server_ip "${2:-}")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: No server IP. Pass as arg, set AGENT_SERVER_IP, or run terraform apply in infra/."
  exit 1
fi

ssh -i "$SSH_KEY" "root@$SERVER_IP" "cd /opt/openclaw-repo && docker compose logs --tail=50 $CONTAINER"
