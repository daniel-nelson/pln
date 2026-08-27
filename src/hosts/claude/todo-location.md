**The to-do-location flow.** When the closing message lists any follow-ups, find where this project records future work, in this order: a location named in the project's `CLAUDE.md`/`AGENTS.md`, then one named in the global instructions file (`~/.claude/CLAUDE.md`), then an existing convention such as an issue tracker or a `TODO.md`.

- **Named in either instructions file** — append the follow-ups there without asking, with full detail pulled from `PLAN.md` (or `REVIEW.md` in standalone mode), and say in the closing message where they went. An offer nobody makes records nothing, and the location is already the user's stated answer to the question.
- **Found only by convention** — offer, in a message of its own, to write them there. A file nobody named may be someone's private scratch.
- **Nothing found** — ask once, in a message of its own, where to save them.

The named location is frequently outside the repository and untracked. Write to it exactly as named; never substitute a path inside the repo.

Never bundle the offer or the ask with another question in the same message. In `/pln` the question it collides with is the ship ask — the one the `implement only`, absent and legacy branches make — and the to-do offer or ask is a turn of its own, separate from it. Under either PR-bearing `Ship` value there is no ship ask to be separate from: the hand-off is an action, not a question, and nothing here puts a turn boundary in front of it.

**A PR body, a PR comment and a commit message are copies, never the record.** Each is a place a follow-up gets *mentioned* on the way past; none is where someone goes to find out what is still outstanding. Putting a follow-up in one of them and treating it as filed is the failure this flow exists to prevent, and it reads as done because the text is visibly written somewhere. The to-do location above is the record; everything else quotes it.
