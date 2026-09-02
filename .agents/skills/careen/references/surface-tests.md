# careen per-surface inclusion tests

For a fact already routed to a surface, the bar that keeps it there.
Each surface reads: earns its place only if, otherwise falls to, and the watch-out that keeps the pass honest.
The move a passing-elsewhere fact makes is bounded by the write verbs and autonomy split in `SKILL.md`.

## main captain.md

Earns its place only if it is a captain preference or standing authority exercised by this home, needed in essentially every main session, or a safety or authority floor.
Falls to: `captain-shared.md` (two or more homes need it), a secondmate home (its domain), `learnings.md` (a fact, not a preference), or a local skill (situational).
Watch: captain-pinned entries are exempt - re-proposing them is nagging, not curation.

## captain-shared.md

Earns its place only if two or more homes must obey it in essentially every session.
Falls to: the single obeying home's `captain.md`.
Watch: the most expensive file in the fleet, since every byte is paid by every inheriting home, and a removal removes it from all homes at once - the default for shared entries is keep, and any removal is a propose-first move.

## a secondmate's captain.md

Earns its place only if it is a domain-scoped preference or authority needed across most of that home's sessions.
Falls to: a local skill there, or the project side if stranger-safe.
Watch: the main firstmate cannot edit it directly - a move into it is a routed cross-home request.

## charter

Earns its place only if it defines what the role is: identity, scope boundary, or safety floor.
Falls to: that home's `captain.md` (preference) or `learnings.md` (fact).
Watch: delivered at launch and not re-read, so a `/clear` drops it until relaunch - careen routes identity here and nothing else, which makes that reanchor gap moot for this skill.

## crew-dispatch.json, projects.md, secondmates.md, config/*

Earn their place only if a machine or a fixed lifecycle moment consults the surface.
The sharpest test: if no defined moment reads the surface, the surface does not exist for routing purposes.
Watch: do not duplicate a rule these surfaces already own into prose.

## learnings.md

Earns its place only if it is an operational fact the home needs unprompted, recurring, with no nameable trigger.
Falls to: the owning secondmate's own `learnings.md`, a local skill once a trigger is nameable, the project repo when the repo-subject smell fires, or the archive (stow's decay clock owns staleness, not careen).
Watch: this is where careen and stow meet - careen decides the right place, stow decides whether it is still true.

## docs/, skill references/, --help - the sub-basement

Earns its place only if it is deep contract or reference detail that an always-loaded layer points to.
This is where push-down recurses: careen applies its own test inside every skill it audits, keeping `SKILL.md` a pointer and pushing depth into `references/`.

## user skill (per-home, untracked)

Earns its place only if it is conditional on a nameable trigger, private or home-scoped, and fat enough to matter (roughly fifty or more tokens, stow's bar).
Falls to: a project skill (stranger-safe), or a shared tracked skill (every-firstmate-user value, via a deliberate PR).
Watch: the description line is the entire trigger, and a skill nothing loads is a grave.
This tier is the idiom for firstmate-specific skills that belong to no project - untracked, excluded through the home's repository-local exclude file, harness-discovered, and zero fork divergence by construction.

## project AGENTS.md / project skill

Earns its place only if it is stranger-safe and either nearly-every-session (`AGENTS.md`) or situational (project skill).
The write path is always a crew ship task through the project's registered delivery mode; firstmate never writes a project repo.
