# Scripts

## twitter-oauth.py

One-time OAuth 1.0a flow to obtain access tokens for an X/Twitter account.

### Prerequisites

- Python 3.10+
- `pip install requests_oauthlib`
- X developer app credentials in `.env.local` (or as environment variables):
  ```
  X_CONSUMER_KEY=your_consumer_key
  X_CONSUMER_SECRET=your_consumer_secret
  ```
  Get these from https://console.x.com → your app → Keys and Tokens.

### Usage

```bash
python3 scripts/twitter-oauth.py
```

1. The script reads `X_CONSUMER_KEY` and `X_CONSUMER_SECRET` from `.env.local`.
2. Your browser opens to the X authorization page. Log in as the bot account and click "Authorize app".
3. X redirects to `localhost:3000/callback`, where the script captures the verifier.
4. The script exchanges the verifier for permanent access tokens.

### Output

Prints the consumer key, consumer secret, access token, and access token secret.

### Where the tokens go

The tokens are used by the `xurl` skill (bundled with OpenClaw). On the server:

```bash
# SSH into the server, then run:
xurl auth login
```

Paste the consumer key, consumer secret, access token, and access token secret when prompted.

Tokens live in `/root/.xurl/` on the host, mounted into the container via `docker-compose.override.yml`. They are **not** stored in `.env.local`.
