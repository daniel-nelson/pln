## The follow-up queue

Work that is found and not done now reaches the queue — wherever in a session it was found, and whichever of `/pln`, `/pln-pr` and `/pln-simplify` found it. A PR body, a review ledger and a commit message are copies; the queue is the record.

**There is no queue command.** pln grows no fourth skill and no slash command for this. Anything computed — whether an item can be picked up, whether two items collide, which ones look finished — comes from `{{OUTPUT_ROOT}}/bin/pln-queue`, called during a run. Anything read is read by opening the file.

**The layout, relative to the resolved queue root.** The index is `<queue-root>/QUEUE.md`. Each live item has one detail file at `<queue-root>/q/<slug>.md`. A record that reaches a terminal state moves to `<queue-root>/done/<YYYY-MM>/<slug>.md`, listed in that month's own `index.md`. `pln/` is only the default root's basename — never write a literal `pln/` into one of these paths, because the root is resolved and may sit outside the repository entirely.

**The helper resolves the root; no phase document does.** `pln-queue` resolves the queue's location on every invocation, creates it when nothing is found, and reports whether the location question is still owed. A standalone `/pln-pr` run, a `/pln` run resumed after a restart, and a plan that predates this release all reach the same queue without having run any particular step first.

### The index line

*Not written yet. This section defines what one index line carries — the completion marker, the urgency flag, the status word, the claim, and the path to the detail file — the three vocabularies it shares with the detail file, and the order `pln-queue list` renders lines in.*

### The detail file

*Not written yet. This section defines the detail file's frontmatter fields and the shape of its body, which together let an agent with no memory of the conversation that filed the item pick it up.*

### Grouping

*Not written yet. This section defines the one-level `group` field and how the index renders each group as a heading with its members beneath it.*

### `touches` and `holds`

*Not written yet. This section defines the two overlap fields — file paths, and named non-file exclusive resources — and the rule that decides whether a second agent can take an item now.*

### Intake — how work reaches the queue

*Not written yet. This section names every door work enters through and states that each one ends in the same `pln-queue add` call.*

### Outflow — what a run may change, and where finished work goes

*Not written yet. This section defines the scope a run declares before it starts, what it may and may not mark, and how a record reaches the archive without anything being deleted.*

### Reading the queue back at a close

*Not written yet. This section defines the order — file first, then draft — and the rule that a closing message is rendered from what the queue returns rather than from what the run remembers filing.*
