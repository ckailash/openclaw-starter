#!/bin/bash
# Health check: verify openclaw-gateway is running on the server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SERVER_IP=$(resolve_server_ip "${1:-}")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: Cannot determine server IP."
  echo "Usage: $0 [server_ip]"
  echo "Or set AGENT_SERVER_IP, or have infra/terraform.tfstate present."
  exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
  echo "ERROR: SSH key not found at $SSH_KEY"
  exit 1
fi

echo "Checking openclaw-gateway on $SERVER_IP..."

STATUS=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
  "root@$SERVER_IP" \
  "cd /opt/openclaw-repo && docker compose ps --format '{{.Service}} {{.State}} {{.Health}}' 2>/dev/null | grep openclaw-gateway" \
  2>/dev/null) || true

if [ -z "$STATUS" ]; then
  echo "UNHEALTHY: openclaw-gateway not found in docker compose ps"
  echo ""
  echo "Last 20 log lines:"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    "root@$SERVER_IP" \
    "cd /opt/openclaw-repo && docker compose logs openclaw-gateway --tail 20 2>/dev/null" || echo "(could not fetch logs)"
  exit 1
fi

# Check if the service is running and healthy
if echo "$STATUS" | grep -qi "running"; then
  if echo "$STATUS" | grep -qi "unhealthy"; then
    echo "UNHEALTHY: openclaw-gateway is running but unhealthy"
    echo "Status: $STATUS"
    echo ""
    echo "Last 20 log lines:"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
      "root@$SERVER_IP" \
      "cd /opt/openclaw-repo && docker compose logs openclaw-gateway --tail 20 2>/dev/null" || echo "(could not fetch logs)"
    exit 1
  else
    echo "HEALTHY: $STATUS"
    exit 0
  fi
else
  echo "UNHEALTHY: openclaw-gateway is not running"
  echo "Status: $STATUS"
  echo ""
  echo "Last 20 log lines:"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    "root@$SERVER_IP" \
    "cd /opt/openclaw-repo && docker compose logs openclaw-gateway --tail 20 2>/dev/null" || echo "(could not fetch logs)"
  exit 1
fi
