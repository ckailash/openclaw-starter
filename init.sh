#!/bin/bash
# Interactive setup script for creating a new autonomous AI agent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  OpenClaw Agent Setup"
echo "============================================"
echo ""
echo "This script will set up your autonomous AI agent."
echo ""

# --- Gather inputs ---

read -rp "Agent name (e.g., Atlas, Nova): " AGENT_NAME
if [ -z "$AGENT_NAME" ]; then
  echo "ERROR: Agent name is required."
  exit 1
fi

read -rp "Agent email (for git commits, e.g., agent@example.com): " AGENT_EMAIL
if [ -z "$AGENT_EMAIL" ]; then
  echo "ERROR: Agent email is required."
  exit 1
fi

read -rp "Twitter/X handle (optional, e.g., @myagent): " TWITTER_HANDLE
read -rp "GitHub username (optional): " GITHUB_USERNAME
read -rp "Owner name (your name): " OWNER_NAME
if [ -z "$OWNER_NAME" ]; then
  echo "ERROR: Owner name is required."
  exit 1
fi

echo ""

# --- Sed-safe substitution ---
# Escape sed special characters in user input to prevent injection.
sed_escape() {
  printf '%s' "$1" | sed 's/[&/\]/\\&/g'
}

SAFE_AGENT_NAME=$(sed_escape "$AGENT_NAME")
SAFE_AGENT_EMAIL=$(sed_escape "$AGENT_EMAIL")
SAFE_OWNER_NAME=$(sed_escape "$OWNER_NAME")
SAFE_TWITTER_HANDLE=$(sed_escape "$TWITTER_HANDLE")
SAFE_GITHUB_USERNAME=$(sed_escape "$GITHUB_USERNAME")

# Apply all placeholders to a template file and write to destination.
apply_template() {
  local src="$1"
  local dst="$2"
  sed -e "s/{{AGENT_NAME}}/$SAFE_AGENT_NAME/g" \
      -e "s/{{AGENT_EMAIL}}/$SAFE_AGENT_EMAIL/g" \
      -e "s/{{OWNER_NAME}}/$SAFE_OWNER_NAME/g" \
      -e "s/{{TWITTER_HANDLE}}/$SAFE_TWITTER_HANDLE/g" \
      -e "s/{{GITHUB_USERNAME}}/$SAFE_GITHUB_USERNAME/g" \
      "$src" > "$dst"
}

# --- Check for existing workspace files ---

WORKSPACE_EXISTS=false
if [ -d "$REPO_ROOT/workspace" ] && [ "$(ls -A "$REPO_ROOT/workspace/" 2>/dev/null)" ]; then
  WORKSPACE_EXISTS=true
  echo "WARNING: workspace/ already contains files. These will be overwritten."
  read -rp "Continue? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# --- Copy and customize workspace templates ---

echo ""
echo "Setting up workspace files..."
mkdir -p "$REPO_ROOT/workspace"

for f in SOUL.md IDENTITY.md USER.md AGENTS.md MEMORY.md; do
  if [ -f "$REPO_ROOT/templates/workspace/$f" ]; then
    apply_template "$REPO_ROOT/templates/workspace/$f" "$REPO_ROOT/workspace/$f"
    echo "  Created workspace/$f"
  else
    echo "  WARNING: templates/workspace/$f not found, skipping"
  fi
done

# --- CLAUDE.md ---

if [ -f "$REPO_ROOT/CLAUDE.md" ]; then
  echo ""
  echo "CLAUDE.md already exists. It may be customized."
  read -rp "Overwrite with template? [y/N] " CONFIRM_CLAUDE
  if [[ "$CONFIRM_CLAUDE" =~ ^[Yy]$ ]]; then
    apply_template "$REPO_ROOT/templates/CLAUDE.md" "$REPO_ROOT/CLAUDE.md"
    echo "  Replaced CLAUDE.md"
  else
    echo "  Kept existing CLAUDE.md"
  fi
else
  apply_template "$REPO_ROOT/templates/CLAUDE.md" "$REPO_ROOT/CLAUDE.md"
  echo "  Created CLAUDE.md"
fi

# --- TODO.md ---

if [ -f "$REPO_ROOT/TODO.md" ]; then
  echo ""
  echo "TODO.md already exists. It may contain task history."
  read -rp "Overwrite with setup checklist? [y/N] " CONFIRM_TODO
  if [[ "$CONFIRM_TODO" =~ ^[Yy]$ ]]; then
    apply_template "$REPO_ROOT/templates/TODO.md" "$REPO_ROOT/TODO.md"
    echo "  Replaced TODO.md"
  else
    echo "  Kept existing TODO.md"
  fi
else
  apply_template "$REPO_ROOT/templates/TODO.md" "$REPO_ROOT/TODO.md"
  echo "  Created TODO.md"
fi

# --- README.md ---

if [ -f "$REPO_ROOT/README.md" ]; then
  echo ""
  echo "README.md already exists."
  read -rp "Overwrite with template? [y/N] " CONFIRM_README
  if [[ "$CONFIRM_README" =~ ^[Yy]$ ]]; then
    apply_template "$REPO_ROOT/templates/README.md" "$REPO_ROOT/README.md"
    echo "  Replaced README.md"
  else
    echo "  Kept existing README.md"
  fi
else
  apply_template "$REPO_ROOT/templates/README.md" "$REPO_ROOT/README.md"
  echo "  Created README.md"
fi

# --- deploy/openclaw.json (model config) ---

if [ -f "$REPO_ROOT/deploy/openclaw.json" ]; then
  echo ""
  echo "deploy/openclaw.json already exists with custom model routing."
  read -rp "Overwrite with starter config (Codex primary + Anthropic fallback)? [y/N] " CONFIRM_MODELS
  if [[ "$CONFIRM_MODELS" =~ ^[Yy]$ ]]; then
    cp "$REPO_ROOT/templates/openclaw.json" "$REPO_ROOT/deploy/openclaw.json"
    echo "  Replaced deploy/openclaw.json"
  else
    echo "  Kept existing deploy/openclaw.json"
  fi
else
  cp "$REPO_ROOT/templates/openclaw.json" "$REPO_ROOT/deploy/openclaw.json"
  echo "  Created deploy/openclaw.json"
fi

# --- Git config ---

if [ -f "$REPO_ROOT/deploy/gitconfig" ]; then
  echo "  deploy/gitconfig already exists, skipping"
else
  if [ -f "$REPO_ROOT/templates/gitconfig" ]; then
    apply_template "$REPO_ROOT/templates/gitconfig" "$REPO_ROOT/deploy/gitconfig"
    echo "  Created deploy/gitconfig"
  fi
fi

# --- .env.local ---

if [ -f "$REPO_ROOT/.env.local" ]; then
  echo "  .env.local already exists, skipping"
else
  if [ -f "$REPO_ROOT/templates/env.example" ]; then
    cp "$REPO_ROOT/templates/env.example" "$REPO_ROOT/.env.local"
    echo "  Created .env.local from template"
  elif [ -f "$REPO_ROOT/deploy/.env.example" ]; then
    cp "$REPO_ROOT/deploy/.env.example" "$REPO_ROOT/.env.local"
    echo "  Created .env.local from deploy/.env.example"
  fi
fi

# --- terraform.tfvars ---

if [ -f "$REPO_ROOT/infra/terraform.tfvars" ]; then
  echo "  infra/terraform.tfvars already exists, skipping"
else
  if [ -f "$REPO_ROOT/infra/terraform.tfvars.example" ]; then
    cp "$REPO_ROOT/infra/terraform.tfvars.example" "$REPO_ROOT/infra/terraform.tfvars"
    echo "  Created infra/terraform.tfvars from example"
  fi
fi

# --- SSH keys ---

echo ""
echo "Setting up SSH keys..."

mkdir -p "$REPO_ROOT/deploy/ssh"

GITHUB_KEY="$REPO_ROOT/deploy/ssh/github_ed25519"
if [ -f "$GITHUB_KEY" ]; then
  echo "  GitHub SSH key already exists at $GITHUB_KEY, skipping"
else
  ssh-keygen -t ed25519 -C "agent@github" -f "$GITHUB_KEY" -N ""
  echo "  Generated GitHub SSH key: $GITHUB_KEY"
fi

SERVER_KEY="$HOME/.ssh/agent_ed25519"
if [ -f "$SERVER_KEY" ]; then
  echo "  Server SSH key already exists at $SERVER_KEY, skipping"
else
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "agent@server" -f "$SERVER_KEY" -N ""
  echo "  Generated server SSH key: $SERVER_KEY"
fi

# --- Summary ---

echo ""
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "Agent:  $AGENT_NAME"
echo "Email:  $AGENT_EMAIL"
echo "Owner:  $OWNER_NAME"
[ -n "$TWITTER_HANDLE" ] && echo "Twitter: $TWITTER_HANDLE"
[ -n "$GITHUB_USERNAME" ] && echo "GitHub:  $GITHUB_USERNAME"
echo ""
echo "Files generated:"
echo "  workspace/SOUL.md, IDENTITY.md, USER.md, AGENTS.md, MEMORY.md"
echo "  CLAUDE.md, TODO.md, README.md"
echo "  deploy/openclaw.json, deploy/gitconfig"
[ -f "$REPO_ROOT/.env.local" ] && echo "  .env.local"
[ -f "$REPO_ROOT/infra/terraform.tfvars" ] && echo "  infra/terraform.tfvars"
echo "  deploy/ssh/github_ed25519 (GitHub SSH key)"
echo "  ~/.ssh/agent_ed25519 (server SSH key)"
echo ""
echo "Next step: open Claude Code in this directory and paste:"
echo ""
echo "  Read CLAUDE.md and TODO.md, then walk me through setting up my agent."
echo ""
echo "Claude will guide you through API keys, provisioning, deployment, and pairing."
echo ""
echo "GitHub SSH public key (add to your agent's GitHub account):"
if [ -f "${GITHUB_KEY}.pub" ]; then
  cat "${GITHUB_KEY}.pub"
fi
echo ""
echo "Server SSH public key (added to VPS via Terraform cloud-init):"
if [ -f "${SERVER_KEY}.pub" ]; then
  cat "${SERVER_KEY}.pub"
fi
echo ""
