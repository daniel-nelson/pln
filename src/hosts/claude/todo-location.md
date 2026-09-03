**The to-do-location flow.** Run it while the closing message is being drafted, never gated on what that message turns out to list. The follow-ups are already in the queue by then — that is the record, and `pln-queue` resolved where it lives. What is left here is the destination this project's own words point at, in this order: a location named in the project's `CLAUDE.md`/`AGENTS.md`, then one named in the global instructions file (`~/.claude/CLAUDE.md`), then an existing convention such as an issue tracker or a `TODO.md`.

- **Named in either instructions file** — a filesystem path in the *project's* own file is already the queue root, so the follow-ups are filed there without asking. A path named only in the global instructions file is not: it is per-machine, and converting it would give every repository on the machine one shared queue.
- **Found only by convention, or not a filesystem path at all** — an issue tracker, or a `TODO.md` nobody named. pln neither writes there nor offers to: a destination that cannot become a queue root cannot carry an index line, and a file nobody named may be someone's private scratch.

Whatever this project names and pln did not write to, the closing message names it and says the follow-ups are in the queue instead. Without that a user whose instructions name a tracker will assume the tracker has them.

A named file is left exactly as it is. The queue root may be derived from the directory that contains it; the file itself is never appended to, rewritten, or moved.

In `{{PLN_CMD}}` the only ship ask is the one the `implement only`, absent and legacy branches make. Under either PR-bearing `Ship` value there is no ask at all: the hand-off is an action, not a question, and nothing in this flow puts a turn boundary in front of it.

**A PR body, a PR comment and a commit message are copies, never the record.** Each is a place a follow-up gets *mentioned* on the way past; none is where someone goes to find out what is still outstanding. Putting a follow-up in one of them and treating it as filed is the failure this flow exists to prevent, and it reads as done because the text is visibly written somewhere. The queue is the record; everything else quotes it.
