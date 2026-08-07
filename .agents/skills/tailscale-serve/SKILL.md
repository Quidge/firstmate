---
name: tailscale-serve
description: Publish a loopback-bound local server onto your own Tailscale tailnet over plain HTTP so another device can open it, then tear it down. Use before sharing a lavish review page, dev server, or build preview with a phone or a second machine, when a local URL is unreachable from another device, and when removing a serve you created. Tailnet-only, never the public internet.
---

# Serve a local server over Tailscale

`tailscale serve` bridges a port on `127.0.0.1` onto your tailnet.
The server keeps its loopback binding: Tailscale reaches it over loopback and terminates the tailnet connection itself, so nothing about the server changes.
Traffic is WireGuard-encrypted device to device and reachable only from devices on your own tailnet.

Treat every serve as session-scoped.
Stand it up, hand over the URL, and remove it when the work is done, because serve config outlives your shell and survives a Tailscale restart.

## 1. Preflight

Read the tailnet hostname and whether this tailnet can issue TLS certificates:

```bash
HOST=$(tailscale status --json | jq -r '.Self.DNSName | rtrimstr(".")')
CERTS=$(tailscale status --json | jq -r '(.CertDomains // []) | length')
echo "host=$HOST certs=$CERTS"
```

`DNSName` carries a trailing dot, so strip it before building a URL.
Without `jq`, use `tailscale status --json | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['Self']['DNSName'].rstrip('.'), len(d.get('CertDomains') or []))"`.

`certs=0` means this tailnet has no HTTPS-certificate feature, which is the common case and the reason to serve over plain HTTP with `--http`.
This matters more than it looks: `--https` is the default mode, and with no certificates available `serve` blocks on certificate provisioning and prints nothing at all, so it reads as a hung command rather than an error.
`sudo tailscale cert "$HOST"` names the cause directly when you need to confirm it.

Confirm the server is on loopback, which is where it should stay:

```bash
ss -ltn | grep ":<port>"                          # Linux; expect 127.0.0.1:<port>
lsof -nP -iTCP:<port> -sTCP:LISTEN                # macOS equivalent
```

`serve` needs root.
Without it the CLI prints `sending serve config: Access denied: serve config denied` and repeats your command with `sudo`.

Choose the HTTP port you intend to publish, then inspect the existing serve configuration before claiming it:

```bash
sudo tailscale serve status
```

If the intended HTTP port is already listed, choose a different port or stop.

## 2. Serve it

Two forms.
Pick by whether the tool generates its own links on a fixed port.

**Clean URL, no port** - use this for a plain web app:

```bash
SERVE_URL="http://$HOST/"
sudo tailscale serve --bg --http=80 http://127.0.0.1:8000
# -> http://<host>/
```

**Port preserved** - required when the tool builds links on a port it chose, such as lavish:

```bash
SERVE_URL="http://$HOST:<port>/"
sudo tailscale serve --bg --http=<port> <port>
# -> http://<host>:<port>/
```

A bare port as the target resolves to `http://127.0.0.1:<port>`.
`--bg` runs it in the background and persists the config, which is what makes step 4 mandatory.

## 3. Verify, then hand over

```bash
sudo tailscale serve status
curl -sS -o /dev/null -w '%{http_code}\n' "$SERVE_URL"       # expect 200
```

Give the person the full URL.
Test with the fully-qualified name: the short MagicDNS name that `serve status` also advertises may not resolve from the serving machine itself, even while it works from other devices.

## 4. Tear it down

This step is part of the task, not cleanup you get to skip.

```bash
sudo tailscale serve status                 # see what exists before removing anything
sudo tailscale serve --http=80 off          # targeted: the original flags, not the target
sudo tailscale serve status                 # Confirm this session's protocol and port are absent.
```

`off` matches on the flags you originally passed, so `--http=8787 off` removes only that proxy and leaves others running.
`sudo tailscale serve reset` clears every serve on the node at once.
Prefer targeted `off` when you know your own port, so a serve someone else stood up on this machine survives.

## Safety rules

- **Serve, never funnel.**
  `tailscale serve` is tailnet-only, while `tailscale funnel` publishes the same service to the public internet.
  Only `serve` is ever the right answer here.
- **Keep the server on loopback.**
  `serve` already reaches it there, so widening a bind to `0.0.0.0` buys nothing and exposes the service to every network the machine is on.
  For lavish specifically, `LAVISH_AXI_HOST=0.0.0.0` makes it serve arbitrary local files.
- **Session-scoped only.**
  Remove the serve when the work is done rather than persisting it or writing it into machine configuration.
- **Look before changing serve config.**
  Print `serve status` before claiming an endpoint or using `reset`.
  Reusing an occupied protocol and port replaces its target, while `reset` destroys every serve on the node.

## Host allowlists: the 403 trap

`serve` forwards the original `Host` header unchanged, including the port, and adds `X-Forwarded-For` and `X-Forwarded-Host`:

```
Host: <host>:<port>
X-Forwarded-For: <tailnet-ip>
X-Forwarded-Host: <host>:<port>
```

So any app with a host allowlist rejects the request until the tailnet name is added.
Lavish answers `403 forbidden host`; Django raises `DisallowedHost`.
This is the most common reason a correct serve still fails to load.

Give the allowlist the fully-qualified name, and on a non-standard port also the `host:port` form, since an app that compares the raw header sees the port.
Add the short MagicDNS name too when other devices may reach it through the tailnet search domain.
Django strips the port before matching `ALLOWED_HOSTS`, so the bare host is enough there.

An HTTP serve sets no `X-Forwarded-Proto`, so leave proxy-SSL settings such as Django's `SECURE_PROXY_SSL_HEADER` alone on this path.

## Worked examples

**Lavish.** Its `LAVISH_AXI_*` variables are read at server start, so stop and relaunch lavish to change them, and pin the port or the serve will point at nothing after a restart:

```bash
sudo tailscale serve --bg --http=4387 4387
LAVISH_AXI_ALLOWED_HOSTS='myrmex.taila827d7.ts.net myrmex myrmex.taila827d7.ts.net:4387' \
LAVISH_AXI_PORT=4387 \
LAVISH_AXI_LINK_HOST=myrmex.taila827d7.ts.net \
  npx -y lavish-axi <html-file>
# -> http://myrmex.taila827d7.ts.net:4387/session/<id>
```

**Django dev server.** Keep `runserver` on loopback and let `serve` do the bridging:

```bash
python manage.py runserver 127.0.0.1:8000
sudo tailscale serve --bg --http=80 http://127.0.0.1:8000
# ALLOWED_HOSTS includes myrmex.taila827d7.ts.net
# any PUBLIC_ORIGIN-style setting uses http://, matching how it is being served
```

Over plain HTTP, form POSTs work with the host allowlisted and nothing else.
Django performs strict `Referer` checking only on HTTPS requests, which is what an HTTP serve sidesteps.

## When the tailnet does have certificates

`certs` greater than zero in the preflight means `sudo tailscale serve --bg --https=443 http://127.0.0.1:8000` works and yields a real `https://` URL, torn down with `--https=443 off`.
Add the origin to `CSRF_TRUSTED_ORIGINS` for Django-style apps at that point, because the strict `Referer` check that plain HTTP skips is now live.

## Symptoms

| What you see | Cause | Fix |
|---|---|---|
| Command produces no output and never returns | `--https` default mode with no tailnet certificates | Interrupt it, use `--http=<port>` |
| `Access denied: serve config denied` | Not root | Prefix `sudo` |
| `403 forbidden host` or `DisallowedHost` | App host allowlist lacks the tailnet name | Add the host, and `host:port` on a non-standard port |
| Reachable from this machine, not from a phone | Testing loopback or the wrong published port, or the device is not on the tailnet | Fetch `$SERVE_URL`; confirm the device in `tailscale status` |
| Short name fails, fully-qualified name works | Search domain not applied locally | Use the fully-qualified name |
| URL still resolves after the work is done | Serve config persists by design | `sudo tailscale serve --http=<port> off` |
