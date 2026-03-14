# OpenClaw Starter

Autonomous AI agent built on [OpenClaw](https://openclaw.ai). Runs 24/7 on a Hetzner VPS.

## Quick Start

1. Run `./init.sh` — interactive setup for your agent
2. Open [Claude Code](https://claude.ai/claude-code) in this directory and paste:
   ```
   Read CLAUDE.md and TODO.md, then walk me through setting up my agent.
   ```
3. Claude will guide you through API keys, VPS provisioning, deployment, and browser pairing

## Architecture

```
Hetzner CAX31 ($14/mo, 8 vCPU ARM, 16GB)
├── OpenClaw (Docker)
│   ├── Model routing (configure in deploy/openclaw.json)
│   ├── Channels: Telegram, Twitter/X, GitHub
│   ├── Browser automation (Playwright)
│   └── Heartbeat / cron system
└── Tailscale mesh → local dev machines
```

## Project Structure

```
├── deploy/                 # Deployment config (infra-as-code)
│   ├── deploy.sh           # Main deploy script
│   ├── config.sh           # Shared server IP + SSH key resolution
│   ├── openclaw.json       # Model config overlay
│   ├── docker-compose.override.yml
│   └── ssh/                # GitHub SSH keys (gitignored)
├── workspace/              # Agent identity (synced to container)
│   ├── SOUL.md             # Personality, beliefs, boundaries
│   ├── AGENTS.md           # Operating instructions
│   ├── IDENTITY.md         # Name and vibe
│   └── USER.md             # User profiles
├── docs/
│   ├── account-setup.md    # External service setup runbooks
│   └── server-setup.md     # Full server walkthrough
├── infra/                  # Terraform (Hetzner VPS)
├── templates/              # Generic templates (used by init.sh)
├── CLAUDE.md               # Instructions for Claude Code
└── TODO.md                 # Cross-session task tracker
```

## Deployment

```bash
./deploy/deploy.sh [server_ip]
```

The deploy script syncs secrets, merges model config, pushes workspace files, installs CLIs, and restarts the container. Idempotent — safe to run repeatedly.

## Docs

- [Account Setup](docs/account-setup.md) — set up all external services
- [Server Setup](docs/server-setup.md) — full server walkthrough
- [Monitoring](docs/monitoring.md) — health checks and auto-restart

