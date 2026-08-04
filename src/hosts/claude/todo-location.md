**The to-do-location flow.** When the closing message lists any follow-ups, find where this project records future work, in this order: a location named in the project's `CLAUDE.md`/`AGENTS.md`, then one named in the global instructions file (`~/.claude/CLAUDE.md`), then an existing convention such as an issue tracker or a `TODO.md`.

- **Named in either instructions file** — append the follow-ups there without asking, with full detail pulled from `PLAN.md` (or `REVIEW.md` in standalone mode), and say in the closing message where they went. An offer nobody makes records nothing, and the location is already the user's stated answer to the question.
- **Found only by convention** — offer, in a message of its own, to write them there. A file nobody named may be someone's private scratch.
- **Nothing found** — ask once, in a message of its own, where to save them.

The named location is frequently outside the repository and untracked. Write to it exactly as named; never substitute a path inside the repo.

Never bundle the offer or the ask with another question in the same message — in `/pln`, the Step 8 ship ask is a separate turn.
