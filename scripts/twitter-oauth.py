#!/usr/bin/env python3
"""3-legged OAuth 1.0a flow to get Access Tokens for X/Twitter.

Reads X_CONSUMER_KEY and X_CONSUMER_SECRET from .env.local (or environment).
Run: python3 scripts/twitter-oauth.py
"""

import os
import sys
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from requests_oauthlib import OAuth1Session

CALLBACK_URL = "http://localhost:3000/callback"
REQUEST_TOKEN_URL = "https://api.x.com/oauth/request_token"
AUTHORIZE_URL = "https://api.x.com/oauth/authorize"
ACCESS_TOKEN_URL = "https://api.x.com/oauth/access_token"


def load_env_local():
    """Load key=value pairs from .env.local into environment."""
    env_path = Path(__file__).resolve().parent.parent / ".env.local"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())


load_env_local()

CONSUMER_KEY = os.environ.get("X_CONSUMER_KEY", "")
CONSUMER_SECRET = os.environ.get("X_CONSUMER_SECRET", "")

if not CONSUMER_KEY or not CONSUMER_SECRET:
    print("ERROR: X_CONSUMER_KEY and X_CONSUMER_SECRET must be set.")
    print("Add them to .env.local or export as environment variables.")
    print("Get them from https://console.x.com → your app → Keys and Tokens.")
    sys.exit(1)

oauth_verifier = None
oauth_token_callback = None


class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global oauth_verifier, oauth_token_callback
        params = parse_qs(urlparse(self.path).query)
        oauth_verifier = params.get("oauth_verifier", [None])[0]
        oauth_token_callback = params.get("oauth_token", [None])[0]
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h1>Done! You can close this tab.</h1>")

    def log_message(self, format, *args):
        pass  # silence logs


# Step 1: Get request token
print("Step 1: Requesting temporary token...")
oauth = OAuth1Session(CONSUMER_KEY, client_secret=CONSUMER_SECRET, callback_uri=CALLBACK_URL)
response = oauth.fetch_request_token(REQUEST_TOKEN_URL)
resource_owner_key = response["oauth_token"]
resource_owner_secret = response["oauth_token_secret"]

# Step 2: Open browser for authorization
auth_url = f"{AUTHORIZE_URL}?oauth_token={resource_owner_key}"
print(f"\nStep 2: Opening browser. Log in as your bot account and click 'Authorize app'.\n")
webbrowser.open(auth_url)

# Step 3: Wait for callback
print("Waiting for callback on localhost:3000...")
server = HTTPServer(("localhost", 3000), CallbackHandler)
server.handle_request()
server.server_close()

if not oauth_verifier:
    print("ERROR: No oauth_verifier received.")
    sys.exit(1)

# Step 4: Exchange for access token
print("\nStep 3: Exchanging for permanent access tokens...")
oauth = OAuth1Session(
    CONSUMER_KEY,
    client_secret=CONSUMER_SECRET,
    resource_owner_key=resource_owner_key,
    resource_owner_secret=resource_owner_secret,
    verifier=oauth_verifier,
)
tokens = oauth.fetch_access_token(ACCESS_TOKEN_URL)

print("\n" + "=" * 60)
print("SUCCESS! Tokens for xurl auth login:")
print("=" * 60)
print(f"Consumer Key:        {CONSUMER_KEY}")
print(f"Consumer Secret:     {CONSUMER_SECRET}")
print(f"Access Token:        {tokens['oauth_token']}")
print(f"Access Token Secret: {tokens['oauth_token_secret']}")
print(f"\nAuthorized as: @{tokens.get('screen_name', 'unknown')}")
print("=" * 60)
