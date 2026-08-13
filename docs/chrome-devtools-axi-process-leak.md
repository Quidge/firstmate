# Known issue: chrome-devtools-axi leaks its process tree when Chrome crashes

Status: OPEN, verified, upstream filing deferred.

`chrome-devtools-axi` wraps Google's `chrome-devtools-mcp`.
This document records the evidence that the wrapper does not reap its own process tree when the Chrome it drives crashes.
It exists so the evidence survives for an eventual upstream bug report against `chrome-devtools-mcp`; no upstream issue has been filed, and filing is deferred pending the captain's decision.

## Leak signature

When the driven Chrome crashes - the `Protocol error ... Target closed` class of failure, for example under `/dev/shm` or memory pressure - the bridge, the `chrome-devtools-mcp` server, and its telemetry watchdog keep running with no Chrome behind them.
The tree root is reparented to `systemd --user`, so the original CLI caller has already exited.
The tell of a leaked instance is a live bridge, MCP server, and watchdog tree with no Chrome process alive.

The leaked chain is five processes:

- `chrome-devtools-axi-bridge.js` (node), the axi bridge.
- `npm exec chrome-devtools-mcp@latest --isolated --headless ...`.
- `sh -c 'chrome-devtools-mcp' --isolated --headless ...`.
- `chrome-devtools-mcp`, the MCP server.
- `chrome-devtools-mcp/build/src/telemetry/watchdog/main.js --parent-pid=<mcp-pid>` (node), the telemetry watchdog.

## Verified case, captured 2026-08-13 on host myrmex

The complete orphaned chain was observed as PIDs 1958187, 1958335, 1958679, 1958680, and 1958927, all started Sun Aug 9 17:09:54 2026.

- Elapsed time at capture was about 284,575 seconds, roughly 79 hours, for a bridge and MCP server that are supposed to live only for the duration of a call.
- The tree root, PID 1958187, was reparented to PID 2278, `/usr/lib/systemd/systemd --user`, so it was genuinely orphaned rather than a child of any live agent session.
- A concurrent `ps` for any `chrome`, `chromium`, `chrome-headless`, or `for-testing` binary returned nothing, so the Chrome was gone while the bridge, MCP server, and watchdog persisted.
- The tree was left running deliberately as live evidence rather than reaped.

## Fresh corroboration, same day and same host

A current `chrome-devtools-axi` screenshot run leaked about 25 processes in its own worktree, which that crew's cleanup reaped.
Leaking on crash therefore reproduces on a current run and is not limited to the stale 79-hour tree.

## Earlier circumstantial signal, 2026-08-12

During navigation planning and implementation work, repeated `chrome-devtools-axi` failures with `Protocol error (Target.setDiscoverTargets): Target closed`, attributed to `/dev/shm` and memory pressure, left about 10 orphaned Chrome and bridge processes resident at roughly 1.5 GB.
Those cleared only as the work finished and its isolated copies were cleaned up.
This signal is circumstantial and was not attributed to individual crashes; it is recorded because it is the pattern that prompted the later investigation.

## What could not be determined

- The exact crash that triggered the 79-hour tree.
  It happened about 79 hours earlier, on Aug 9, with no surviving stderr or log, so it cannot be tied to a specific crash line.
- Which home, crew, or session originally launched that tree.
  Its invocation flags, `--isolated --headless --use-mock-keychain --password-store=basic`, are the generic `chrome-devtools-axi` defaults and carry no home-specific marker.

## Workaround for the crashes

The following reduces the crash class that triggers the leak; it does not address the leak itself.

```
CHROME_DEVTOOLS_AXI_CHROME_ARGS="--no-sandbox --disable-dev-shm-usage"
```

## Disposition

The leak signature is confirmed on a real orphaned tree - crashed Chrome, unreaped bridge, MCP server, and watchdog, reparented to `systemd --user` - plus a fresh roughly 25-process leak from a current run.
That is strong enough to justify an upstream bug, with the honest caveat that no specific crash log was preserved.
Upstream filing is deferred pending the captain's decision, and this document is the durable record until then.
