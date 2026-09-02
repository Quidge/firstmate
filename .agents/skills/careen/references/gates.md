# careen gates G1-G6

The on-demand walk for one held fact.
`SKILL.md` names the routing order and when to reach this file; this file is the full flowchart.
Hold one specific fact and answer the gates top to bottom; the first gate that resolves it wins.
G4's taxonomy lives in [`kinds.md`](kinds.md), and the per-surface bars G5 applies live in [`surface-tests.md`](surface-tests.md); reach each as its gate calls for it.

## G1 - Durability: does it outlive the task?

No means the task tier, chosen by lifespan: a backlog item note (durable while the item lives), then a scout report (survives teardown), then a brief (true for one dispatch only).
Ephemera that will rot - temporary paths, moving versions, transient ids - store nothing and verify live.
This gate is the guard against laundering ephemera into a durable tier; a fact only continues down the gates once it has outlived its task.

## G2 - Representation: could a machine own it instead of prose?

Prose is the representation of last resort.
Ask, in order, whether a non-prose owner already fits:

- An enforceable rule becomes a fail-closed guard, where the rule turns unviolable and no prose tier carries it - but only within the enforcement scope limit in `SKILL.md`: a `config/`-oriented, home-local destination is in scope, while anything that would change firstmate's version-controlled machinery is flagged to the captain, never performed.
- A choice consulted at a fixed lifecycle moment belongs to the surface that moment reads: `crew-dispatch.json` at worker selection, `data/projects.md` at intake or merge, `config/*` for operating toggles.
- The mechanics of one command belong to that script's header and `--help`, nowhere else.
- A secret belongs in `.env`, only ever.

Only judgment, preference, context, and lore continue past G2 as prose.

## G3 - The stranger test: the privacy wall

Ask: would a contributor who has never heard of firstmate find this line true, meaningful, and appropriate in the project's own repo?
Any of these failing sends it firstmate-side: it mentions the captain, his authority, or his review habits; it names fleet machinery, routing, delivery posture, merge authority, quota, or house vocabulary; or it would leak strategy.
A passing example is oikos's "prefix every command with `direnv exec .`".

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
Split by reader among the surfaces the project actually has, never assuming the full VISION / README / CONTRIBUTING / AGENTS.md quartet - many projects carry only a subset.
Within the agent-facing surface, apply the depth bars in [`surface-tests.md`](surface-tests.md): every-session to the project `AGENTS.md`, situational to a project skill, deep contract into the project's `docs/` pointed at from above, mechanics to `--help`.

Knowledge about firstmate-the-product that is useful to every firstmate user goes to firstmate's shared tracked material through the PR path; the within-repo half of that decision is owned by `firstmate-coding-guidelines`, which this skill points at and never restates.

No suitable in-project home yet is a legitimate outcome, not a failure: the fact stays firstmate-side, and its continued residence there is the standing signal that the in-project home should be created through a ship task on the project's delivery path.
Delivery is always a crew ship task; firstmate never writes a project repo.

## G6 - The hard case: relationship knowledge routes by actor

The cell where scope is one project and audience is firstmate-only.
Its homes already exist and, obeying push-down, they sit low rather than up in `captain.md`.
Route by the actor who needs the fact at the moment it is needed:

- The main firstmate at intake or merge: standing delivery posture, ownership, and routing go to `data/projects.md`; "when to route work here" goes to the `scope:` field in `data/secondmates.md`; a bare operating fact ("myrmex rejects squash") goes to the main `data/learnings.md`.
- The owning secondmate (apply-checkbox flow, domain conventions): that home's own `captain.md` or `learnings.md` - the whole reason dedicated secondmate homes exist.
- Crewmates on that project read briefs, not tiers, so the durable home must sit wherever the brief-writer reads at brief-writing time - one of the above.
  Never push a fact below the brief-writer's sight line.
- Fat and conditional relationship lore goes to a per-project local user skill in the owning home (untracked; stow owns that offload destination's mechanics).
