#!/bin/bash
# Deploy OpenClaw to server
# Usage: ./deploy.sh [server_ip]
#
# First-time setup: run docker-setup.sh on the server (see docs/server-setup.md).
# This script handles ongoing deploys: syncs model config, pushes secrets, restarts.

set -euo pipefail

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

SERVER_IP=$(resolve_server_ip "${1:-}")
if [ -z "$SERVER_IP" ]; then
  echo "ERROR: No server IP. Pass as arg, set AGENT_SERVER_IP, or run terraform apply in infra/."
  exit 1
fi

REMOTE_COMPOSE_DIR="/opt/openclaw-repo"
REMOTE_CONFIG_DIR="/root/.openclaw"
ENV_LOCAL="$REPO_ROOT/.env.local"

SSH_CMD="ssh -i \"$SSH_KEY\" root@$SERVER_IP"

echo "Deploying to $SERVER_IP..."

# --- Secrets ---
if [ ! -f "$ENV_LOCAL" ]; then
  echo "ERROR: $ENV_LOCAL not found. Create it with your API keys."
  exit 1
fi

echo "Pushing secrets..."
# .env.local is already sourced by config.sh with set +u protection.

# Upsert API keys into the .env that docker-setup.sh created
$SSH_CMD "cd $REMOTE_COMPOSE_DIR && \
  grep -v '^ALIBABA_CODING_API_KEY=' .env | grep -v '^ANTHROPIC_API_KEY=' | grep -v '^ANTHROPIC_CREDITS_API_KEY=' | grep -v '^FIREWORKS_API_KEY=' | grep -v '^TELEGRAM_BOT_TOKEN=' | grep -v '^GITHUB_TOKEN=' > .env.tmp && \
  mv .env.tmp .env && \
  echo 'ALIBABA_CODING_API_KEY=${ALIBABA_CODING_API_KEY:-}' >> .env && \
  echo 'ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}' >> .env && \
  echo 'ANTHROPIC_CREDITS_API_KEY=${ANTHROPIC_CREDITS_API_KEY:-}' >> .env && \
  echo 'FIREWORKS_API_KEY=${FIREWORKS_API_KEY:-}' >> .env && \
  echo 'TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}' >> .env && \
  echo 'GITHUB_TOKEN=${AGENT_GITHUB_PAT:-}' >> .env"

# --- Compose override (passes API keys into containers) ---
echo "Syncing compose override..."
rsync -avz \
  -e "ssh -i $SSH_KEY" \
  "$SCRIPT_DIR/docker-compose.override.yml" \
  "root@$SERVER_IP:$REMOTE_COMPOSE_DIR/"

# --- Model config overlay ---
echo "Merging model config..."
rsync -avz \
  -e "ssh -i $SSH_KEY" \
  "$SCRIPT_DIR/openclaw.json" \
  "root@$SERVER_IP:/tmp/openclaw-overlay.json"

# Merge our models/agents config into the server's openclaw.json.
# Preserves server-side settings (meta, compaction, sandbox, commands) that
# docker-setup.sh or the gateway itself manage.
$SSH_CMD 'python3 -c "
import json

with open(\"/tmp/openclaw-overlay.json\") as f:
    overlay = json.load(f)

with open(\"'"$REMOTE_CONFIG_DIR"'/openclaw.json\") as f:
    config = json.load(f)

# Merge models section (full replace — we own model provider config)
if \"models\" in overlay:
    config[\"models\"] = overlay[\"models\"]

# Merge agents.defaults (preserve server-side compaction/sandbox settings)
if \"agents\" in overlay and \"defaults\" in overlay[\"agents\"]:
    if \"agents\" not in config:
        config[\"agents\"] = {}
    if \"defaults\" not in config[\"agents\"]:
        config[\"agents\"][\"defaults\"] = {}
    for key, val in overlay[\"agents\"][\"defaults\"].items():
        config[\"agents\"][\"defaults\"][key] = val

# Merge browser
if \"browser\" in overlay:
    config[\"browser\"] = overlay[\"browser\"]

# Merge gateway.controlUi.allowedOrigins from overlay
if \"gateway\" in overlay:
    gw = overlay[\"gateway\"]
    if \"controlUi\" in gw and \"allowedOrigins\" in gw[\"controlUi\"]:
        origins = config.get(\"gateway\", {}).get(\"controlUi\", {}).get(\"allowedOrigins\", [])
        for origin in gw[\"controlUi\"][\"allowedOrigins\"]:
            if origin not in origins:
                origins.append(origin)
        config.setdefault(\"gateway\", {}).setdefault(\"controlUi\", {})[\"allowedOrigins\"] = origins

with open(\"'"$REMOTE_CONFIG_DIR"'/openclaw.json\", \"w\") as f:
    json.dump(config, f, indent=2)

print(\"Config merged\")
"'

# --- Workspace files (personality, identity, operating instructions) ---
WORKSPACE_DIR="$SCRIPT_DIR/../workspace"
if [ -d "$WORKSPACE_DIR" ]; then
  echo "Syncing workspace files..."
  rsync -avz \
    -e "ssh -i $SSH_KEY" \
    "$WORKSPACE_DIR/" \
    "root@$SERVER_IP:$REMOTE_CONFIG_DIR/workspace/"
  # Remove BOOTSTRAP.md if our workspace files are present (we've done the bootstrap)
  $SSH_CMD "rm -f $REMOTE_CONFIG_DIR/workspace/BOOTSTRAP.md 2>/dev/null" || true
  # Fix ownership and permissions so the container (node, UID 1000) can read+write workspace
  $SSH_CMD "chown -R 1000:1000 $REMOTE_CONFIG_DIR/workspace/ && chmod -R u+rw $REMOTE_CONFIG_DIR/workspace/"
fi

# --- GitHub SSH key + git config ---
echo "Syncing GitHub SSH key and git config..."
$SSH_CMD "mkdir -p $REMOTE_CONFIG_DIR/.ssh && chmod 700 $REMOTE_CONFIG_DIR/.ssh"
rsync -avz \
  -e "ssh -i $SSH_KEY" \
  "$SCRIPT_DIR/ssh/" \
  "root@$SERVER_IP:$REMOTE_CONFIG_DIR/.ssh/"
rsync -avz \
  -e "ssh -i $SSH_KEY" \
  "$SCRIPT_DIR/gitconfig" \
  "root@$SERVER_IP:$REMOTE_CONFIG_DIR/.gitconfig"
$SSH_CMD "chmod 600 $REMOTE_CONFIG_DIR/.ssh/github_ed25519 && chown -R 1000:1000 $REMOTE_CONFIG_DIR/.ssh && chown 1000:1000 $REMOTE_CONFIG_DIR/.gitconfig"

# --- Ensure gh CLI is installed on host ---
echo "Checking gh CLI..."
if $SSH_CMD "which gh >/dev/null 2>&1"; then
  echo "gh already installed"
else
  echo "Installing gh CLI..."
  $SSH_CMD 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update -qq && apt-get install -y -qq gh'
fi

# --- Ensure xurl (X/Twitter CLI) is installed on host ---
echo "Checking xurl..."
if $SSH_CMD "which xurl >/dev/null 2>&1"; then
  echo "xurl already installed"
else
  echo "Installing xurl..."
  $SSH_CMD "curl -fsSL https://raw.githubusercontent.com/xdevplatform/xurl/main/install.sh | bash"
fi

# --- Ensure Tailscale HTTPS proxy is running ---
echo "Checking Tailscale HTTPS proxy..."
SERVE_STATUS=$($SSH_CMD "tailscale serve status 2>&1" || true)
if echo "$SERVE_STATUS" | grep -q "No serve config"; then
  echo "Starting Tailscale HTTPS proxy..."
  $SSH_CMD "tailscale serve --bg 18789"
else
  echo "Tailscale HTTPS proxy already running"
fi

# --- Restart ---
echo "Pulling latest image and restarting..."
$SSH_CMD "cd $REMOTE_COMPOSE_DIR && docker compose pull && docker compose up -d openclaw-gateway"

echo ""
echo "Done. Container status:"
$SSH_CMD "cd $REMOTE_COMPOSE_DIR && docker compose ps"
echo ""
TS_HOSTNAME=$($SSH_CMD "tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"Self\"][\"DNSName\"].rstrip(\".\"))'" 2>/dev/null || echo "unknown")
echo "Web UI: https://$TS_HOSTNAME"
