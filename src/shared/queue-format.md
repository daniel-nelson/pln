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

## Refunds — money already taken and not yet given back

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

Related items should read as one thing to decide about rather than as three separate asks. What makes a long queue hard is not its length; it is not knowing what to do next, and in what grouping.

**One level, from the `group` field.** The index renders each group as a heading with its member lines beneath it, and the items carrying no group sit last, under `## Everything else`. Groups do not nest: headings inside headings are how a list of work turns into a document nobody reads, and one level is what keeps the index scannable.

**A group heading carries one line saying what its members share, and nothing else** — `## Refunds — money already taken and not yet given back`. The moment that line wants to be a paragraph, the paragraph is an item: give it a detail file and file it.

**Membership is declared on the item.** The `group` field in the detail file is the only record of it, so the index cannot drift from the items it was built out of, and there is no second list to maintain. An item belongs to at most one group.

Urgency does not touch membership. The flag decides where an item's one line renders — `## Urgent` if it is set — and the `group` field decides what the item belongs to, which is why a flagged item is not repeated under its own heading.

### `touches` and `holds`

These two fields say what an item occupies while someone is working on it, and they are the only inputs to the question of whether a second agent can take an item now.

**`touches` is repository-relative file paths the item is expected to write.** A directory entry stands for everything beneath it, so `app/bookings/` claims that whole subtree and `app/calendar/availability.rb` claims one file.

**`holds` is the non-file exclusive resources the item consumes for its duration** — an eval whose numbers a concurrent change would invalidate, a shared prompt, a migration slot, a deploy, a provisioner handing out a scarce local resource. They are tokens rather than paths: `staging-deploy` names a thing there is one of, not a file that exists.

**Two items overlap when their `touches` intersect by prefix containment in either direction, or their `holds` share a token.** Either direction, because a directory entry is a claim on a region and not a string to match: `app/bookings/` and `app/bookings/cancellation.rb` collide regardless of which item declared which.

**An overlapping item is refused.** It is not offered as parallel-safe until the first one is done — the same answer pln already gives inside a single plan, where an overlap between two items becomes an ordering rather than a warning. The refusal names the item collided with and the path or resource they share, because "not now" on its own sends the reader to open both files to find out why.

The comparison is pairwise against the set of items a run has declared, never a partition of the whole queue. Items nobody has picked up need no lanes computed for them.

**Absent means unknown, and unknown collides with everything.** An item filed with no `touches` is never reported parallel-safe. It is also the cheapest kind of item to file — one sentence mid-run, no fields — and if an empty field read as "writes nothing", the cheapest capture would be the most permissive thing in the queue. `mark` fills the field in later, once someone has looked, so a run that takes an unknown item up says what it will write before it declares its scope.

**`holds` is a field of its own rather than a reserved prefix inside `touches`.** pln already has a field of that shape — the write leases the scheduler works from — and it resolves every entry there as a real path in the working tree, so a bare resource token routed through the same field is looked for on disk and fails. Keeping the two apart also keeps the two kinds of collision distinguishable, which is what lets a refusal say whether a file or a resource is being waited on.

**Why a non-file resource needs a field at all.** Take a provisioner that hands out port blocks from a shared registry with no lock: two runs read the registry, both see the same block free, and both take it. Nothing was written twice, so no `touches` could have expressed the conflict, and it surfaces long afterwards as two working trees fighting over the same ports rather than as a collision at write time. Database names drawn from a counter, a fixed scratch path, and a single staging deploy all have that shape.

**What the answer covers.** Parallel-safety is scoped to runs sharing one working tree. The queue sits wherever it resolved, so a second worktree has its own — its own items, and its own record of what is held — and neither can see the other's. Two agents in two trees are outside what these fields can tell you, and that is a stated limit rather than something the fields quietly close.

### Intake — how work reaches the queue

*Not written yet. This section names every door work enters through and states that each one ends in the same `pln-queue add` call.*

### Outflow — what a run may change, and where finished work goes

*Not written yet. This section defines the scope a run declares before it starts, what it may and may not mark, and how a record reaches the archive without anything being deleted.*

### Reading the queue back at a close

*Not written yet. This section defines the order — file first, then draft — and the rule that a closing message is rendered from what the queue returns rather than from what the run remembers filing.*
