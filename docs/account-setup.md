# Account Setup Guide

> Step-by-step runbooks for every external account needed to run an autonomous OpenClaw agent.
> Each section is self-contained — follow them in order for a fresh setup.

## TL;DR — What You Need

> Pricing as of March 2026. Verify current rates before subscribing.

| Service | What for | Cost | Section |
|---------|----------|------|---------|
| **ChatGPT Plus** | Primary LLM (Codex via OAuth) | $20/mo flat | [6](#6-chatgpt-plus-oauth-openai-codex) |
| **Alibaba Coding Plan** | Fallback LLMs + heartbeats | $3-10/mo | [7](#7-alibaba-cloud-coding-plan) |
| **Hetzner Cloud** | VPS hosting | ~$14/mo | [1](#1-hetzner-cloud) |
| **Tailscale** | VPN networking + HTTPS | Free | [2](#2-tailscale) |
| **GitHub** | Agent's code access | Free | [5](#5-github) |
| Telegram | Control channel (optional) | Free | [3](#3-telegram-bot) |
| Twitter/X | Public presence (optional) | ~$5/mo | [4](#4-twitterx-developer) |
| Anthropic | Claude fallback (optional) | Pay-as-you-go | [8](#8-anthropic-optional) |
| Fireworks AI | Alt Kimi K2.5 (optional) | Pay-as-you-go | [9](#9-fireworks-ai-optional) |

**Minimum to get running:** Hetzner + ChatGPT Plus + Alibaba Lite + Tailscale = **~$34-44/mo**.

---

## 1. Hetzner Cloud

VPS hosting for the OpenClaw server.

### Steps

1. Create an account at https://console.hetzner.cloud
2. Create a new project (e.g., "my-agent")
3. Go to **Security > API Tokens > Generate API Token**
4. Set permissions to **Read/Write**
5. Copy the token immediately (it's only shown once)

### Where to save

Add to `.env.local` at the repo root:

```
HETZNER_API_KEY=your_token_here
```

Add to `infra/terraform.tfvars`:

```hcl
hcloud_token = "your_token_here"
```

### Verification

```bash
HCLOUD_TOKEN="your_token_here" hcloud server-type list
```

If you see a list of server types, the token works.

---

## 2. Tailscale

VPN mesh network connecting the VPS to your local machines. Provides HTTPS for the OpenClaw Control UI.

### Steps

1. Create an account at https://login.tailscale.com
2. No API token is needed — authentication is interactive

### Usage

After the VPS is provisioned and Tailscale is installed (cloud-init handles this), SSH in and run:

```bash
tailscale up
```

Follow the URL it prints to authorize the node on your tailnet.

### Tailscale Serve (HTTPS)

The first time you run `tailscale serve` on the server, Tailscale may prompt you to enable the Serve feature on your tailnet. Visit the URL it provides and approve it. After that, `deploy.sh` handles starting the HTTPS proxy automatically.

### No ongoing credentials to manage

Tailscale uses device-based auth. Once a node joins your tailnet, it stays connected. No tokens to rotate.

---

## 3. Telegram Bot

Control channel for talking to your agent via Telegram.

### Steps

1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Choose a display name (e.g., "My Agent")
4. Choose a username (e.g., `myagent_bot`) — must end in `bot`
5. BotFather replies with your **bot token** (format: `123456:ABC-DEF...`)

### Where to save

Add to `.env.local`:

```
TELEGRAM_BOT_TOKEN=your_bot_token_here
```

### After deploy: register the channel

SSH into the server and register the bot with OpenClaw:

```bash
cd /opt/openclaw-repo
docker compose run --rm openclaw-cli channels add --channel telegram --token <YOUR_BOT_TOKEN>
```

### Pair yourself

1. Open your bot in Telegram and send `/start`
2. To get your Telegram user ID: forward any message to [@userinfobot](https://t.me/userinfobot) — it replies with your numeric ID
3. Your user ID is used for access control in the OpenClaw agent config (e.g., `agents.defaults.allowedUsers`)

### Gotcha

The bot token must also be passed as an env var into the container. `deploy.sh` handles this via the compose override, but if you're debugging manually, make sure `TELEGRAM_BOT_TOKEN` is in the server's `.env` file at `/opt/openclaw-repo/.env`.

---

## 4. Twitter/X Developer

Public-facing social media for your agent. Uses the `xurl` skill bundled with OpenClaw.

### Steps

1. Create an X account for your agent at https://x.com (e.g., @myagent)
2. Apply for developer access at https://console.x.com
   - Choose **Pay-Per-Use** plan (~$5/mo for Basic tier)
   - Basic tier provides enough for an autonomous agent's tweet volume
3. Create a new App in the developer portal
4. Under **Keys and Tokens**, generate:
   - **OAuth 1.0a Consumer Key** (API Key)
   - **OAuth 1.0a Consumer Secret** (API Secret)

### Generate access tokens

The consumer key/secret authenticate your *app*. You also need *user* access tokens for the bot account:

```bash
python3 scripts/twitter-oauth.py
```

This runs a local OAuth flow:
1. Opens your browser to X's authorization page
2. Log in as the bot account and click "Authorize app"
3. The script captures the callback and prints the access token + secret

See `scripts/README.md` for prerequisites (`pip install requests_oauthlib`).

### Configure xurl on the server

SSH into the server and run the xurl auth flow:

```bash
ssh -i ~/.ssh/agent_ed25519 root@<SERVER_IP>
xurl auth login
```

Paste the consumer key, consumer secret, access token, and access token secret when prompted.

Credentials are stored at `/root/.xurl/` on the host and mounted into the container via `docker-compose.override.yml`.

### Post-setup

- Update your bot's X profile to include "Automated by @YourMainAccount" (required by X's automation policy)
- The `xurl` binary is installed on the server by `deploy.sh` if not already present

### Gotcha

X developer tokens are **not** stored in `.env.local`. They live in the xurl config on the server. If you reprovision the server, you'll need to re-run `xurl auth login`.

---

## 5. GitHub

Version control access for the agent — lets it push code, create PRs, interact with repos.

### Generate SSH key

```bash
ssh-keygen -t ed25519 -C "agent@github" -f deploy/ssh/github_ed25519 -N ""
```

This creates:
- `deploy/ssh/github_ed25519` (private key, gitignored)
- `deploy/ssh/github_ed25519.pub` (public key)

### Create GitHub account

1. Create a GitHub account for your agent (e.g., `myagentbot`)
2. Go to **Settings > SSH and GPG Keys > New SSH key**
3. Paste the contents of `deploy/ssh/github_ed25519.pub`
4. Give it a title (e.g., "OpenClaw server")

### Generate a Personal Access Token (PAT)

1. Go to https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Select the `repo` scope (full control of private repositories)
4. Copy the token

### Where to save

Add to `.env.local`:

```
AGENT_GITHUB_PAT=ghp_your_token_here
```

### How it gets to the server

- `deploy.sh` syncs the SSH key to `/root/.openclaw/.ssh/` on the server
- `deploy.sh` pushes the PAT as `GITHUB_TOKEN` in the server's `.env` file
- The compose override passes `GITHUB_TOKEN` and `GIT_SSH_COMMAND` into the container
- Git identity is configured via `deploy/gitconfig`, synced to `/root/.openclaw/.gitconfig`

### Gotcha

The SSH key at `deploy/ssh/github_ed25519` is gitignored. If you lose it, generate a new one and re-add the public key to GitHub.

---

## 6. ChatGPT Plus OAuth (OpenAI Codex)

OpenAI Codex models (gpt-5.3-codex, codex-mini) via ChatGPT Plus subscription. This is the primary model provider — flat $20/mo for generous rate limits.

### Steps

1. Subscribe to ChatGPT Plus ($20/mo) at https://chatgpt.com
2. Deploy OpenClaw to the server first (the agent must be running)

### Auth flow (after deploy)

SSH into the server:

```bash
ssh -i ~/.ssh/agent_ed25519 root@<SERVER_IP>
cd /opt/openclaw-repo
docker compose exec openclaw-gateway openclaw models auth login --provider openai-codex
```

This prints an auth URL. You have two options to complete it:

**Option A: SSH tunnel (recommended)**

In a separate terminal on your local machine:

```bash
ssh -L 1455:localhost:1455 -i ~/.ssh/agent_ed25519 root@<SERVER_IP>
```

Then open the auth URL in your local browser. The OAuth callback goes to `localhost:1455`, which the tunnel forwards to the server.

**Option B: Copy URL**

Open the auth URL on any device, log in, and the server picks up the auth automatically.

### Token storage

Tokens are stored inside the container at:

```
~/.openclaw/agents/<agentId>/agent/auth-profiles.json
```

The token TTL is ~7 days and is auto-refreshed by OpenClaw. No manual rotation needed.

### Rate limits (Plus tier, per 5-hour window)

| Model | Messages |
|-------|----------|
| gpt-5.3-codex | 45-225 |
| codex-mini | 180-900 |

### Gotchas

- **Scope bug**: OpenClaw versions before 2026.3.7 had broken OAuth scopes (identity-only, no `model.request`). Make sure you're on 2026.3.7 or later.
- **Don't run Codex CLI simultaneously**: Running the standalone Codex CLI and OpenClaw on the same ChatGPT account causes token conflicts. Pick one.
- **No API key needed**: Auth is purely OAuth. No env var changes to `deploy.sh` or `docker-compose.override.yml`.

---

## 7. Alibaba Cloud Coding Plan

Bundled access to multiple models behind a single API key: Kimi K2.5, MiniMax M2.5, GLM-4.7/5, Qwen 3.5+.

### Steps

1. Sign up at https://www.alibabacloud.com
2. Navigate to **Model Studio** (https://www.alibabacloud.com/product/model-studio)
3. Subscribe to the **Coding Plan** (see [OpenClaw Coding Plan docs](https://www.alibabacloud.com/help/en/model-studio/openclaw-coding-plan))
   - Lite: $3 first month, $5 second, $10/mo steady-state (18k requests/mo)
   - Pro: $15 first month, $25 second, $50/mo steady-state (90k requests/mo)
   - Promo pricing available for new users (check current offers on the Alibaba signup page)
4. Generate an API key in the Model Studio dashboard

### Where to save

Add to `.env.local`:

```
ALIBABA_CODING_API_KEY=your_key_here
```

### What you get

One key covers all of these through Alibaba's routing:

| Model | Use case |
|-------|----------|
| Kimi K2.5 | Strong general model, fallback |
| MiniMax M2.5 | Cost-effective fallback |
| GLM-4.7 / GLM-5 | Heartbeats, lightweight tasks |
| Qwen 3.5+ | Subagent tasks (1M context, vision) |

### Verification

The key is used in `deploy/openclaw.json` model provider configs. After deploy, check the OpenClaw logs for successful model initialization:

```bash
ssh -i ~/.ssh/agent_ed25519 root@<SERVER_IP> \
  "cd /opt/openclaw-repo && docker compose logs openclaw-gateway | grep -i 'model\|provider'"
```

---

## 8. Anthropic (optional)

Claude models. Use sparingly — most expensive option.

### Steps

1. Create an account at https://console.anthropic.com
2. Go to **API Keys** and generate a key

### Where to save

Add to `.env.local`:

```
ANTHROPIC_API_KEY=sk-ant-your_key_here
```

### Credits billing (separate key)

If you have Anthropic credits (separate from the standard API billing), you can use a second key:

```
ANTHROPIC_CREDITS_API_KEY=sk-ant-your_credits_key_here
```

The model routing config in `deploy/openclaw.json` references both keys for different cost tiers (standard billing for normal use, credits for emergency fallback).

---

## 9. Fireworks AI (optional)

Alternative provider for Kimi K2.5 and other models. Useful as a fallback if Alibaba is down.

### Steps

1. Create an account at https://fireworks.ai
2. Go to **API Keys** and generate a key

### Where to save

Add to `.env.local`:

```
FIREWORKS_API_KEY=your_key_here
```

---

## Summary: .env.local template

After completing the steps above, your `.env.local` should look like:

```bash
# Required
HETZNER_API_KEY=your_hetzner_token

# LLM Providers
ALIBABA_CODING_API_KEY=your_alibaba_key    # Fallbacks + heartbeats
# ChatGPT Plus (Codex) uses OAuth — no API key needed

# Optional LLM Providers
# ANTHROPIC_API_KEY=sk-ant-your_key
# ANTHROPIC_CREDITS_API_KEY=sk-ant-your_credits_key
# FIREWORKS_API_KEY=your_fireworks_key

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...

# GitHub
AGENT_GITHUB_PAT=ghp_your_token

# Note: Twitter/X tokens are NOT in .env.local — they're in xurl config on the server
```

## Cross-references

- [Server Setup](server-setup.md) — full server provisioning and deploy guide
