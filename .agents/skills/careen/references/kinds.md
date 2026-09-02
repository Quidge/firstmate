# careen kind table (G4)

The taxonomy G4 routes by, each kind with a real example from the captain's own files and its home.
A home marked "exits at G2" means the kind is owned by a machine surface, not prose; "exits at G1" means it is task-scoped.
The relationship kind resolves at G6, and the project-side kinds resolve their depth at G5 against [`surface-tests.md`](surface-tests.md).

| Kind | Real example | Home |
|---|---|---|
| Home-local captain preference / working style | read phone-origin messages charitably when it applies within one home | that home's `captain.md` |
| Cross-domain or shared captain preference / directive | read phone-origin messages charitably when it applies fleet-wide; upstream-sync PR shape | `captain-shared.md` |
| Standing authority grant | "MAY run terraform plan; apply needs explicit word" | `captain.md` of the home that exercises it |
| Role identity / scope / safety floor | "homeworld-steward never applies to the live box" | charter |
| Dispatch / routing rule | lavish sessions to an opus crewmate | `crew-dispatch.json` (exits at G2) |
| Per-project fleet posture | delivery mode + yolo | `projects.md` (exits at G2) |
| Work-routing scope | "route Oikos feature work here" | `secondmates.md` scope field |
| Enforceable rule | worktree isolation | fail-closed guard (exits at G2; fork machinery is flag-only) |
| Secret | Relay pairing token | `.env` (exits at G2) |
| Home-local learned fact / gotcha | "gh-axi truncates large payloads" | the owning home's `learnings.md` |
| Fleet-general operational / machinery fact | recurring `fm-send` behavior | its tracked owner under `secondmate-provisioning` |
| Reusable technique with a trigger | serving a board over the tailnet | a user skill |
| Deep contract / reference detail | an adapter's quirk sheet | `docs/` or a skill's `references/`, pointed to from above |
| Project-intrinsic, every-session | "prefix commands with `direnv exec .`" | project `AGENTS.md` |
| Project-intrinsic, situational | a project's ponytail discipline | a project skill |
| Project direction / human workflow / overview | goals; contributor how-to | VISION / CONTRIBUTING / README (audience decides) |
| Fleet-to-project relationship | "myrmex merges rebase-only"; apply-checkbox protocol | G6 - by actor |
| Command mechanics | exact flags, paths | `--help` / header (exits at G2) |
| Task-scoped | one item's decisions / findings / context | backlog note to report to brief (exits at G1) |

Two parallel ladders fall out once audience is fixed firstmate-only and representation is prose:

- The preference/authority ladder follows breadth across the `captain.md`, `captain-shared.md`, and charter rows above.
- The learned-facts ladder follows ownership across the `learnings.md` and tracked-owner rows above.

A learned fact and a captain preference are different kinds riding parallel ladders; do not merge them onto one rung.
