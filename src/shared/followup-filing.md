**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-todo add` — not by leaving it in prose for the close to remember. **Any `pln-todo` call that ends with `TRACKER_PENDING` above 0 is followed, in the same turn, by the tracker sync** that `{{OUTPUT_ROOT}}/bin/pln-todo tracker --guide` describes; a move that fails stays pending and never stops the run.

**A remainder of this run's own work is not a follow-up, and it is never filed.** Before filing any candidate — a discovery, a worker's doubt, a review finding, a CI failure, a sweep candidate — run the remainder test. It is a remainder when any one of these holds:

- **(a) Its line is this run's.** The line it cites is a `+` line of `git diff -U0 <SOURCE_HEAD>`, or sits in an untracked file `git ls-files --others --exclude-standard` lists. `SOURCE_HEAD` is the `META SOURCE_HEAD` row of `<plan-dir>/run-manifest.tsv`; before that manifest exists the run has no change of its own and (a) does not hold. In `{{PLN_PR_CMD}}` the base is `git merge-base origin/<base> HEAD`, and (a) applies only to a candidate that came through no review merge — a CI failure, a scope-baseline find. Outside git, (a) holds for a file in one of this run's items' write leases.
- **(b) The review merge confirmed `on_base` as `branch`.** In `{{PLN_PR_CMD}}` this alone decides a merged review finding.
- **(c) The run was asked for it.** It is a step — run, verify, backfill, roll out, remove a temporary gate — that a plan item's acceptance criteria name, or that a claimed to-do item's "What to do" or "How to tell it worked" names. Quote that line; a line you cannot quote is no match.
- **(d) This run broke it.** A reproduction passes on `SOURCE_HEAD` (in `{{PLN_PR_CMD}}`, on the merge base) and fails on the current tree. Outside git, (d) does not apply.

The test is line-level: a defect already on a line this run did not add, in a file it touched, is not a remainder and is filed as before.

**A remainder is done in this run, or asked.** In `{{PLN_CMD}}` it becomes a new node by the mid-run-request route; in `{{PLN_PR_CMD}}` the fix phase repairs it; what cannot be done goes to the blocker phase. Delegated and auto mode do it rather than ask. It reaches the to-do list only through one of three exits, with the exit's artifact quoted in the item's body:

1. **The user declined it in this run**, in words you quote. Its status follows the to-do list's rule that "not now" is an answer.
2. **A command this run ran was refused or failed for lack of access** — a production write, an owner-only credential — with the refusal quoted. A read-only check the run can make is made, not filed. Status `blocked`, naming the access.
3. **It waits on an event outside the run** — the merge, a deploy, a soak period, a named date. Status `blocked`, naming the event.

**What a live item already covers goes onto it as a sub-item, never beside it as a new item.** What is left of an id this run claimed — a remainder only through an exit, its artifact quoted in the line — and work any live item already covers, held or not, go in with `pln-todo mark --id <id> --run <run> --add-sub-item "<text>"`; only otherwise `add`. An `add` refused with `NEAR` lines takes one of the two ways it names: that sub-item, or `--distinct-from` naming every `NEAR` id for separate work. Two `{{PLN_PR_CMD}}` deferrals stand: the owner-constraint deferral is exit 1, the owner's quoted constraint its artifact, and the `reached_by: test-only` deferral is filed as the fix phase says.
