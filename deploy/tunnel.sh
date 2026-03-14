#!/bin/bash
# Open SSH tunnel to OpenClaw web UI
# Usage: ./tunnel.sh [server_ip]
# Then open http://localhost:18789 in your browser
#
# NOTE: Prefer Tailscale HTTPS (tailscale serve) instead.
# This tunnel is a fallback for when Tailscale Serve isn't available.

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

SERVER_IP=$(resolve_server_ip "${1:-}")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: No server IP. Pass as arg, set AGENT_SERVER_IP, or run terraform apply in infra/."
  exit 1
fi

TS_URL=$(ssh -i "$SSH_KEY" -o ConnectTimeout=5 "root@$SERVER_IP" \
  "tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(\"https://\" + json.load(sys.stdin)[\"Self\"][\"DNSName\"].rstrip(\".\"))'" 2>/dev/null) || true
if [ -n "$TS_URL" ]; then
  echo "Prefer: $TS_URL (Tailscale HTTPS)"
  echo ""
fi
echo "Tunneling OpenClaw UI to http://localhost:18789"
echo "Press Ctrl+C to stop"
ssh -N -L 18789:127.0.0.1:18789 -i "$SSH_KEY" "root@$SERVER_IP"
