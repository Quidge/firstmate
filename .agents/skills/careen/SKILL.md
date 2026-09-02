---
name: careen
description: >-
  Haul out the whole knowledge lattice and route each durable fact to its lowest idiomatic home - the memory files, config surfaces, skills, project repos, and secondmate domains - pushing non-pinned facts and techniques down within this home autonomously and proposing every pinned, authority-shaped, cross-home, captain-shared-removal, or project-side move.
  Use when the captain invokes /careen, for the roughly-weekly knowledge haul-out, or when knowledge has visibly settled in the wrong tier.
  Heavier and rarer than /stow, and defers to /stow inside the three memory files rather than duplicating it.
user-invocable: true
metadata:
  internal: true
---

<!--
maintainers: careen's model is generic enough to be a candidate for upstream contribution rather than fork-local divergence, consistent with the captain's minimize-divergence preference.
If a public installer-facing counterpart is ever wanted, follow the stow pattern: a separate skills/careen/SKILL.md with no shared code.
This tracked skill has no public counterpart yet by design.
-->

# careen

Careen is the roughly-weekly haul-out that beaches the whole knowledge lattice and scrapes each durable fact down to its lowest idiomatic home.
The forcing function is placement correctness, not budget: a fact in the wrong place is wrong even when it fits, because every session that loads its tier pays for it whether or not that session needs it.
The motion is mostly down - push each fact to the lowest surface still guaranteed-loaded for every actor that needs it - and, rarely, up: a fact discovered low that two or more homes now need is hoisted, reconfiguring the ballast so knowledge settles where it belongs.

Careen is a sibling to `/stow`, not an overlap.
`/stow` runs frequently against a byte budget over the three memory files and asks "is this still true?"; careen runs rarely over the whole lattice and asks "is this in the right place?".
Inside `data/captain.md`, `data/captain-shared.md`, and `data/learnings.md`, careen defers to `/stow`'s tier markers, decay clocks, and write boundaries rather than restating them - when careen relocates an entry into or out of a memory file, it stamps per `/stow`'s marking rules and lets `/stow` own staleness.

## The cost model

A line at a tier is a tax paid by every session that loads that tier, whether or not it needs the line.
It earns its keep only if some session that loads the tier - and would not have loaded anything lower in time - needs it.
Otherwise it drops to the lowest surface still guaranteed-loaded at the fact's moment of need.

## The lattice

The old eight-rung ladder survives only as a mnemonic; the real structure is three orthogonal axes plus a recursing depth.

- SCOPE - how widely it applies: captain-wide, cross-domain, one home, one project, one task (the task rung splits by lifespan: backlog note, scout report, brief).
- AUDIENCE - who may read it: firstmate-only, project-shareable, or public, decided by the stranger test; the project side splits by reader (VISION, README, CONTRIBUTING, AGENTS.md) but is nebulous, never assume the full quartet.
- REPRESENTATION - what form it takes, strongest first: enforced code, machine config, colocated mechanics (header + `--help`), prose, pointer; secrets are their own case (`.env`, only ever), and prose is the representation of last resort.
- Depth: LOAD-MOMENT, and it recurses - inside every prose surface, always-loaded versus just-in-time.
  The same earns-its-keep question repeats fractally: `captain.md` versus a skill, `AGENTS.md` versus `docs/`, a `SKILL.md` versus its `references/` (this skill is built that way on purpose).
  Careen practices its own recursion: it keeps every always-loaded surface a pointer and pushes depth into the basement it points at.

## The pass

1. Sweep the lattice for durable knowledge sitting above its lowest idiomatic home: the three memory files, the charter and any secondmate homes this home owns, `config/`-oriented surfaces, this home's user skills, and - read-only - the relationship knowledge that indexes each project.
   First runs surface far more than later ones, and by the autonomy split below they will mostly be proposals, not moves.
2. For each durable fact, walk the gates in [`references/gates.md`](references/gates.md) to find its home.
   The routing order is KIND, then REPRESENTATION before location, then AUDIENCE to pick the side, then SCOPE and LOAD-MOMENT to pick the rung.
   The kind taxonomy is [`references/kinds.md`](references/kinds.md); the bar each surface applies is [`references/surface-tests.md`](references/surface-tests.md).
3. Decide the move's class against the autonomy split, then apply the matching write verb - or, when the destination does not yet exist, flag it.
4. Report the pass in the completion receipt below.

## Write verbs and autonomy

Write authority bounds every move; there is no universal "relocate".
Three verbs, each with its own authority:

- move - relocate an entry within this home's own surfaces.
- route - hand knowledge that belongs to another home to that home as a cross-home request (see below); firstmate never writes a secondmate's files directly.
- propose-as-task - ship a project-side change through the project's registered delivery mode; firstmate never writes a project repo.

The autonomy split is by risk, and it is per-move-class, not per-run:

- Autonomous - a direct `move` only for a non-pinned fact or technique staying within this home.
- Propose-first - everything else surfaces to the captain before it moves: any pinned entry, anything authority- or safety-shaped, every cross-home `route`, every removal from `captain-shared.md`, and every project-side `propose-as-task`.

Because the propose-first classes dominate a first pass, an early careen proposes more than it moves; that is expected, not a failure.

## Routing to a secondmate's domain (the route verb)

Careen is fleet-wide, but the main home never writes another home's files.
When a main-home pass finds knowledge that belongs to a secondmate's domain - a domain-scoped preference or authority, a learned fact about that domain, a relationship fact the owning secondmate is the right actor for - it does not edit that secondmate's memory.
It packages the knowledge and, once the captain approves the route (cross-home is a propose-first class), hands it to that secondmate as a cross-home request: the information plus the explicit instruction "run `/careen` over this within your own domain".

That handoff rides the normal steering path - `bin/fm-send.sh fm-<id> "<packaged knowledge + instruction>"` - exactly as `/stow`'s cascade reaches a live secondmate; read the routed reply from that home's status or the document it points to, never from its chat.
The transport mechanics, remote routes, and delivery-confirmation contract are owned by `secondmate-provisioning`; this skill points at it rather than restating it.

Each home careens what it owns.
A secondmate running `/careen` - whether the captain invokes it there or the main home routes knowledge to it - operates on its own lattice: its own `captain.md`, its own `learnings.md`, its own projects, under its own autonomy split.
Home isolation and the standing authority rules hold throughout: a secondmate still escalates every captain-owned call rather than deciding it, and nothing here expands merge, destructive, or security-sensitive authority for any home.

## Enforcement scope limit

Careen's push into enforcement and config (G2) is limited to `config/`-oriented, home-local destinations.
Turning an enforceable rule into a fail-closed guard is in scope only when the destination is such a config surface.
Anything that would require changing firstmate's version-controlled machinery - `fm-spawn.sh` and its kin - is out of scope: careen flags the opportunity to the captain in the receipt and never touches the fork.
Fork divergence is a standing cost the captain minimizes.

## Side rules

1. Availability beats tidiness: push down only when the destination is guaranteed-loaded at the fact's moment of need for every actor.
   If you cannot name that moment, it is not conditional, and it stays up.
2. The doubt asymmetry: for authority, safety, and preferences a miss can break a boundary, so doubt keeps the fact higher; for facts and techniques a miss only costs a rediscovery, so doubt pushes it down.
3. One owner, with a short, captain-confirmed-complete duplication whitelist: trigger stubs, charter identity, and safety floors that must survive a lower tier going unloaded.
   Nothing else is legitimately copied.
4. Write authority bounds the move - the three verbs above, never one universal relocate.
5. No purity crusade: captain pins beat the algorithm, and re-proposing a settled placement is nagging, not curation.
6. Prose is the representation of last resort, bounded by the enforcement scope limit above.
7. Push-down recurses: apply the one test wherever an always-loaded surface has an on-demand basement.
8. Reconfiguring ballast: mostly down, but hoist up in the rare case - a low fact two or more homes now need becomes a `captain-shared.md` proposal, and a local skill every firstmate user should have becomes a PR proposal.

## Completion receipt

Report the pass in plain captain-facing language, mirroring `/stow`'s receipt style:

- Each direct move made, with the fact, its old home, its new home, and the one-line reason it moved.
- Each proposal raised and awaiting the captain: pinned relocations, authority-shaped moves, cross-home routes (naming the secondmate), captain-shared removals, and project-side ship tasks, each with the fact, its destination, and the reason.
- Each secondmate a route was handed to, and where its reply will return.
- Each enforcement opportunity flagged, marking whether it is an in-scope `config/` destination or an out-of-scope fork-machinery change left untouched.
- What was examined and deliberately left in place, including every pin respected under the no-purity-crusade rule.

A pass is complete when every durable fact examined has either moved, been proposed, or been deliberately left with its reason - never left silently in the wrong place, and never moved past the authority its class allows.
