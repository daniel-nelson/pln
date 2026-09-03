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

**A held item says who holds it.** Where a record carries a holder the line ends `· held by <run> in <worktree>`, after the path, and an unheld item ends at its path as before. This is the one fact the line carries that is not about the item itself, and it is there because the index is what people actually open: a claim a reader cannot see is a claim that gets taken twice, which is how two runs in two worktrees of one repository came to hold and re-take the same three items. The worktree rides with the run string because `<YYYY-MM-DD>-<slug>` is not unique across trees sharing one queue — it is the tree's own directory name, and the record keeps the full path. A record claimed before `claimed_in` existed names its run and no tree rather than inventing one.

**The order.** Flagged items render in one `## Urgent` section above the group headings; everything else follows under its own heading. Every item appears exactly once, so a flagged item does not appear again beneath its group — `## Urgent` is a bucket derived from the flag, not a group an item belongs to.

The order is the flag, then the group, then date opened, then the items carrying no `opened` date, then `id`. The group orders inside `## Urgent` too, where it renders no heading — two flagged items from one group sit together there, and a flagged item filed later can come first. Nothing in that chain is set by hand and nothing records a rank; the last tiebreak exists only so that two `list` runs over an unchanged set of detail files cannot produce two different files.

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

**The helper owns the frontmatter.** `mark` sets a field after filing — a `touches` nobody knew at capture time, a status that changed, the urgency flag — so a fast capture is refined rather than refiled, and `claim` records the run holding the item and the worktree it claimed from. Nothing else in the body is the helper's to rewrite.

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

**A run is not refused its own path overlaps.** Where the item collided with is already held by this same run, from this same worktree, a `path` overlap is passed over rather than refused, and the claim says which overlap it passed — `EXEMPT <id> path <path>` beside the `COLLISION` lines. Inside one plan a path overlap between two items is already an ordering the scheduler computed before any wave ran, so refusing it a second time only stops a plan from claiming the items it is there to do: no plan whose two items share a file could otherwise mark its own headline item at close. The exemption is per pair and covers `path` alone. A shared `holds` token keeps refusing whoever asks, because the scheduler resolves leases as repository-relative paths and never reads a queue record, so two same-run items holding one deploy slot would go concurrent with no interlock at all; an item declaring no `touches` keeps refusing too, since an unknown write set is not a path overlap and inherits nothing from that argument. A caller-named `--against` set is compared verbatim, with no exemption.

**A run is identified by its run string and the worktree it claimed from, together.** `claim` records both, in `claimed_by` and `claimed_in`, and both must match before an overlap is passed over. The run string is `<YYYY-MM-DD>-<slug>` and carries nothing repository-qualified, while a queue root may be declared as an absolute or `~/`-rooted path that two unrelated repositories share — so on one day, with one slug, two runs would otherwise pass each other's overlaps with no scheduler edge between them. Within one worktree the run string is trusted as it stands. A same-run claim arriving from a different worktree is refused exactly like a foreign run's, and a record claimed before `claimed_in` existed matches no worktree and is exempted from nothing.

**Absent means unknown, and unknown collides with everything.** An item filed with no `touches` is never reported parallel-safe. It is also the cheapest kind of item to file — one sentence mid-run, no fields — and if an empty field read as "writes nothing", the cheapest capture would be the most permissive thing in the queue. `mark` fills the field in later, once someone has looked, so a run that takes an unknown item up says what it will write before it declares its scope.

**`holds` is a field of its own rather than a reserved prefix inside `touches`.** pln already has a field of that shape — the write leases the scheduler works from — and it resolves every entry there as a real path in the working tree, so a bare resource token routed through the same field is looked for on disk and fails. Keeping the two apart also keeps the two kinds of collision distinguishable, which is what lets a refusal say whether a file or a resource is being waited on.

**Why a non-file resource needs a field at all.** Take a provisioner that hands out port blocks from a shared registry with no lock: two runs read the registry, both see the same block free, and both take it. Nothing was written twice, so no `touches` could have expressed the conflict, and it surfaces long afterwards as two working trees fighting over the same ports rather than as a collision at write time. Database names drawn from a counter, a fixed scratch path, and a single staging deploy all have that shape.

**What the answer covers, and what a second worktree actually shares.** Two trees meet in one queue more often than not, so the holder record is doing real work rather than covering a corner. The linked worktrees of one repository resolve their queue to the *shared* git directory — `git rev-parse --git-common-dir` is the same path from every one of them — so they see each other's items and each other's holds by default. Instructions naming one root do the same across unrelated repositories. What separates the claimants there is the pair `claimed_by` plus `claimed_in`, which is why the worktree sits beside the run string: a `<date>-<slug>` is not unique on its own. Only a tree whose queue resolved somewhere genuinely separate — its own project-root `pln/`, its own declared path — has a queue the other cannot see, and then neither queue can say anything about the other's work at all. That last case is a stated limit, not something the fields quietly close.

### Intake — how work reaches the queue

Work enters through four doors, and every one of them ends in the same call: `{{OUTPUT_ROOT}}/bin/pln-queue add`. The helper writes the detail file, rebuilds the index from it, and prints back the `INDEX_LINE` it wrote — so what was filed is something a later step can read rather than something the run remembers doing. Four hand-written appends would be four chances to write the line differently and four chances to skip it.

**Adding never asks.** Filing is the run writing down what it found, not a decision the user has to be present for. No door pauses for permission, and none of them holds an item back for a better moment.

**A door files a complete item**: an `--id`, a `--status`, a `--source` and a claim. `source` names the run, the review or the person the item came from, because the failure this queue answers is a follow-up whose origin died with the run that found it. Everything else is optional — an item filed with no `touches` is filed with none, and unknown then collides with everything, so it is never reported parallel-safe until someone fills the field in.

**1. The run spinoff — the sweep at either close.** At `/pln`'s Step 7 wrap-up and at whichever `/pln-pr` close hands the PR to the user, the outstanding sweep already assembles the candidates and the follow-up bar already decides which of them are filed. Each one that clears the bar is filed **before the closing message is drafted**, not after it, so that the message can be written from the queue rather than the queue from the message.

**2. The explicit user drop.** "File this for a dedicated session", in whatever words, said at any point in a run — mid-interview, mid-review, in the middle of a fix. It is filed in the turn it is said, and it neither pauses the phase it arrived in nor becomes a question. A drop that waits for the close is a drop that survives only in the conversation, which is the state this queue replaces.

**3. The mid-implementation discovery.** An item worker that finds work outside its item's scope returns it in its result; the **coordinator** files it at the checkpoint. Workers never write the queue themselves — the same rule that keeps them out of `PLAN.md` and the run manifest, and for the same reason: one writer, so two concurrent workers cannot both file the same discovery under two ids.

**4. The recurring cadence.** A `/pln-simplify` map produces bounded candidates, and the ones this run is not taking — struck at the outline checkpoint, or left behind by a run that stops there — are filed rather than ending with the run. `source` names the map. Its own cadence marker is the precedent: an assessment is only worth repeating if what it found outlives it.

The doors differ only in what triggers them. What each one files and where it lands is the format above.

**A migration accepted at the start of a run is not a fifth door.** What an agent lifts out of a to-do file this project's own instructions named is filed item by item through that same `add`, with `source` naming the file it came from. The file is read and never written — the queue starts beside it, not out of it.

### Outflow — what a run may change, and where finished work goes

Intake is unguarded because filing costs nothing. Outflow is not: every rule below exists so that what the queue says was finished is something that actually was.

**A run declares its scope before it starts, and its write set with it.** It names the queue items it is taking — one `pln-queue claim --id <id> --run <name> --touches <paths>` each, which records the write set, checks the collision and records the holder under a single lock, so a second run in this tree reads the item as taken rather than taking it too. `--touches` is where the field above actually gets filled: filing is deliberately cheap and files most items with nothing, and the claim is the first moment somebody has read the item and knows what working it will write. Declare it from that reading, `--holds` alongside it where a scarce resource is involved. A claim of an item that still declares nothing is refused and says so, because an unknown write set is what makes every later parallel-safety answer "cannot say". That declared set is the whole set this run may ever check off. An item outside it may be reported on, and never marked; the one write a run makes outside its declared set is the user-confirmed archive below, which checks nothing off. A refused claim is an item to drop from the run, not one to work anyway.

**Fully done, or not done.** An item is `[x]` only when every part of it landed. Partial completion is expressed — `[-]`, with the remaining sub-items readable in the detail file — never rounded up, least of all because the run is ending. Half a thing marked done leaves work nobody will look for again.

**A read of the queue never fails, and it is never satisfied by reading the index file by hand.** `pln-queue list` is a read to whoever calls it: only the refresh of the on-disk index needs the write lock, and everything it prints is derived from the detail files at that instant. When another run holds the lock it skips the refresh, says so, and renders the listing live — so a locked queue costs a stale index file and nothing else. The index does name its holders, so a caller that gives up on the helper and opens `QUEUE.md` itself still reads a claimed item as claimed — but it reads whatever the last refresh wrote, and a lock is exactly when that file is out of date, so the helper remains the answer to who holds what right now. A refusal says that in as many words, and a `NOTE=` names the holder whenever a lock changed what a call could do.

**A lock left behind by a run that is gone is cleared, once it can be proven gone.** The lock is a directory, so a run killed between taking it and releasing it — a sandbox timeout, an OOM, a hard interrupt — used to leave one that never expired and failed every later call against a holder that no longer existed. The holder now records its pid, host and time inside the lock, and a lock is broken only on evidence: the same host, and a pid that is not running. Another host, or an owner file that cannot be read, is waited on instead and then reported with the `rmdir` that clears it — guessing wrong here means two writers in one queue, which is the thing the lock exists to prevent.

**Marking is attributable, so a run that has been displaced cannot record a completion.** `mark` names the run doing it — `--run <name>` — and a record someone else holds refuses the write, naming the holder. `claim --steal` is the only thing that moves a holder and it does not tell the run it displaced, so without this a run whose item was taken mid-flight could still check it off, and its plan would carry a success the queue does not back. A run that really did the work takes the item back with `claim --steal <holder>` and then marks it; that is also how the run that stole it finds out the steal was contested. An unheld record is marked by anyone, as before, and `--run` is only needed where there is a holder to match.

**`[x]` is not a claim a run may make about work it did not verify.** An item checked off carries the commit or the evidence that closed it, in the record that is archived. `pln-queue archive --disposition completed` refuses a record that is not already `[x]`, so the marking and the evidence cannot come apart.

**The parent's marker is derived from its sub-items**, not chosen: any child done and any child not makes the parent `[-]`, all children done makes it `[x]`, none makes it `[ ]`. New sub-items go in with `mark --add-sub-item`, which keeps the checklist's shape uniform; an existing one is checked off in the detail file's body, which the run working the item keeps current. The parent's own marker is frontmatter, so it is set with `mark --state`.

**A run may add, always, without asking.** New items through the doors above, and new sub-items under an item it is working — including work it discovered was needed and then did. Adding is never a question, and there is no bar to clear for a sub-item under an item that already exists.

**Nothing is deleted.** A record that reaches a terminal state is moved, not removed: `pln-queue archive` copies it to `<queue-root>/done/<YYYY-MM>/<slug>.md`, appends its line to that month's own `index.md`, and only then takes it out of the live queue. The month is the one the record became terminal in — completion for an item a run finished, the confirmation for one finished elsewhere or dropped. There is no delete subcommand and no inverse of `archive`: an item that comes back is a new item whose `source` names the archived one, which leaves no archived `[x]` standing for a completion that was later undone.

The archive is partitioned by month because the index is the part that grows; the detail files are one per item and never do. "What did we finish in August" is one file, and "everything ever finished" is a directory listing.

**The archive inherits the queue root and is never asked about separately.** Wherever the queue resolved, `done/` is beneath it — tracked where the queue is tracked, outside the working tree where the queue is. Excluding a tracked archive is the one case where archiving would be deletion from the repository's record: a tracked detail file moved into an ignored directory shows as a deletion, and the next commit makes it real, under a guarantee that nothing is deleted.

**Work that got finished some other way is the user's call, every time.** `pln-queue stale` reports and never writes: an item whose record says `[x]`, one already `dropped`, an abandoned claim, an item that has simply aged. Those are candidates, not findings. The closing message names them, the user says which are actually finished or dropped, and only then does `archive` run — with their own words as the record's evidence, and with the record keeping the state it had rather than gaining an `[x]` nobody verified. A merged commit that names an item's id proves nothing on its own and archives nothing.

Nothing waits on that answer. The candidates are named in the closing message rather than in a turn of their own, and one nobody answers is named again at the next close — so the live index is bounded by the user's confirmations rather than by a mechanism, which is what "nothing moves without them" costs.

### Reading the queue back at a close

A closing message once said "Open follow-ups, all filed:" over six items when two were filed. The other four sat in a PR body and a review ledger for twelve hours, until someone was asked to go and check. Every word of that message was written in good faith by a run that believed it. So a close does not describe what it filed. It reads it back.

**File first, then draft.** The sweep gathers, the bar decides, `pln-queue add` files every candidate that clears it, and only then is the closing message written. The message is drafted from the queue; the queue is never assembled from the message. Reversed, the list is a statement of intent with nothing behind it to check it against, which is how those four went missing.

**Render the list, do not compose it.** Run `{{OUTPUT_ROOT}}/bin/pln-queue list` before writing the follow-up bullets. Each `add` printed back the exact `INDEX_LINE` it wrote; `list` prints the whole index between `INDEX_BEGIN` and `INDEX_END`. This run's follow-up bullets are the lines it filed, found there — a follow-up whose line is not between those markers cannot appear in the message, because there is nothing to render it from. This is not a check run over a finished draft; it is where the bullets come from.

**Say where they went, and claim nothing the read does not support.** Name the queue — `list` prints `QUEUE_ROOT` in the same output — and let the count be the number of lines read back. "All filed" then stops being the run's account of its own behavior, which is the sentence that was wrong, and becomes a description of a file. A `list` that fails is a failed read and fails the close with it: it prints `ITEM_COUNT` and `STATUS` even for an empty queue, so an empty read and a broken one are never the same thing.

**None of this touches the bar.** Filing is not a way around it: a candidate that is not true when checked, that is done, or that nobody will have to act on is not filed and not mentioned. The read-back governs only what becomes of a candidate that already cleared it.

**One exception, and it is a floor rather than a way out.** When nothing could be filed at all — `pln-queue` resolved no queue root anywhere, or the root it resolved cannot be written — the run lists the follow-ups inline in the closing message, says plainly that nothing was filed, and says why. A rule against over-claiming must not become a rule against reporting; losing them silently is the failure being fixed. This is the only way a follow-up reaches the user with no index line behind it. It never covers one that could have been filed and was not, and a run that takes it says so rather than letting the inline list read as a queue.
