**The to-do-location flow.** When the closing message lists any follow-ups, find where this project records future work, in this order: a location named in the project's `AGENTS.md`/`CLAUDE.md`, then one named in the global instructions file (`$CODEX_HOME/AGENTS.md`, `~/.codex/AGENTS.md` by default), then one recorded in this project's memories, then an existing convention such as an issue tracker or a `TODO.md`.

- **Named in either instructions file** — append the follow-ups there without asking, with full detail pulled from `PLAN.md` (or `REVIEW.md` in standalone mode), and say in the closing message where they went. An offer nobody makes records nothing, and the location is already the user's stated answer to the question.
- **Recorded in a memory** — append without asking, the same as an instructions file. A memory naming a to-do location is the user's own answer to this question from a previous session, written down precisely so it isn't asked again.
- **Found only by convention** — offer, in a message of its own, to write them there. A file nobody named may be someone's private scratch.
- **Nothing found** — ask once, in a message of its own, where to save them. Then write the answer to a memory, so the next run finds it here instead of asking again.

The named location is frequently outside the repository and untracked. Write to it exactly as named; never substitute a path inside the repo.

Never bundle the offer or the ask with another question in the same message — in `/pln`, the Step 8 ship ask is a separate turn.

**A PR body, a PR comment and a commit message are copies, never the record.** Each is a place a follow-up gets *mentioned* on the way past; none is where someone goes to find out what is still outstanding. Putting a follow-up in one of them and treating it as filed is the failure this flow exists to prevent, and it reads as done because the text is visibly written somewhere. The to-do location above is the record; everything else quotes it.
