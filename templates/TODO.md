# {{AGENT_NAME}} - Task Tracker

> Read by Claude Code at session start. Update as tasks are completed.
> For larger efforts, create a plan in `docs/plans/`.

## Setup (complete these first)

- [ ] Fill in API keys in `.env.local` (at minimum `ALIBABA_CODING_API_KEY` and `HETZNER_API_KEY`)
- [ ] Add Hetzner API token to `infra/terraform.tfvars`
- [ ] Provision VPS: `cd infra && terraform init && terraform apply`
- [ ] Wait for cloud-init: SSH in and run `cloud-init status --wait`
- [ ] Connect Tailscale: SSH in and run `tailscale up`, follow the auth URL
- [ ] Install OpenClaw on server (see `docs/server-setup.md` step 6)
- [ ] Deploy: `./deploy/deploy.sh` (Alibaba fallback models work immediately; Codex primary needs OAuth in step below)
- [ ] Enable Tailscale HTTPS on server: `tailscale serve --bg 18789`
- [ ] Add your Tailscale hostname to `deploy/openclaw.json` under `gateway.controlUi.allowedOrigins`
- [ ] Re-deploy to apply the allowedOrigins change: `./deploy/deploy.sh`
- [ ] Pair browser device (see `docs/server-setup.md` step 9)
- [ ] Set up ChatGPT Plus OAuth for Codex (primary model — see `docs/account-setup.md` section 6)
- [ ] (Optional) Register Telegram channel on server (see `docs/account-setup.md` section 3)
- [ ] (Optional) Set up Twitter/X via xurl (see `docs/account-setup.md` section 4)
- [ ] Customize your agent's personality in `workspace/SOUL.md` and operating instructions in `workspace/AGENTS.md`
- [ ] (Optional) Add more LLM providers to `deploy/openclaw.json`

## Up Next

- [ ] Define your agent's first task or project

## Done
