---
name: careen
description: >-
  Route each durable fact across the whole knowledge lattice - memory files, config surfaces, skills, project repos, and secondmate domains - to its lowest idiomatic home: move non-pinned facts and techniques down within this home, and propose every pinned, authority-shaped, cross-home, captain-shared-removal, or project-side move.
  Use when the captain invokes /careen, or when knowledge has settled in the wrong tier.
  Defers to /stow inside the three memory files rather than duplicating it.
user-invocable: true
metadata:
  internal: true
---

# careen

Route each durable fact to the lowest surface still guaranteed-loaded for every actor that needs it: a line earns its tier only if some session that loads that tier - and nothing lower in time - needs it, so most knowledge pushes down and only the shared captain preference or directive class in side rule 8 hoists up.

## The pass

1. Sweep only this home's own lattice and routing records for durable knowledge sitting above its lowest idiomatic home: its `captain.md`, `learnings.md`, owned `captain-shared.md`, charter, `config/`-oriented surfaces, user skills, `projects.md`, and `secondmates.md` scope.
   Never inspect another home's lattice; package secondmate-domain knowledge found in this home's records and route it for that secondmate to self-careen.
   A first pass surfaces far more than later ones, and by the autonomy split below it is mostly proposals, not moves.
2. For each durable fact, walk the gates in [`references/gates.md`](references/gates.md) to find its home.
   The four questions - KIND, then REPRESENTATION before location, then AUDIENCE for the side, then SCOPE and LOAD-MOMENT for the rung - are the conceptual ordering, while G1-G6 is the operational walk, with representation and secrets applied as a pre-filter ahead of durability.
   The kind taxonomy is [`references/kinds.md`](references/kinds.md); the bar each surface applies is [`references/surface-tests.md`](references/surface-tests.md).
3. Decide the move's class against the autonomy split below, then apply the matching write verb - or flag it when the destination does not yet exist.
4. When a move touches `data/captain.md`, `data/captain-shared.md`, or `data/learnings.md`, defer to `/stow`'s tier markers, decay clocks, and write boundaries: stamp the relocation per `/stow` and let `/stow` own staleness.
5. Report the pass in the completion receipt below.

## The lattice

The lattice is three orthogonal axes plus a recursing depth; the old eight-rung ladder is only a mnemonic.

- SCOPE - how widely it applies: captain-wide, cross-domain, one home, one project, one task (the task rung splits by lifespan: backlog note, scout report, brief).
- AUDIENCE - who may read it: firstmate-only, project-shareable, or public, decided by the stranger test; the project side splits by reader (VISION, README, CONTRIBUTING, AGENTS.md) but is nebulous, so never assume the full quartet.
- REPRESENTATION - what form it takes, strongest first: enforced code, machine config, colocated mechanics (header + `--help`), prose, pointer; a secret is its own case (`.env`, only ever), and prose is the representation of last resort.
- Depth: LOAD-MOMENT, and it recurses - inside every prose surface, always-loaded versus just-in-time.
  The same earns-its-keep question repeats fractally: `captain.md` versus a skill, `AGENTS.md` versus `docs/`, a `SKILL.md` versus its `references/` (this skill is built that way on purpose).
  Keep every always-loaded surface a pointer and push depth into the basement it points at.

## Write verbs and autonomy

Write authority bounds every move; there is no universal "relocate".

- move - relocate an entry within this home's own surfaces.
- route - hand knowledge that belongs to another home to that home as a cross-home request (below); firstmate never writes a secondmate's files directly.
- propose-as-task - ship a project-side change through the project's registered delivery mode; firstmate never writes a project repo.

The split is by risk, per-move-class, not per-run:

- Autonomous - a direct `move`, only for a non-pinned fact or technique staying within this home.
- Propose-first - everything else, before it moves: any pinned entry, anything authority- or safety-shaped, every cross-home `route`, every removal from `captain-shared.md`, and every project-side `propose-as-task`.

Because the propose-first classes dominate a first pass, it proposes more than it moves; that is expected, not a failure.

## Routing to a secondmate's domain (the route verb)

Careen is fleet-wide, but the main home never writes another home's files.
When a main-home pass finds knowledge that belongs to a secondmate's domain - a domain-scoped preference or authority, a learned fact about that domain, a relationship fact the owning secondmate is the right actor for - it does not edit that secondmate's memory.
It packages the knowledge and, once the captain approves the route (cross-home is propose-first), hands it to that secondmate as a cross-home request: the information plus the explicit instruction to "run `/careen` over this within your own domain".

That handoff rides the normal steering path - `bin/fm-send.sh fm-<id> "<packaged knowledge + instruction>"` - the same way `/stow`'s cascade reaches a live secondmate; read the routed reply from that home's status or the document it points to, never from its chat.
`secondmate-provisioning` owns the transport, remote routes, and delivery-confirmation contract; point at it rather than restating it.

Each home careens what it owns.
A secondmate running `/careen` - whether the captain invokes it there or the main home routes knowledge to it - operates on its own lattice: its own `captain.md`, `learnings.md`, and projects, under its own autonomy split.
Home isolation and the standing authority rules hold throughout: a secondmate still escalates every captain-owned call rather than deciding it, and nothing here expands merge, destructive, or security-sensitive authority for any home.

## Enforcement scope limit

Careen's push into enforcement and config (G2) is limited to `config/`-oriented, home-local destinations.
Turning an enforceable rule into a fail-closed guard is in scope only when the destination is such a config surface.
Anything that would change firstmate's version-controlled machinery - `fm-spawn.sh` and its kin - is out of scope: careen flags the opportunity in the receipt and never makes the change itself.
That machinery is shared tracked material, altered only through a deliberate repository change, never a knowledge-routing pass.

## Side rules

1. Availability beats tidiness: push down only when the destination is guaranteed-loaded at the fact's moment of need for every actor.
   If you cannot name that moment, it is not conditional, and it stays up.
2. The doubt asymmetry: for authority, safety, and preferences a miss can break a boundary, so doubt keeps the fact higher; for facts and techniques a miss only costs a rediscovery, so doubt pushes it down.
3. One owner, with a short, closed duplication whitelist - trigger stubs, charter identity, and safety floors that must survive a lower tier going unloaded.
   Nothing else is legitimately copied.
4. Write authority bounds the move: the three verbs above, never one universal relocate.
5. No purity crusade: pins beat the algorithm, and re-proposing a settled placement is nagging, not curation.
6. Prose is the representation of last resort, bounded by the enforcement scope limit above.
7. Push-down recurses: apply the one test wherever an always-loaded surface has an on-demand basement.
8. Reconfiguring ballast: mostly down, but hoist a shared captain preference or directive that two or more homes now need into a `captain-shared.md` proposal, and turn a local skill every firstmate user should have into a PR proposal.
   A general or operational fact needed by several homes follows its tracked owner under `secondmate-provisioning` and never enters `captain-shared.md`.

## Completion receipt

Report the pass in plain captain-facing language, mirroring `/stow`'s receipt:

- Each direct move made: the fact, its old home, its new home, and the one-line reason.
- Each proposal awaiting the captain - pinned relocations, authority-shaped moves, cross-home routes (naming the secondmate), captain-shared removals, and project-side ship tasks - with the fact, its destination, and the reason.
- Each secondmate a route was handed to, and where its reply will return.
- Each enforcement opportunity flagged, as an in-scope `config/` destination or an out-of-scope version-controlled-machinery change left untouched.
- What was examined and deliberately left in place, including every pin respected.

A pass is complete when every durable fact examined has moved, been proposed, or been deliberately left with its reason - never left silently in the wrong place, and never moved past the authority its class allows.
