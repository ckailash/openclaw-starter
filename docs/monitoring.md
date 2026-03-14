# Monitoring & Health Checks

> How to verify the agent is running and options for automated monitoring.

## Manual Health Checks

### Container status

```bash
./deploy/status.sh
```

This SSHs into the server and runs `docker compose ps`, showing container state and health status.

The OpenClaw official `docker-compose.yml` includes a `HEALTHCHECK` directive on the gateway container. The `STATUS` column in `docker compose ps` shows one of:
- `healthy` — gateway is responding to health checks
- `unhealthy` — gateway is running but not responding
- `starting` — container just started, health check hasn't passed yet

### Logs

```bash
./deploy/logs.sh
```

Streams live gateway logs. Look for errors, model timeouts, or channel disconnections.

### SSH and inspect manually

```bash
./deploy/ssh.sh

# Once on the server:
cd /opt/openclaw-repo
docker compose ps              # container status + health
docker compose logs --tail 50  # recent logs
```

## Automatic Restart

The `docker-compose.override.yml` and the official compose file use `restart: unless-stopped` on the gateway container. This means:

- **Container crash**: Docker automatically restarts it
- **Server reboot**: Docker starts the container on boot (Docker daemon starts via systemd)
- **Manual stop**: Container stays stopped until you explicitly start it (`docker compose up -d`)

This covers most failure modes without any external monitoring. If the gateway process crashes, Docker brings it back within seconds.

## Future Monitoring Options

These are documented for future implementation. None are currently active.

### Cron healthcheck with Telegram alert

Run a cron job on the server that checks container health and sends a Telegram message if something is wrong.

```bash
# Example: /etc/cron.d/agent-healthcheck (runs every 5 minutes)
*/5 * * * * root /opt/agent-healthcheck.sh
```

```bash
#!/bin/bash
# /opt/agent-healthcheck.sh
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null)
if [ "$HEALTH" != "healthy" ]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="YOUR_CHAT_ID" \
    -d text="Agent health check failed: gateway is $HEALTH"
fi
```

Pros: Simple, no external dependencies. Cons: Can't detect if the entire server is down (cron won't run either).

### External pinger (UptimeRobot / Uptime Kuma)

Expose a health endpoint externally via Tailscale Funnel and monitor it with an external service.

```bash
# Enable Tailscale Funnel (makes the endpoint publicly accessible)
tailscale funnel --bg 18789
```

Then point UptimeRobot (https://uptimerobot.com, free tier: 50 monitors, 5-minute interval) at the public Funnel URL.

Pros: Detects full server outages. Cons: Exposes the gateway to the public internet (Funnel bypasses the tailnet). May want to expose only a specific health path rather than the full UI.

### Heartbeat canary

The agent's heartbeat system (configured in `openclaw.json`) runs periodic tasks. If the agent hasn't produced any heartbeat activity for >1 hour, something is likely wrong.

Detection approach:
- Check the agent's session logs or Telegram channel for recent messages
- If nothing in the last hour during expected active hours, alert

This is more of a "liveness from the agent's perspective" check — the container might be healthy but the agent might be stuck (e.g., all LLM providers down, rate limited, etc.).

### Summary of options

| Approach | Detects | Server-down detection | Effort |
|----------|---------|----------------------|--------|
| `docker compose ps` | Container health | No (manual) | None |
| `restart: unless-stopped` | Container crashes | N/A (auto-recovery) | Already done |
| Cron + Telegram | Container unhealthy | No | Low |
| External pinger | Server down, container down | Yes | Medium |
| Heartbeat canary | Agent stuck/unresponsive | No | Medium |

For most cases, Docker's restart policy handles failures automatically. Add external monitoring when uptime becomes critical for your use case.
