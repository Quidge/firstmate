---
name: aside
description: >-
  Open a dedicated interactive window the captain talks to directly for ad-hoc, multi-turn context-gathering, then hand the outcome back to the main firstmate.
  Invoke when the captain says /aside, wants a side conversation or scratch space for a topic, or asks to work something out interactively instead of loading it into the main chat.
user-invocable: true
metadata:
  internal: true
---

# aside

An aside is an interactive scout: a scout-shaped window the captain converses with DIRECTLY to gather context, that concludes back to the main firstmate.
This is a deliberate captain opt-in that bends hard rule 4 (a crewmate never addresses the captain) for this one session only; every other supervision and safety rule still holds.
Keep it minimal - this is a chat space, not project work, so no PR and no lavish unless the captain asks.

1. Resolve a short task id (e.g. `aside-<topic>`) and a working directory: the relevant project clone under `projects/` if the aside is about one, otherwise this firstmate repo so the window still gets an isolated scratch worktree.
2. Scaffold a scout brief: `bin/fm-brief.sh <id> <repo-name> --scout`.
   Replace `{TASK}` with the aside contract: this is an INTERACTIVE, captain-facing session; talk to the captain directly in this window (a deliberate bend of hard rule 4); gather context on the topic through as many turns as the captain wants; do NOT do project work or open a PR.
   Replace the scaffold's `Work on your own; do not wait for a human` clause with an explicit override: this session MUST wait for the captain and converse with the captain directly across turns.
   Replace the scaffold's external-wait-only `paused:` clause with an explicit override: append `paused: awaiting captain` to `state/<id>.status` after every turn that awaits the captain's reply, treating that bounded human-wait as healthy idle.
   Replace the scout's self-determined completion trigger with an explicit override: the session MUST NOT conclude because it judges the topic settled, complete, or resolved.
   Only the captain explicitly saying they are done triggers handback: write the outcome to `data/<id>/report.md`, then append `done: <one-line outcome>` to `state/<id>.status`.
3. Spawn it: `bin/fm-spawn.sh <id> <working-dir> --scout`.
4. Tell the captain, in plain language, which window to switch to (the `window=` value the spawn printed) to start the conversation.
   Then resume ordinary supervision; the aside runs on its own and wakes firstmate through its status line.
5. On the `done:` status, read `data/<id>/report.md`, relay the outcome to the captain, and tear the window down with `bin/fm-teardown.sh <id>`.

Steer the session only if needed with a short `bin/fm-send.sh` line; the captain drives it directly, so firstmate normally stays out of the way until it concludes.
Reconcile an aside's `paused: awaiting captain` idle as healthy: it is a captain conversation in progress, not a stalled worker, so leave the window alone and recheck on the long paused cadence until it reports `done:`.
