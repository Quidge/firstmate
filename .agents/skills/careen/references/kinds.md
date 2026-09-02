# careen kind table (G4)

The taxonomy G4 routes by, each kind with an illustrative example and its home.
A home marked "exits at G2" means the kind is owned by a machine surface, not prose; "exits at G1" means it is task-scoped.
The relationship kind resolves at G6, and the project-side kinds resolve their depth at G5 against [`surface-tests.md`](surface-tests.md).
Every project-side or public home in this table requires G3 to pass first; a failure routes project-relationship knowledge through G6.

| Kind | Example | Home |
|---|---|---|
| Home-local captain preference / working style | a working-style preference that applies within one home | that home's `captain.md` |
| Cross-domain or shared captain preference / directive | a working-style preference that applies fleet-wide; a cross-domain directive on PR shape | `captain-shared.md` |
| Standing authority grant | "MAY run a read-only plan; applying needs explicit word" | `captain.md` of the home that exercises it |
| Role identity / scope / safety floor | "this steward role never applies to the production host" | charter |
| Dispatch / routing rule | a given task kind to a higher-reasoning crewmate profile | `crew-dispatch.json` (exits at G2) |
| Per-project fleet posture | delivery mode + yolo | `projects.md` (exits at G2) |
| Work-routing scope | "route this domain's feature work here" | `secondmates.md` scope field |
| Enforceable rule | worktree isolation | fail-closed guard (exits at G2; version-controlled machinery is flag-only) |
| Secret | a pairing token | `.env` (exits at G2) |
| Home-local learned fact / gotcha | "a CLI truncates large payloads on this box" | the owning home's `learnings.md` |
| Fleet-general operational / machinery fact | a recurring fleet-command behavior | its tracked owner under `secondmate-provisioning` |
| Reusable technique with a trigger | reaching a local server from another device | a user skill |
| Deep contract / reference detail | a tool's quirk sheet | `docs/` or a skill's `references/`, pointed to from above |
| Project-intrinsic, every-session | "prefix every command with `direnv exec .`" | project `AGENTS.md` |
| Project-intrinsic, situational | a project's situational setup convention | a project skill |
| Project direction / human workflow / overview | goals; contributor how-to | VISION / CONTRIBUTING / README (audience decides) |
| Fleet-to-project relationship | "this project merges rebase-only"; a review-checklist protocol | G6 - by actor |
| Command mechanics | exact flags, paths | `--help` / header (exits at G2) |
| Task-scoped | one item's decisions / findings / context | backlog note to report to brief (exits at G1) |

Two parallel ladders fall out once audience is fixed firstmate-only and representation is prose:

- The preference/authority ladder follows breadth across the `captain.md`, `captain-shared.md`, and charter rows above.
- The learned-facts ladder follows ownership across the `learnings.md` and tracked-owner rows above.

A learned fact and a captain preference are different kinds riding parallel ladders; do not merge them onto one rung.
