---
name: tailscale-serve
description: Reach a loopback-bound local server from another device over your own Tailscale tailnet, then tear the route down. Use when a `127.0.0.1` URL needs to open on a phone or second machine, before sharing a lavish review page, dev server, or build preview, and when removing a serve you created. Tailnet-only, never the public internet.
---

# Serve a local server over Tailscale

`tailscale serve` bridges a loopback port onto your tailnet.
The server keeps its `127.0.0.1` binding, and only devices on your own tailnet can reach it.

Every serve is session-scoped: the config outlives your shell and survives a Tailscale restart, so removing it is part of the job.

## 1. Check for certificates first

This is the one check that separates a working serve from a command that appears to hang:

```bash
read -r HOST CERTS < <(tailscale status --json | uv run python -c "import json,sys;d=json.load(sys.stdin);print(d['Self']['DNSName'].rstrip('.'), len(d.get('CertDomains') or []))")
echo "host=$HOST certs=$CERTS"
```

`certs=0` means this tailnet cannot issue TLS certificates, so serve over plain HTTP with `--http=<port>`.
That is the common case, and skipping this check is expensive: `--https` is serve's default mode, and with no certificates available it blocks on certificate provisioning and prints nothing at all, so it reads as a wedged command rather than an error.
If you need to confirm it, this names the cause outright:

```bash
read -r HOST _ < <(tailscale status --json | uv run python -c "import json,sys;d=json.load(sys.stdin);print(d['Self']['DNSName'].rstrip('.'), len(d.get('CertDomains') or []))")
sudo tailscale cert "$HOST"
```

`DNSName` carries a trailing dot, so strip it before building a URL.

## 2. Claim a free endpoint

An endpoint is a protocol and port.
Reusing an occupied one silently replaces its target instead of failing, and your later teardown then removes a route someone else was using, so look before you claim:

```bash
sudo tailscale serve status
```

Pick a port that is not already listed, and confirm the server is on loopback where it belongs:

```bash
ss -ltn | grep ":<port>"                # Linux; expect 127.0.0.1:<port>
lsof -nP -iTCP:<port> -sTCP:LISTEN      # macOS equivalent
```

If the CLI prints `sending serve config: Access denied: serve config denied`, rerun the mutating command it shows with `sudo`.

## 3. Serve, verify, and hand over

Pick the form by whether the tool builds its own links on a fixed port.

**Clean URL** for a plain web app:

```bash
read -r HOST _ < <(tailscale status --json | uv run python -c "import json,sys;d=json.load(sys.stdin);print(d['Self']['DNSName'].rstrip('.'), len(d.get('CertDomains') or []))")
SERVE_URL="http://$HOST/"
sudo tailscale serve --bg --http=80 http://127.0.0.1:8000
sudo tailscale serve status
curl -sS -o /dev/null -w '%{http_code}\n' "$SERVE_URL"      # expect 200
echo "$SERVE_URL"
```

**Port preserved** when the tool generates links on a port it chose, such as lavish:

Replace `<port>` with the free endpoint you chose.

```bash
read -r HOST _ < <(tailscale status --json | uv run python -c "import json,sys;d=json.load(sys.stdin);print(d['Self']['DNSName'].rstrip('.'), len(d.get('CertDomains') or []))")
SERVE_URL="http://$HOST:<port>/"
sudo tailscale serve --bg --http=<port> <port>
sudo tailscale serve status
curl -sS -o /dev/null -w '%{http_code}\n' "$SERVE_URL"      # expect 200
echo "$SERVE_URL"
```

A bare port as the target resolves to `http://127.0.0.1:<port>`.
`--bg` backgrounds it and persists the config, which is what makes step 4 mandatory.

Give the person the printed URL in full.
Test the fully-qualified name rather than the short MagicDNS name that `serve status` also advertises, since the short form may not resolve from the serving machine even while it works elsewhere.
If they still cannot open it, confirm their device appears in `tailscale status`.

## 4. Tear it down

**Clean URL:**

```bash
sudo tailscale serve --http=80 off
sudo tailscale serve status             # confirm HTTP port 80 is gone
```

**Port preserved:**

Replace `<port>` with the same port you served.

```bash
sudo tailscale serve --http=<port> off
sudo tailscale serve status             # confirm this HTTP port is gone
```

Other serves may legitimately remain, so check that yours is absent rather than expecting `No serve config`.
`sudo tailscale serve reset` clears every serve on the node at once; prefer targeted `off` so a route you did not create survives.

## Safety rules

- **Serve, never funnel.**
  `tailscale serve` is tailnet-only, while `tailscale funnel` publishes the same service to the public internet.
- **Keep the server on loopback.**
  `serve` already reaches it there, so widening a bind to `0.0.0.0` buys nothing and exposes the service to every network the machine is on.
  For lavish specifically, `LAVISH_AXI_HOST=0.0.0.0` makes it serve arbitrary local files.
- **Session-scoped only.**
  Remove the serve when the work is done rather than persisting it or writing it into machine configuration.
- **Look before changing serve config.**
  Print `serve status` before claiming an endpoint or running `reset`.

## Host allowlists: the 403 trap

This is the most common reason a correct serve still fails to load.

`serve` forwards the original `Host` header unchanged, including the port, and adds `X-Forwarded-For` and `X-Forwarded-Host`.
So an app that validates hosts rejects the request until the tailnet name is allowed: lavish answers `403 forbidden host`, Django raises `DisallowedHost`.

Allow the fully-qualified name, plus the `host:port` form on a non-standard port for apps that compare the raw header, plus the short MagicDNS name when other devices may reach it through the tailnet search domain.
Django strips the port before matching `ALLOWED_HOSTS`, so the bare host is enough there.
An HTTP serve sets no `X-Forwarded-Proto`, so leave proxy-SSL settings such as Django's `SECURE_PROXY_SSL_HEADER` alone on this path.

## Worked examples

**Lavish** reads its `LAVISH_AXI_*` variables at server start, so relaunch it to change them, and pin the port or the serve points at nothing after a restart:

```bash
SERVE_URL="http://myrmex.taila827d7.ts.net:4387/"
sudo tailscale serve --bg --http=4387 4387
LAVISH_AXI_ALLOWED_HOSTS='myrmex.taila827d7.ts.net myrmex myrmex.taila827d7.ts.net:4387' \
LAVISH_AXI_PORT=4387 \
LAVISH_AXI_LINK_HOST=myrmex.taila827d7.ts.net \
  npx -y lavish-axi <html-file>
```

**A Django dev server** stays on loopback and lets `serve` do the bridging:

```bash
uv run python manage.py runserver 127.0.0.1:8000
sudo tailscale serve --bg --http=80 http://127.0.0.1:8000
# ALLOWED_HOSTS includes myrmex.taila827d7.ts.net, and any PUBLIC_ORIGIN-style setting uses http://
```

Form POSTs work over plain HTTP with the host allowed and nothing else, because Django performs strict `Referer` checking only on HTTPS requests.

## When the tailnet does have certificates

`certs` greater than zero means `sudo tailscale serve --bg --https=443 http://127.0.0.1:8000` works and yields a real `https://` URL, torn down with `--https=443 off`.
Add the origin to `CSRF_TRUSTED_ORIGINS` for Django-style apps at that point, because the strict `Referer` check that plain HTTP skips is now live.
