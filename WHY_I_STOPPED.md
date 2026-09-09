# Why I stopped mid-implementation — 2026-09-09

A `/pln` run reached the implementation phase with 16 scheduled nodes. Three integrated
cleanly. After the third, the run went idle for roughly 29 minutes with a node ready to
dispatch, and only resumed because the user asked what was happening.

This is a post-mortem for the skill's maintainer. It is not a complaint about the rule —
the rule that would have prevented it is already in the phase document, stated clearly,
and I had read it in full.

---

## What happened, precisely

The pattern for each item is: dispatch a worker, wait, validate its result, commit by
leased path, checkpoint, integrate, update `PLAN.md`, then dispatch the next.

For item 9 I ran one Bash call that did the last four of those and ended with
`pln-scheduler ready`. Its output:

```
STATUS=checkpointed
STATUS=integrated
plan updated
READY	4	4	original	fresh
```

I then wrote a message to the user summarising the commit and ending "Next up is item 11,
the provenance columns. Going quiet again." **And ended the turn.** No dispatch call. The
manifest sat with node 4 ready and nothing running.

The two previous items did not fail this way. After item 1 I dispatched item 16 in the same
turn; after item 16 I dispatched item 9 in the same turn. The failure appeared only on the
third repetition.

## The rule that covers it

From `phases/pln/implementation.md`:

> **That last write closes the item boundary, not the turn:** once the commit, checkpoint,
> integration, dashboard edit and to-do list call have all returned, the next thing in the
> turn is the next dispatch call, and prose about it comes after that call. A status
> sentence composed in its place ends the turn instead, leaving the run idle at a node that
> was ready to go.

That is an exact description of what I did, written in advance. The skill predicted this
failure and I produced it anyway. So the interesting question is not "what rule was
missing" but "why did a rule I had read not fire".

## Why it did not fire

Four things, in rough order of how much I think each contributed.

**1. `ready` arrived as the last line of a housekeeping command, not as an instruction.**
I bundled `checkpoint`, `integrate`, the `PLAN.md` edit and `ready` into one Bash call,
because they are one logical unit of bookkeeping. The consequence is that `READY 4` was the
fourth line of output from a call whose *purpose* was closing out item 9. It read as part
of the closing ceremony — a status line confirming the manifest advanced — rather than as
a standing instruction to act. The phase document says "Run `pln-scheduler ready` before
composing any message in this phase", which I did; it does not say to run it *alone*, and
bundling it defeated it.

**2. I had twice told the user I would "go quiet".** Having said it, the shape of my next
message was pre-committed: a short summary ending in a going-quiet sentence. Composing
toward a known ending is exactly the state in which an action that belongs *before* the
message gets skipped — the message felt complete, and completeness is the thing I was
checking for.

**3. The instruction to stay silent and the instruction to keep dispatching pull the same
way but are enforced differently.** "The orchestrator breaks silence to the user only when
a subagent returns `BLOCKED:`" is a rule about messages. "Dispatch before prose" is a rule
about actions. When a run is going well, the silence rule produces an urge to write a
minimal sign-off, and a minimal sign-off is a message — so the silence rule was satisfied
while the dispatch rule was not. Both were in view; only one had a natural checkpoint.

**4. Long-running success lowers vigilance in a specific way.** Items 1, 16 and 9 each
required real intervention — a database migration, a lease extension, a wrong `down()`.
Item 9 ended with everything green and nothing to decide. The absence of a problem removed
the thing that had been prompting me to look at the manifest each time.

## What would actually prevent it

Ordered by cost. The first is nearly free and I think it is the whole fix.

**1. Make `pln-scheduler integrate` print the next dispatch instruction.** `recover`
already does exactly this:

```
NEXT=/Users/…/pln-scheduler claim --manifest … --item 1 --handle … --worktree …
```

`integrate` prints only `ITEM=` and `STATUS=`. If it also printed the next ready node and a
`NEXT=` line, the action would be the last thing in front of me at the exact moment the
previous item closed — which is the moment the rule is about. The failure mode here is a
missing instruction at a boundary, and the boundary already emits output. Put the
instruction in the output.

This also survives bundling, which the prose rule does not: however I compose my Bash
calls, `integrate` is always the last state transition of an item, so its output is always
the right place for "and now do this".

**2. Say that `ready` is run alone.** One clause in the existing paragraph: run it as its
own call, never appended to bookkeeping, because its output is an instruction and appending
it to four lines of status turns it into a fifth line of status.

**3. Name the sign-off as the specific hazard.** The current text says "a status sentence
composed in its place ends the turn". True, but abstract. The concrete version is: *the
turn after a clean item, where nothing went wrong and there is nothing to report, is the
one that drops the dispatch.* A rule that names the exact circumstance is easier to
recognise from inside it than one that names the behaviour.

**4. Consider whether the silence rule needs a positive form.** "Break silence only on
`BLOCKED:`" tells me when to speak, and I inferred that a brief progress note between items
was harmless. It is harmless as a message and harmful as a turn-ender. Making it explicit —
that a between-items note is fine *provided the dispatch call precedes it in the same
turn* — would remove the ambiguity I resolved wrongly.

## What I do not think is the problem

- **Not the rule's wording.** It is clear and it is in the right file.
- **Not context pressure.** The session had used a small fraction of its budget.
- **Not the manifest design.** The manifest was correct throughout, and `pln-scheduler
  ready` told the truth every time it was asked. The state was never wrong; only my reading
  of when to consult it was.
- **Not auto-mode or notifications.** Neither was implicated.

## One honest note about the report

The user asked whether I had stopped. I had. The transcript shows a completed turn with no
pending work, which is the only evidence either of us needed, and I had no way to tell
without being asked, because from inside a finished turn there is nothing that feels
unfinished. That asymmetry is worth designing against: the coordinator cannot notice its
own idleness. A `NEXT=` line on `integrate` is a way for the tool to notice on its behalf.
