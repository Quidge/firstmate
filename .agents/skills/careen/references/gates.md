# careen gates G1-G6

The on-demand walk for one held fact.
`SKILL.md` names the routing order and when to reach this file; this file is the full flowchart.
Before durability routing, apply G2's representation test as a hard pre-filter so secrets always route to `.env` and no machine-owned representation can exit G1 into a prose task tier.
For facts that remain prose, hold one specific fact and answer the gates top to bottom; the first gate that resolves it wins.
G4's taxonomy lives in [`kinds.md`](kinds.md), and the per-surface bars G5 applies live in [`surface-tests.md`](surface-tests.md); reach each as its gate calls for it.

## G1 - Durability: does it outlive the task?

No means the task tier, chosen by lifespan: a backlog item note (durable while the item lives), then a scout report (survives teardown), then a brief (true for one dispatch only).
Ephemera that will rot - temporary paths, moving versions, transient ids - store nothing and verify live.
This gate is the guard against laundering ephemera into a durable tier; a fact only continues down the gates once it has outlived its task.

## G2 - Representation: could a machine own it instead of prose?

Prose is the representation of last resort.
Ask, in order, whether a non-prose owner already fits:

- An enforceable rule becomes a fail-closed guard, where the rule turns unviolable and no prose tier carries it - but only within the enforcement scope limit in `SKILL.md`: a `config/`-oriented, home-local destination is in scope, while anything that would change firstmate's version-controlled machinery is flagged to the captain, never performed.
- Fixed-lifecycle choices follow the consulting-moment contracts owned by `crew-dispatch.json`, `data/projects.md`, and `config/*`.
- Command mechanics follow the placement contract owned by `firstmate-coding-guidelines`.
- A secret belongs in `.env`, only ever.

Only judgment, preference, context, and lore continue past G2 as prose.

## G3 - The stranger test: the privacy wall

Ask: would a contributor who has never heard of firstmate find this line true, meaningful, and appropriate in the project's own repo?
Any of these failing sends it firstmate-side: it mentions the captain, his authority, or his review habits; it names fleet machinery, routing, delivery posture, merge authority, quota, or house vocabulary; or it would leak strategy.
A passing example is a project's "prefix every command with `direnv exec .`".

The repo-subject smell: a learning whose subject is a version-controlled project - rather than, say, a tool's behavior on the box - is a strong but not certain smell that it belongs project-side; check every repo-subject learnings entry against this test.

The key insight for the hard problem: "project-intrinsic but firstmate-only" dissolves here.
If a line fails the stranger test it was never project knowledge; it is fleet-to-project relationship knowledge, indexed by project.
The index key (the project name) tempts toward the repo; the subject (the relationship) forbids it.
Route by subject, never by index key - which is what sends this class to G6.

## G4 - Kind: the taxonomy that routes

Classify the fact by kind and read its home from [`kinds.md`](kinds.md).
Several kinds resolve here by pointing back at a G2 owner (dispatch rule, per-project posture, enforceable rule, secret, command mechanics) or forward to G1 (task-scoped).
The remainder split by side at G5, and the relationship cell resolves at G6.

## G5 - The project or public side: audience first, then depth

Reached when G3 passed and the kind is project-shareable.
Apply the conditional reader, purpose, and depth bars in [`surface-tests.md`](surface-tests.md) only among the surfaces the project actually has; that file also owns the no-suitable-surface outcome.

Firstmate shared tracked material follows `firstmate-coding-guidelines`.

Delivery is always a crew ship task; firstmate never writes a project repo.

## G6 - The hard case: relationship knowledge routes by actor

The cell where scope is one project and audience is firstmate-only.
Its homes already exist and, obeying push-down, they sit low rather than up in `captain.md`.
Route by the actor who needs the fact at the moment it is needed:

- The main firstmate: standing delivery posture, ownership, and routing go to `data/projects.md`; work-routing scope goes to `data/secondmates.md`; a bare operating fact goes to the main `data/learnings.md`.
- The owning secondmate (its review-checklist flow and domain conventions): that home's own `captain.md` for a home-local preference or authority, or its `learnings.md` for a home-local learned fact - the whole reason dedicated secondmate homes exist.
- Crewmates on that project read briefs, not tiers, so the durable home must sit wherever the brief-writer reads at brief-writing time - one of the above.
  Never push a fact below the brief-writer's sight line.
- Fat and conditional relationship lore goes to a per-project local user skill in the owning home; `/stow` owns that destination's offload mechanics.
