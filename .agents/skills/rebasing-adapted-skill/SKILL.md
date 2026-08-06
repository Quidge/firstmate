---
name: rebasing-adapted-skill
description: >-
  Rebase a locally adapted agent skill onto a newer upstream tip while keeping its intentional deviations, or audit whether those deviations are still honest, driven by the skill's ADAPTATION.md pins.
  Use before rebasing an adapted skill, absorbing upstream skill changes, advancing a skill from its attributions, or checking a vendored skill for undeclared drift and stale deviation bullets.
user-invocable: false
metadata:
  internal: true
---

# Rebasing an adapted skill

**Rebase** a local skill that was adapted from one or more upstream skill directories onto a newer upstream tip, keeping the intentional deviations.
Point this skill at a **target skill directory**: any path that contains `SKILL.md`.

Provenance lives only in that directory's sibling `ADAPTATION.md`, never in `SKILL.md`.
Two parts carry it:

- The front-matter `attributions` **pin** each upstream skill directory to a GitHub tree URL at a full commit SHA.
- The `## Deviations` body lists each intentional difference on an upstream-present path as one natural-language bullet, read as merge **policy**: keep what a bullet protects, and where a bullet is silent, match upstream.
  It is a policy ledger, not a changelog, so it never chronicles the upstream changes a rebase absorbs.

Scaffold pins, validate a directory, or audit it with `scripts/skill-adaptation.py` (read its `--help` for exact commands and exit codes).

## Audit: is the ledger honest?

Run this on its own to answer "does my vendored skill still match its declared deviations?", and as the first step of every rebase.

```bash
scripts/skill-adaptation.py audit <skill-dir>
```

Audit fetches each pinned base and presents two sides for you to correlate: the deterministic `ours - base` **differences** for paths present in that base, and the declared `## Deviations` bullets.
Those differences include locally modified and removed base files; local-only additions stay local across a rebase and are outside audit.
The script does not match one to the other; you do.
Correlate them against the two rot modes:

- **Undeclared drift** - a difference that no bullet covers.
  The next rebase reads silence as "match upstream" and reverts it, so a local change with no covering bullet is silently lost.
  Reconcile by declaring the difference in `## Deviations`, or by dropping the local change to match upstream.
- **Stale deviation** - a bullet that maps to no current difference, usually because upstream later adopted the same change.
  Reconcile by retiring the bullet.

Audit's exit code catches the two provable extremes on its own: differences with zero declared bullets are all undeclared drift, and bullets over zero differences are all stale.
When both differences and bullets are present it cannot prove which covers which, so it exits clean and leaves the pairing to you.

*Done when every presented difference has a covering bullet and every bullet maps to a live difference.*

## Rebase

### 1. Start from an honest ledger

Confirm the target is adapted, then reconcile it before planning:

```bash
scripts/skill-adaptation.py validate-skill-dir <skill-dir>
```

If validation fails, fix `ADAPTATION.md` first (scaffold a fresh one with the `template` subcommand, then edit `## Deviations`).
Then run **Audit** above and reconcile every undeclared drift and stale deviation, so the merge starts from a ledger that tells the truth and cannot silently clobber undeclared local work.

*Done when `validate-skill-dir` exits 0 and audit shows no undeclared drift or stale deviation.*

### 2. Choose target SHAs per attribution

Read the `attributions` pins.
For each attribution the user wants moved this run:

- If the user already gave a target SHA or tree URL, use it.
- Otherwise investigate GitHub - the default-branch tip at the same path, recent tags and releases, commits that touched that path - and present the options, then wait for the user to pick.

Leave every attribution with no target this run at its current pin.

*Done when every attribution either has an approved target SHA or is explicitly skipped.*

### 3. Plan the merge, and wait

For each attribution being moved, reconstruct a **3-way merge** per relative path in the upstream skill tree:

| Side       | Source                                              |
| ---------- | --------------------------------------------------- |
| **base**   | file contents at the current pinned SHA             |
| **ours**   | current files in the target skill directory         |
| **theirs** | file contents at the chosen target SHA (same path)  |

Hold these rules:

- Merge every file present in the upstream skill directory at base or target, matched by relative path.
- Read `## Deviations` as policy: keep each intentional difference, and reintroduce upstream text only where no bullet rejects it.
- Keep local-only files local, and propose upstream-only new files as adds.
- Leave `ADAPTATION.md` out of the file merge entirely; its pins advance in step 5, and it is never taken from upstream.

Show the user a plan: which attributions move (old SHA to new SHA), the file-level outcome for each path, and how each deviation bullet constrained the result.

*Done when the user approves the plan; write nothing before that approval.*

### 4. Apply the approved merge

Write the approved file changes into the target skill directory, and only those.

*Done when every approved file change is on disk.*

### 5. Advance pins; refresh deviations only on intent change

Rewrite each **moved** attribution's tree URL to its new commit SHA, same owner, repo, and path.
Leave skipped attributions untouched.

Edit `## Deviations` only when the set of intentional differences on upstream-present paths actually changed - a difference added, removed, or reworded.
An absorbed upstream change leaves the ledger alone.

Re-run `validate-skill-dir` and **Audit**, and confirm both are clean.

*Done when the moved pins are advanced, the deviations reflect current intent, and validate and audit both pass.*
