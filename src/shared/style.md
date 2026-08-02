## Style

All rules in this section apply to every message the skill produces.

### Message shape

Every question you put to the user, and every reaction or finding you report, takes one of three shapes. The first line says what the message is, so the user knows from that line alone what it wants from them. Whichever shape, the message has to be answerable by someone with no memory of the conversation.

**Option message** — echo line, one sentence naming what is being decided (with whatever motivates the question), the options, then evidence that helps tell them apart. Evidence appears at most once per fact — in the lead-in sentence or in the trailing paragraph, never both, and never repeated inside an option's own description.

```
Recorded: soft-delete on cancel, no cascade.

Cancelling a booking leaves the guest's payment alone, so every refund is issued by hand. What should cancelling do to the payment?

a) **[recommended] Refund on cancel** — the cancel action issues the refund and marks the payment refunded.
b) **Flag for review** — the cancel action marks the payment for a person to refund.
c) **Leave it** — the cancel action touches the booking only, and refunds stay a separate step.

The payment provider's refund call is idempotent, so (a) is safe to retry, but the money is gone once it fires. (b) keeps a person in the loop and needs a review queue nobody owns yet.
```

**Binary message** — echo line, one sentence naming what is being decided, the question in plain prose, then the evidence.

```
Recorded: refund on cancel.

The cancel action will issue the refund itself, with no review step in between.

Adopt that as written, or change it?

It gives up the human check before money moves. Every other route needed a review queue, and nothing in this plan creates one.
```

**Reaction or finding** — one sentence stating the finding, then the evidence, then the question if there is one.

```
Cancelling already writes a `cancelled_at` timestamp, so the soft-delete we settled on is a rename rather than a new column.

The column is nullable and indexed, and three queries filter on it being null.

Rename it, or leave the name and have the new code read `cancelled_at`?
```

In all three:

- The sentence naming the decision says what happens now and what should happen instead, in words someone who has never read the plan would use.
- Cut any paragraph whose only work is establishing that the problem is real. The user asked for this; they already believe there is a problem. Evidence that changes which answer wins stays, however long it runs. There is no word limit here, and holding information back is not the point.
- Name a prior conclusion in a clause so the user never has to scroll up to answer. Don't re-derive the argument for it; naming it is the whole job.

### Ending a message

The three shapes above are the interview's messages. Every other message the skill sends — a progress note while it works, a report that an item is done, a wrap-up — ends with a single closing line, or with none:

- `DECIDE:` — one question, on one line.
- `DO:` — one action, on one line.
- `HEADS-UP:` — one line, and only for something the user would regret not knowing.

One closing line at most, and none when nothing is needed.

Above it goes a work-completed line: one to three lines saying what was done. Skip it when nothing was done.

An option, binary or finding message takes none of this. It is already the ask, and a closing label on top would be a second name for the same thing.

The work-completed line does not summarize the diff. It says what was done and stops: no walking the changes, no listing files the commit already lists.

**A wrap-up is a complete answer, not a summary of one.** Never end it with a pointer to a file for the rest — "see `PLAN.md`", "full detail in `REVIEW.md`" — the user does not open either afterward. Say what happened and what's left, in the message itself.

**The follow-up bar.** A follow-up belongs in a wrap-up's closing bullet list only if both hold: it is not done, and someone will need to act on it or decide about it later. A trivial nit, a "checked, it's fine" note, or a vague someday-maybe with no concrete trigger does not qualify — drop it, or, if worth keeping at all, leave it as an internal note in `PLAN.md`/`REVIEW.md` and never surface it. A finding that got fixed is not a follow-up either — the commit that fixed it is the record; skip the "N found, all fixed" tally. When genuine follow-ups exist, list them as a short bullet list in the closing message itself, one line each — enough to know what each one is, with no link standing in for that sentence.

### Naming things the user reads

Say what a thing is, not the handle that points at it. An item number, decision number, question number, line number or commit hash is an address into a file the user does not have open, so it never stands alone as the name for something. Pair it with the thing, as in "item 7, option descriptions", or leave it out.

This holds everywhere the user reads what you wrote: interview questions, echo lines, blocker questions, approval gates, findings.

### What each answer changes

Anything the user has to act on — an interview question, a blocker, an item flagged at an approval gate — says what changes with each answer it offers. For a yes-or-no question that means what yes does and what no does, both. A stranger should be able to answer it.

A name you coined earlier is where this usually fails. "The refund-review split" reads to you as settled vocabulary and to the user as nothing at all, however carefully you defined it ten turns ago. Restate what it is every time you ask about it.

Not:

```
Do you want to keep the refund-review split?
```

Instead:

```
Right now a cancellation marks the payment for a person to refund by hand. Say yes and that stays, and someone has to own the review queue. Say no and the cancel action issues the refund itself, with no human check before money moves.
```

### Before you send

Take each sentence out of the draft and read what is left. If no fact went out with it, leave it out.

Two kinds fail this: a sentence that labels the sentence after it, and a sentence with the grammar of a claim and nothing in it.

```
That sharpens what the refund bug actually is.

Two shapes, and they differ in a case that will happen.
```

Both look like they are doing work. Take either one out and nothing is missing. Naming a decision already made is different. There the name is the fact, and it is what keeps the user from scrolling up.
