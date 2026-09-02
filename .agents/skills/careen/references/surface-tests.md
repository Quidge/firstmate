# careen per-surface inclusion tests

For a fact already routed to a surface, the bar that keeps it there.
Each surface reads: earns its place only if, otherwise falls to, and the watch-out that keeps the pass honest.
When an entry fails a surface's bar, re-enter G4 so its kind selects the ladder before applying the fallback below, with G3 still gating every project-side or public destination.
The move a passing-elsewhere fact makes is bounded by the write verbs and autonomy split in `SKILL.md`.

## main captain.md

Earns its place only if it is a home-local captain preference or standing authority exercised by this home, needed in essentially every main session, or a safety or authority floor.
Falls to: `captain-shared.md` only for a shared captain preference or directive that two or more homes must obey, another home's `captain.md` or `learnings.md` for that home's local knowledge, this home's `learnings.md` for a home-local fact, or a local skill for situational knowledge.
General or operational facts needed by multiple homes follow their tracked owner under `secondmate-provisioning`.
Watch: captain-pinned entries are exempt - re-proposing them is nagging, not curation.

## captain-shared.md

Earns its place only if it is a shared captain preference or directive that two or more homes must obey in essentially every session.
Falls to: G4 routes a preference or directive narrowed to one home to that home's `captain.md`, a home-local fact to that home's `learnings.md`, and a fleet-general operational or machinery fact to its tracked owner under `secondmate-provisioning`.
Watch: the most expensive file in the fleet, since every byte is paid by every inheriting home, and a removal removes it from all homes at once - the default for shared entries is keep, and any removal is a propose-first move.

## a secondmate's captain.md

Earns its place only if it is a domain-scoped preference or authority needed across most of that home's sessions.
Falls to: G4 routes a cross-domain or shared captain preference or directive to a `captain-shared.md` proposal, a home-local learned fact to that home's `learnings.md`, and a fleet-general operational or machinery fact to its tracked owner under `secondmate-provisioning`, while conditional knowledge falls to a local skill or, when G3 passes, the project side.
Watch: the main firstmate cannot edit it directly - a move into it is a routed cross-home request.

## charter

Earns its place only if it defines what the role is: identity, scope boundary, or safety floor.
Falls to: that home's `captain.md` for a home-local preference or authority, a `captain-shared.md` proposal for a cross-domain or shared captain preference or directive, or that home's `learnings.md` for a home-local fact.
Fleet-general operational or machinery facts follow their tracked owner under `secondmate-provisioning`.
Watch: delivered at launch and not re-read, so a `/clear` drops it until relaunch - careen routes identity here and nothing else, which makes that reanchor gap moot for this skill.

## crew-dispatch.json, projects.md, secondmates.md, config/*

Their owners' consulting-moment contracts are their inclusion tests.
Watch: do not duplicate a rule these surfaces already own into prose.

## learnings.md

Earns its place only if it is a home-local operational fact the home needs unprompted, recurring, with no nameable trigger.
Falls to: the owning secondmate's own `learnings.md`, the tracked owner under `secondmate-provisioning` for a fleet-general operational or machinery fact, a local skill once a trigger is nameable, the project repo when G3 passes and the repo-subject smell fires, or the archive under `/stow`'s staleness rules.
When G3 fails, route project-relationship knowledge firstmate-side through G6.
Watch: this is where careen and stow meet - careen decides the right place, stow decides whether it is still true.

## docs/, skill references/, --help - the sub-basement

Earns its place only if it is deep contract or reference detail that an always-loaded layer points to.
This is where push-down recurses: careen applies its own test inside every skill it audits, keeping `SKILL.md` a pointer and pushing depth into `references/`.

## user skill

Earns its place only under `/stow`'s owned user-skill contract.
Falls to: a project skill when G3 passes, or a shared tracked skill under `firstmate-coding-guidelines`.
Watch: `/stow` is the sole owner of this surface's mechanics.

## project-side surfaces

These tests are conditional by reader and purpose; never assume a project has the full VISION / README / CONTRIBUTING / AGENTS.md quartet.

- `VISION.md` earns stranger-safe project direction.
- `README.md` earns a stranger-safe public overview.
- `CONTRIBUTING.md` earns stranger-safe human contributor workflow.
- Project `AGENTS.md` earns stranger-safe agent operations needed in nearly every project session.
- A project skill earns stranger-safe situational agent operations.

Route an item only among the surfaces the project actually has, choosing by reader and purpose.
If no suitable surface exists, the item stays firstmate-side and signals that the surface must be created through a ship task under G5.
The write path is always a crew ship task through the project's registered delivery mode; firstmate never writes a project repo.
