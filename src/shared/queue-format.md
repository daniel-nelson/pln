## The follow-up queue

Work that is found and not done now reaches the queue — wherever in a session it was found, and whichever of `/pln`, `/pln-pr` and `/pln-simplify` found it. A PR body, a review ledger and a commit message are copies; the queue is the record.

**There is no queue command.** pln grows no fourth skill and no slash command for this. Anything computed — whether an item can be picked up, whether two items collide, which ones look finished — comes from `{{OUTPUT_ROOT}}/bin/pln-queue`, called during a run. Anything read is read by opening the file.

**The layout, relative to the resolved queue root.** The index is `<queue-root>/QUEUE.md`. Each live item has one detail file at `<queue-root>/q/<slug>.md`. A record that reaches a terminal state moves to `<queue-root>/done/<YYYY-MM>/<slug>.md`, listed in that month's own `index.md`. `pln/` is only the default root's basename — never write a literal `pln/` into one of these paths, because the root is resolved and may sit outside the repository entirely.

**The helper resolves the root; no phase document does.** `pln-queue` resolves the queue's location on every invocation, creates it when nothing is found, and reports whether the location question is still owed. A standalone `/pln-pr` run, a `/pln` run resumed after a restart, and a plan that predates this release all reach the same queue without having run any particular step first.

### The index line

The index is derived from the detail files rather than maintained by hand: `pln-queue list` rebuilds it whole, so a line that disagrees with its detail file is the line that is wrong.

**One line per open item, and nothing between the lines but the group headings.** The line carries five things in this order — how far along the item is, whether it is urgent, whether it can be picked up, what it is, and where the rest of it lives.

```
## Urgent

- [-] ! ready · a cancelled booking never releases its held dates, so the room stays unbookable → `q/cancel-releases-held-dates.md`

## Refunds

- [ ] decide · a guest charged twice gets one refund, and nobody has said which charge it clears → `q/double-charge-refund.md`
- [ ] blocked · the refund total on the receipt leaves out the cleaning fee → `q/receipt-refund-total.md`
```

Three vocabularies meet on that line. They are defined here and nowhere else, and the detail file's `state`, `urgent` and `status` fields carry the same values:

- **How far along** — `[ ]` not done, `[-]` partly done, `[x]` fully done. The nested sub-items a `[-]` refers to live in the detail file.
- **Urgent or not** — a single `!` between the completion marker and the status word. Two states on purpose, with no levels, and it is absent rather than negated when the item is not urgent. The line still parses with it optional, because the status word comes from a closed set that `!` is not a member of.
- **Whether it can be picked up** — `ready`, `blocked`, `decide`, `dropped`. There is no `doing` and no `done`: `[x]` covers done, and what a run has in hand is the scope it declared when it started.

The three are orthogonal. Any item at any stage of completion can be urgent, and `[-] ready` and `[-] decide` are both ordinary.

**The claim says what is wrong or what would change, in ordinary words.** Not a title and not an internal name — an identifier, a module, a scenario's name or a term coined in the conversation that filed the item tells a reader who was not there nothing at all. The bar is whether someone who has never seen the item knows what it is about from that one clause.

**The line may not carry detail.** Anything longer than the claim belongs in the detail file. The path is required and relative, so the index and its detail files travel together and an item is found from its line with one file open.

**The order.** Flagged items render in one `## Urgent` section above the group headings; everything else follows under its own heading. Every item appears exactly once, so a flagged item does not appear again beneath its group — `## Urgent` is a bucket derived from the flag, not a group an item belongs to.

Within either bucket the order is date opened, then the items carrying no `opened` date, then `id`. Nothing there is set by hand and nothing records a rank; the last tiebreak exists only so that two `list` runs over an unchanged set of detail files cannot produce two different files.

### The detail file

One file per item, complete enough that an agent with no memory of the conversation that produced it can pick the item up from this file and the repository alone. The frontmatter carries the machine-readable facts; the body is the packet.

```
---
id: cancel-releases-held-dates
state: "[-]"
urgent: true
status: ready
opened: 2026-08-27
source: the cancellation change's PR review, adversarial reader
group: refunds
depends_on: [receipt-refund-total]
touches: [app/bookings/, app/calendar/availability.rb]
holds: [staging-deploy]
---
```

- `id` — the item's stable name, and what the detail file's path is derived from, so two items cannot land on one file.
- `state`, `urgent`, `status` — the three vocabularies above, unchanged. Quote the completion marker: to a YAML reader a bare `[ ]` is an empty list and `[x]` is a one-element one. `urgent` is false when absent.
- `opened` — the date the item was filed, and the index's first sort key.
- `source` — where the item came from: the run, the review, the person.
- `group` — at most one, rendered as described below.
- `depends_on` — the ids of items this one waits on.
- `touches`, `holds` — the files the item is expected to write, and the non-file resources it consumes for its duration. What counts as an overlap is below.

**Four fields have to be filled: `id`, `state`, `status` and `source`.** Every other field may be left empty, so an item captured in one sentence in the middle of a run is still a valid item rather than a form to complete.

**`source` is a field and not a sentence in the body.** The failure this queue answers is a follow-up that existed only in a PR body and a review ledger, so an item's provenance has to outlive the run that found it — which a field does and a paragraph anyone may rewrite does not.

**The helper owns the frontmatter.** `mark` sets a field after filing — a `touches` nobody knew at capture time, a status that changed, the urgency flag — so a fast capture is refined rather than refiled, and `claim` records the run holding the item. Nothing else in the body is the helper's to rewrite.

**The body is a task packet**, in the shape one already needs: what exists and where, what to do, what has to be true first, how to tell it worked, and what it relates to. It is never the index line's claim restated and nothing else — the claim is how the item is recognized, the body is what a stranger needs in order to act on it.

**The nested sub-item checklist lives in the body**, and it is what a `[-]` state refers to. Sub-items use the same three completion markers, one per line, so what is left reads off the file with nothing reconstructed from the run's history:

```
- [x] release the held dates when a booking is cancelled
- [x] free the rooms already stuck behind a cancellation
- [ ] the same when the host cancels rather than the guest
```

Who may check one off, and who may add one, is below.

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
