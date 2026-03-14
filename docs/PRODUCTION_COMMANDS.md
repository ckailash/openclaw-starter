# Production Commands

All commands run from your local machine in the project root.

## Deploy

```bash
./deploy/deploy.sh
```

Pushes secrets from `.env.local`, syncs model config overlay, ensures Tailscale HTTPS proxy is running, pulls latest image, restarts gateway.

## Status

```bash
./deploy/status.sh
```

Shows container status (running, health, uptime).

## Logs

```bash
./deploy/logs.sh                    # all containers
./deploy/logs.sh openclaw-gateway   # gateway only
```

Shows last 50 lines of logs.

## SSH

```bash
./deploy/ssh.sh
```

Drops you into the server shell.

## Web UI

```bash
# Preferred: Tailscale HTTPS (requires Tailscale Serve enabled)
open https://<your-tailscale-hostname>

# Fallback: SSH tunnel
./deploy/tunnel.sh
open http://localhost:18789
```

## Device Pairing

When a new browser visits the UI for the first time:

```bash
./deploy/ssh.sh
cd /opt/openclaw-repo
docker compose run --rm openclaw-cli devices list      # find the pending request
docker compose run --rm openclaw-cli devices approve <REQUEST_ID>
```

## Infrastructure (Terraform)

```bash
cd infra
terraform plan     # preview changes
terraform apply    # apply changes
terraform destroy  # tear everything down
```

## Useful Docker commands (via SSH)

```bash
./deploy/ssh.sh
cd /opt/openclaw-repo

# Restart gateway
docker compose restart openclaw-gateway

# Full restart
docker compose down && docker compose up -d openclaw-gateway

# Watch logs live
docker compose logs -f openclaw-gateway

# Health check
docker compose exec openclaw-gateway node dist/index.js health --token "<GATEWAY_TOKEN>"

# Check resource usage
docker stats

# Add Telegram channel
docker compose run --rm openclaw-cli channels add --channel telegram --token <BOT_TOKEN>
```

## Server Details

> **Snapshot values** from the current deployment. These change on re-provision.
> Get current values: `cd infra && terraform output`

| Field | Value |
|-------|-------|
| IP | <SERVER_IP> |
| Tailscale IP | <TAILSCALE_IP> |
| Tailscale HTTPS | https://<your-tailscale-hostname> |
| SSH | `./deploy/ssh.sh` |
| Compose dir | `/opt/openclaw-repo/` (on server) |
| OpenClaw config | `/root/.openclaw/openclaw.json` (on server) |
| Secrets | `/opt/openclaw-repo/.env` (on server, pushed from `.env.local`) |
