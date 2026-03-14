# Server Setup Guide

> Disaster recovery / reproducible setup document.
> Infrastructure managed by Terraform in `infra/`.
> Last updated: 2026-03-14
>

## Prerequisites

- Hetzner Cloud account with API token
- SSH key pair at `~/.ssh/agent_ed25519`
- Terraform >= 1.5 (`brew install terraform`)
- hcloud CLI (`brew install hcloud`)
- Tailscale account (https://login.tailscale.com)
- API keys in `.env.local`: at minimum `ALIBABA_CODING_API_KEY` and `HETZNER_API_KEY`

See [Account Setup](account-setup.md) for detailed setup instructions for each service.

## Quick Start (Disaster Recovery)

If starting from scratch, run these steps in order:

### 1. Generate SSH key (if lost)

```bash
ssh-keygen -t ed25519 -C "agent@server" -f ~/.ssh/agent_ed25519 -N ""
```

### 2. Get Hetzner API token

- Hetzner Cloud Console: https://console.hetzner.cloud
- Project → Security → API Tokens → Generate (Read/Write)
- Save to `.env.local` as `HETZNER_API_KEY`
- Save to `infra/terraform.tfvars` as `hcloud_token = "..."`

### 3. Provision everything

```bash
cd infra
terraform init
terraform apply
```

This creates all three resources:
- **SSH key** uploaded to Hetzner
- **Firewall** (SSH + Tailscale UDP only)
- **Server** CAX31 with cloud-init bootstrap

Cloud-init automatically installs and configures:
- System updates + essential packages
- UFW firewall (SSH 22/tcp, Tailscale 41641/udp)
- Fail2Ban (SSH protection, 5 retries, 1hr ban)
- SSH hardening (password auth disabled)
- Docker
- Tailscale
- Unattended security upgrades

### 4. Wait for cloud-init to finish

```bash
ssh -i ~/.ssh/agent_ed25519 root@<IP> "cloud-init status --wait"
```

### 5. Connect Tailscale

```bash
ssh -i ~/.ssh/agent_ed25519 root@<IP> "tailscale up"
```

Follow the auth URL to join your tailnet.

### 6. Install OpenClaw (one-time)

SSH into the server and run the official setup:

```bash
cd /opt && git clone https://github.com/openclaw/openclaw.git openclaw-repo
cd openclaw-repo
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest OPENCLAW_GATEWAY_BIND=lan ./docker-setup.sh
```

**What docker-setup.sh does:**
- Pulls the OpenClaw Docker image
- Creates config dir at `~/.openclaw/` with subdirs (identity, agents, sessions)
- Generates a gateway auth token (random 64-char hex)
- Writes all settings to `/opt/openclaw-repo/.env`
- Runs interactive onboarding (accept the security prompt)
- Sets `gateway.mode=local` and `gateway.bind=lan`
- Configures `controlUi.allowedOrigins` for `127.0.0.1`
- Starts the `openclaw-gateway` container

**What it does NOT do:**
- Configure LLM providers or model routing (we overlay that)
- Pass custom env vars (API keys) into containers (we use a compose override)
- Set up HTTPS (we use Tailscale Serve)
- Pair browser devices (manual step after)

**Important:** Do not roll your own docker-compose.yml. The official one handles bind addresses,
port mapping, health checks, gateway commands, and the CLI service correctly.

### 7. Deploy our config overlay

```bash
cd deploy && ./deploy.sh
```

This pushes API keys, syncs our model config, and restarts the gateway.
See "Ongoing Deploys" below for what this does.

### 7.5 Workspace Bootstrapping

`deploy.sh` syncs files from the repo's `workspace/` directory into the server's
`/root/.openclaw/workspace/`. This seeds the agent with essential context on first deploy.

**What gets synced:**
- `MEMORY.md` — starts as a minimal template in the repo and grows over time as the agent
  accumulates context. The server-side copy diverges from the repo copy quickly.
- `BOOTSTRAP.md` — one-time orientation file. The agent reads it on first boot, then
  `deploy.sh` removes it after the first successful deploy.
- Other workspace files (personality docs, reference material) as needed.

**Workspace divergence:** The server-side workspace is the agent's live working directory.
It will diverge from the repo's `workspace/` directory as the agent creates files, updates
MEMORY.md, and accumulates session state. This is expected. The repo copy is just the
initial seed.

**Ownership:** Files synced via rsync arrive as root. `deploy.sh` runs
`chown -R 1000:1000 /root/.openclaw/workspace/` after sync so the container process
(which runs as UID 1000) can read and write them.

**Preserving memory across re-provisions:** If you need to tear down and recreate the
server (e.g., `terraform destroy` + `terraform apply`), save the agent's memory first:

```bash
# Before destroying the server
scp -i ~/.ssh/agent_ed25519 root@<IP>:/root/.openclaw/workspace/MEMORY.md ./workspace/MEMORY.md

# Then destroy and re-provision
cd infra && terraform destroy && terraform apply

# deploy.sh will sync the preserved MEMORY.md to the new server
```

### 8. Enable Tailscale HTTPS

The OpenClaw Control UI requires a secure context (HTTPS or localhost) for device identity
(Web Crypto API). Plain HTTP on a non-localhost IP won't work.

**Enable Serve on your tailnet** (one-time, in browser):
- When you first run `tailscale serve`, it may prompt you to enable the feature
- Visit the URL it gives you (e.g., `https://login.tailscale.com/f/serve?node=...`)
- Approve it

**Start the HTTPS proxy** (deploy.sh does this automatically, but for manual setup):

```bash
ssh -i ~/.ssh/agent_ed25519 root@<IP> "tailscale serve --bg 18789"
```

This makes `https://<your-tailscale-hostname>` proxy to `http://127.0.0.1:18789` with a
valid TLS certificate auto-provisioned by Tailscale. No nginx/caddy needed.

`tailscale serve` runs persistently (survives reboots via Tailscale daemon).

### 9. Pair your browser

On first visit to the Control UI, you'll see "pairing required". Your browser generates
a device identity and requests pairing.

**Approve the pairing request from the server:**

```bash
# SSH into server
./deploy/ssh.sh

# List devices (look for "Pending" section)
cd /opt/openclaw-repo && docker compose run --rm openclaw-cli devices list

# Approve the pending request
docker compose run --rm openclaw-cli devices approve <REQUEST_ID>
```

The request ID is a UUID shown in the "Pending" table. After approval, refresh the browser.

Each browser/device needs to be paired once. The pairing persists across restarts.

### 10. Set up hcloud CLI (optional, for ad-hoc management)

```bash
source .env.local && HCLOUD_TOKEN="$HETZNER_API_KEY" hcloud context create my-agent --token-from-env
```

## Ongoing Deploys

After first-time setup, `deploy/deploy.sh` handles everything:

```bash
cd deploy && ./deploy.sh
```

What it does:
1. Reads API keys from `.env.local`, upserts them into the server's `.env`
2. Syncs `docker-compose.override.yml` (passes API keys into containers as env vars)
3. Syncs `deploy/openclaw.json` overlay and merges it into server's config
   - Replaces `models` section (we own provider config)
   - Merges `agents.defaults` (preserves server-side compaction/sandbox settings)
   - Merges `gateway.controlUi.allowedOrigins` (additive)
   - Merges `browser` section
4. Ensures `tailscale serve` HTTPS proxy is running
5. Pulls latest Docker image and restarts the gateway

## SSH Access

```bash
ssh -i ~/.ssh/agent_ed25519 root@<SERVER_IP>
```

Add to `~/.ssh/config` for convenience:
```
Host my-agent
  HostName <SERVER_IP>
  User root
  IdentityFile ~/.ssh/agent_ed25519
```

## Infrastructure Details

### Terraform resources (`infra/main.tf`)

| Resource | Name | Purpose |
|----------|------|---------|
| `hcloud_ssh_key.agent` | agent | ED25519 key for SSH access |
| `hcloud_firewall.agent` | agent | Inbound: SSH (22/tcp) + Tailscale (41641/udp) |
| `hcloud_server.agent` | agent | CAX31 ARM64, Ubuntu 24.04, nbg1 |

### Server bootstrap (`infra/cloud-init.yml`)

Runs on first boot only. Installs:

| Component | Purpose |
|-----------|---------|
| UFW | Firewall: deny all inbound except SSH + Tailscale |
| Fail2Ban | SSH brute-force protection |
| Docker | Container runtime for OpenClaw |
| Tailscale | VPN tunnel to dev machines |
| unattended-upgrades | Automatic security patches |

### Security hardening

- SSH: key-only auth, password disabled
- Firewall: only ports 22 (SSH) and 41641 (Tailscale) open
- Fail2Ban: 5 failed attempts → 1 hour ban
- No services exposed to public internet
- OpenClaw accessed via Tailscale HTTPS only
- Gateway protected by auth token + device pairing

## Key Paths on Server

| Path | Purpose |
|------|---------|
| `/opt/openclaw-repo/` | Cloned OpenClaw repo with official docker-compose.yml |
| `/opt/openclaw-repo/.env` | Docker Compose env vars (gateway token, bind, API keys) |
| `/opt/openclaw-repo/docker-compose.yml` | Official compose (do not edit) |
| `/opt/openclaw-repo/docker-compose.override.yml` | Our override: passes API keys into containers |
| `/root/.openclaw/openclaw.json` | OpenClaw config (models, agents, gateway) |
| `/root/.openclaw/identity/` | Device identity keys |
| `/root/.openclaw/agents/` | Agent state and sessions |
| `/root/.openclaw/workspace/` | Agent workspace |

## Web UI Access

**Preferred:** `https://<your-tailscale-hostname>` (Tailscale HTTPS, secure context)

**Fallback:** SSH tunnel via `./deploy/tunnel.sh`, then `http://localhost:18789`

The Tailscale HTTPS URL requires:
- Tailscale Serve enabled on the tailnet
- `tailscale serve --bg 18789` running on the server (deploy.sh ensures this)
- The origin in `gateway.controlUi.allowedOrigins`
- Your browser device paired

## CLI Commands (on server)

```bash
cd /opt/openclaw-repo

# Container status
docker compose ps

# Logs (live)
docker compose logs -f openclaw-gateway

# Health check
docker compose exec openclaw-gateway node dist/index.js health --token "<GATEWAY_TOKEN>"

# List paired devices
docker compose run --rm openclaw-cli devices list

# Approve a device pairing request
docker compose run --rm openclaw-cli devices approve <REQUEST_ID>

# Add Telegram channel
docker compose run --rm openclaw-cli channels add --channel telegram --token <BOT_TOKEN>

# Restart gateway
docker compose restart openclaw-gateway

# Full teardown and restart
docker compose down && docker compose up -d openclaw-gateway
```

## Server Details

After provisioning, get your server's details:

```bash
cd infra && terraform output
```

## Tearing Down

```bash
cd infra
terraform destroy
```

This deletes the server, firewall, and SSH key from Hetzner.

## Gotchas / Lessons Learned

1. **Don't roll your own docker-compose.yml.** Use OpenClaw's official `docker-setup.sh`.
   It handles bind addresses, ports, origins, auth tokens, health checks, and the CLI
   service correctly. We tried a custom compose first and the UI didn't work.

2. **The official compose doesn't pass custom env vars.** API keys referenced as
   `${ALIBABA_CODING_API_KEY}` in `openclaw.json` need to be actual env vars inside the
   container. The official compose only passes OpenClaw-specific vars (gateway token, etc.).
   Solution: `docker-compose.override.yml` that adds our API key env vars to both
   `openclaw-gateway` and `openclaw-cli` services.

3. **OpenClaw Control UI requires a secure context.** The UI uses Web Crypto API for device
   identity, which browsers only allow on HTTPS or localhost. Accessing via a plain HTTP
   Tailscale IP gives "control ui requires device identity (use HTTPS or localhost secure
   context)". Solution: `tailscale serve` for auto-provisioned HTTPS.

4. **Tailscale Serve must be enabled on the tailnet first.** The first time you run
   `tailscale serve`, it may give a URL to visit to enable the feature on your tailnet.
   After that, it works immediately.

5. **Browser device pairing is required.** After first HTTPS access, the UI shows "pairing
   required". Approve via CLI: `docker compose run --rm openclaw-cli devices approve <ID>`.
   Each browser/device is paired once and persists.

6. **Config merge, not replace.** The server's `openclaw.json` has settings managed by
   OpenClaw itself (`meta`, `compaction`, `sandbox`, `commands`). Our deploy merges only
   the sections we own (`models`, `agents.defaults`, `browser`, `gateway.controlUi.allowedOrigins`)
   and preserves the rest.

7. **Gateway token is generated once by docker-setup.sh.** Stored in `/opt/openclaw-repo/.env`.
   Needed for the `?token=` query param on first UI access and for CLI health checks.
   The browser remembers it after initial auth + device pairing.

8. **docker-setup.sh is one-time only.** After initial setup, `deploy.sh` handles ongoing
   deploys. The cloned repo at `/opt/openclaw-repo` stays around for its docker-compose.yml
   but we never re-run docker-setup.sh.
