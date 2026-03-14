#!/bin/bash
# SSH into server
# Usage: ./ssh.sh [server_ip]

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

SERVER_IP=$(resolve_server_ip "${1:-}")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: No server IP. Pass as arg, set AGENT_SERVER_IP, or run terraform apply in infra/."
  exit 1
fi

ssh -i "$SSH_KEY" "root@$SERVER_IP"
