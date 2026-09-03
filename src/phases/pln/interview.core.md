---
name: pln-phase-interview
---

# /pln phase: interview

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first interview action. `Phase: interview` permits planning conversation, durable plan edits, read-only research, and incidental capture only; it never permits feature implementation.

Before sending any question, write the self-contained question under `Open questions`. After the answer, write the decision and reconcile the item before removing that question. When every active item is resolved, finish every item/detail/dashboard write, set `Phase: review-approval`, then read that phase in full before review or gate work.

**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-queue add` — not by leaving it in prose for the close to remember.

That covers the user handing you something to file — "file this for a dedicated session", "that's its own piece of work, don't lose it" — in whatever words they use. It is filed without asking, with an `--id`, a `--status`, a `--source` naming this run and a claim; then the interview continues from where it was. It is not an interview question, not a plan item, and not a reason to leave the interview. The three signals below are a different thing: they scope an item or a question already under discussion, while this is work that leaves the plan behind entirely.

## Defer / drop / think-offline signals

Three intents the user can express in any phrasing:

- **defer** — come back later this session. The skill circles back automatically at the end of the per-item loop, before final verification.
- **drop** — don't ask again, not relevant.
- **think-offline** — the user will go consider it and come back in a future session.

Common vocabulary: `defer`, `skip for now`, `come back to this`, `parking it`, `drop`, `abandon`, `forget it`, `not relevant`, `n/a`, `think about it`, `let me sit with it`, `offline`. Don't literal-match; infer the intent from natural phrasing.

**Scope these intents to the item or question under discussion, never the whole session.** When one of these signals arrives mid-interview, it applies to the current item (or the specific sub-question being asked), not to the interview or the planning session as a whole. "drop" / "abandon" / "forget it" in answer to a question about item N means mark item N 🚫 dropped and continue to item N+1 — it does **not** mean exit the interview. The interview ends only when every item has been walked, or when the user unambiguously ends the whole session ("abandon the whole plan", "stop the session", "we're done here", "cancel everything") **and confirms it**, per Step 3's exit-confirmation rule — recognizing the language is never itself the exit. A bare one-word reply during an item discussion is scoped to that item by default; if you genuinely can't tell whether the user means the item or the session, ask one clarifying question rather than tearing down the session — exiting the interview is expensive to undo and re-establish, so the safe default is the narrow scope.

### Delegated mode

One further intent, and the only one scoped to the session rather than to the item: the user hands the rest of the interview over. "you decide", "stop asking me", "answer them yourself and build it". Infer it from natural phrasing like the three above, but read it as covering the whole interview — the agent resolves every remaining ask-lane question itself and goes on to implementation.

**Only unambiguous session-wide phrasing enters it.** The narrow-scope default still governs everything else: "I don't know", "your call", "whatever's easiest" in answer to a question is an answer to that question, and the filter above already says what to do with it — indifference means the choice was decide-and-disclose, not ask. Where you can't tell whether the user means this question or the interview, ask one clarifying question. Entering the mode is expensive to undo, because after it there is almost nothing left that stops.

**What the agent may decide from:** the decision record Step 1 found (see Step 3's "Before asking, check the record"), the code itself, the project's stated principles, and this session's own prompts and whatever they name. A question none of those answers is not one to invent an answer to — it goes on the short list below.

**Every resolution is recorded** in its item's detail section as `**Decision (agent).**` with its cited authority and its reversibility, the way a decide-and-disclose call already is. The user reads them afterwards rather than at a gate, so that record is what they read.

**Adoption is given once, in advance.** The instruction that entered the mode is the adoption signal for the run, so both prompts that would otherwise block are self-adopted: write the Step 2 skeleton and keep going, and move from the finished plan into Step 5 without showing it for approval. Record `Ship: PR after implementation` in the dashboard — the mode takes the implement-and-open-a-PR shape of Step 4's adopt prompt.

**What still stops the run: one short list, printed before implementation starts.** Three things reach it, each resolved with the user before Step 5 begins:

- A decision that reverses something already settled or already built, or one that cannot be undone. Record the reversals in the dashboard's Reversals section as well, so `{{PLN_PR_CMD}}` carries them into the PR body.
- A Step 3.5 finding the review flagged rather than repaired. Flagged findings are the gate's business, and there is no gate here, so a flagged false factual claim would otherwise be built with nobody having seen it.
- A question the sources above do not answer.

Print the list, then offer to walk it the way Step 4's adopt prompt offers to walk its triaged entries — one question per turn, each item restated in full, per Walking the flagged entries. There is no gate in this mode, so this is where that offer lives. Declining is itself the answer to the list: the user has read it and said go, and Step 5 starts. What the offer replaces is a list the user can only act on by naming entries back at you.

Nothing waives that list, including a spoken "just go, don't check with me" — that instruction is what entering the mode already means, and the list is what it was traded against. A run with nothing on the list says so in one line and proceeds. Everything else runs without interruption, which is the point of the mode.
### Step 3. Interview phase

This is a **questions-only** phase for the plan's own scope. What's banned is *implementing the feature this interview is defining* — anything that would need the full item workflow (edit, verify, commit, and eventually a PR) — no matter how it's carried out: not in this repo, not in any other repo, sibling, or dependency; not inline, and not by spawning a sub-agent, background task, or workflow to do it. That work is a plan item, and plan items execute in Step 5, never here.

Two things are not that, and are fine to do mid-interview, immediately, without asking:

- **Read-only research through the context firewall.** Repository, dependency, framework, and prior-decision research is worker work. Its detailed evidence is a local planning artifact, not feature output. Never paste a worker's report into chat or replace the worker with inline exploration. A worker finishing produces no user-facing turn of its own, whether or not a question is already open; its findings are held per Holding output until the work quiesces.
- **Incidental capture, done right now.** A small side-note that isn't the item under discussion and isn't part of this plan's own work — write up a bug you noticed, a feature request, a stray discovery — into wherever it belongs (a file in another repo's root, a tracker) so it isn't lost. This isn't implementation: nothing about it needs a test, a review, or a PR of its own, and it doesn't touch the thing the plan item will build. Do it immediately when asked, in this repo or another one, and mention in the plan that it was done so the record isn't silent.

The line between the two lanes is not "is this a write" or "is this delegated" — it's whether what's being asked for is the item's actual feature work. A note that says "this other repo can't do X, someone should add it" is capture. Adding X to that repo is implementation, however small it looks, and it waits for Step 5 even if asked for explicitly and delegated to a non-blocking sub-agent — the ban is on doing the feature work now, not on background execution as a mechanism. When unsure which lane a request is in: would it need its own tests-and-PR treatment? If yes, it's a plan item; capture it, don't start it.

A discovery *during the interview* that warrants separate work — a fix in another repo, an upstream framework change, anything outside the current task's scope — is **captured, not executed** the same way: record it in `PLAN.md` (Open questions, an out-of-scope-follow-ups note, or a spinoff stub) and keep interviewing, unless it's the incidental-capture kind above, which gets written immediately instead of waiting.

None of this exits the interview — not a request to implement the item's own feature work, however phrased ("fix it," "go do X now," "send a sub-agent to do it"), and not a plan decision that merely names something executable ("open a PR for X"). Litmus test for the latter: if the sentence would read naturally as a line inside an item's Decision write-up in `PLAN.md`, capture it silently and keep interviewing — don't ask. Every accepted plan item eventually becomes an executable action; naming one is the interview's whole point, not a signal to leave it.

The only thing that ends the interview early is the user abandoning the plan itself ("stop the plan," "forget the interview, just do it") — and recognizing that language is not itself authorization to act on it. Confirm first: "Really exit `{{PLN_CMD}}` mode?" Only an explicit yes leaves Step 3; anything else, including silence, means stay. This runs even when the signal reads as unambiguous — unambiguous phrasing is what makes the question worth asking, not a reason to skip it.

**Research before prose.** Every active item is researched before the walk begins — not each item as the walk reaches it, which would put a wait in front of every question instead of one wait in front of all of them. For each item, classify the needed read through the three tiers. A known-stop exact coordination fact may be direct within the shared budget; a mechanically closed inventory or citation refresh uses `{{SKILL_DIR}}/src/workers/evidence-collection.md`; shaping an approach, tradeoff, scope, or question uses a fresh `judgment` worker with `{{SKILL_DIR}}/src/workers/interview-research.md` in item mode. Give workers the project root, `PLAN.md`, exact item/question scope, source state, applicable root mandates, evidence/result paths, routing attribution, and the 4096-byte ceiling. Record every route in `routing.tsv` and read only a validated envelope. If evidence changes the premise or returns `ESCALATE: frontier`, dispatch a fresh judgment worker over its artifact paths before writing prose. The user sees one coherent response after research, never progress output or raw findings.

**Research every active item before the walk begins, and dispatch it concurrently.** The classification above is per item; the dispatch is not. Item research is read-only and each item's is independent of every other item's, so nothing orders them — and a run that researches one item at a time makes the user wait the sum of every item before the first question, rather than the slowest one. Dispatch the item workers together in waves, await the wave, then walk the items with their envelopes already in hand. Measured on a real four-item run: 6.1 + 7.4 + 13.9 minutes serially, where the wall clock could have been the longest of the three.

**A plan wider than one wave walks the wave it has.** Where the active items do not fit a single wave, the walk begins when the first wave lands, and the next wave is dispatched as the walk moves into it — the run does not wait for the last wave before asking the first question, which would put the whole delay back for exactly the plans that can least afford it. A wave still running for items the walk has not reached does not hold back a question about an item already researched: the hold above exists so that a message the user must read is not buried by later output, and a wave in flight produces no output at all — its results are consumed silently as they land, which is what that rule already says. What is never split is a single item: its own research is in hand before its question is asked.

Two things stay sequential, and neither is a reason to serialize the wave. A follow-up worker for an item whose evidence changed its premise, or which returned `ESCALATE: frontier`, is dispatched after the wave that raised it. And where an answer already given makes a dispatched item's research moot, say so and cancel that worker rather than letting it land under a question its own answer would change.

<!-- pln:include research-fanout -->

Walk every item, in order, gathering what the implementer needs to do the work without doing something the user would veto: intent, constraints, and the decisions only the user can make. Not a prescription of reversible mechanics. For each item:

1. Use the item's validated research envelope to ground a concrete approach (file paths, behavior, touchpoints, consumers, constraints, and tests). The coordinator reads no surrounding code.
2. Apply the system-fit gate before proposing additive durable surface. A localized correction inside an established owner needs only that owner named. For a durable owner, abstraction, data concept, service, workflow, public interface, compatibility path, or parallel behavior path, cite the validated envelope's strongest existing-owner route and select its reuse or extension unless repository evidence identifies the specific acceptance criterion or invariant it cannot satisfy and the distinct required responsibility it cannot carry coherently. If that support is absent, do not admit the new concept: keep the existing owner or dispatch further research. This gate applies even when plan review is disabled. Analogues inform the comparison but do not command reuse, and the comparison stays within the requested feature rather than creating unrelated cleanup.
3. Propose a concrete approach, and run every open choice in it through the filter (see "What reaches the user"). Surface only ask-lane choices — unbacked and consequential — as a) / b) / c) options. Make the cite-backed and reversible calls yourself and record them as disclosed decisions. Leave the not-yet-knowable ones to surface in implementation. Don't manufacture an interview question for a choice an implementer should own.

   Put the message in one of the shapes under Message shape. The sentence naming the decision says what happens now and what should happen instead: "In the Past Stays tab, clicking a booking does nothing; in the Upcoming tab it opens that booking's detail panel. We want that panel to open from Past Stays too." Not a label ("the Past-Stays tab wiring"), and not the code-level approach ("wire the `onOpen` prop"). Where the approach itself needs stating, it goes where the evidence goes, in no more than six short bullets.
4. If notifications are on, fire them first (see Notifications): {{NOTIFY_CALL}}, each naming the item and the gist of the question (e.g. "pln: item 4 — which auth provider?"). Then ask **one** ask-lane question at a time. Wait for the answer. Echo the recorded answer in one short line. Move to the next question.
5. Update the item's detail section in `PLAN.md` after each answered question, so the file becomes the durable record and nothing is lost if context compacts.
6. When the item's ask-lane questions are answered, write the item's detail section: intent, constraints, acceptance criteria, the decisions other work depends on, and the disclosed decisions (each tagged with its authority or reversibility, and flagged if low-confidence). In those existing fields, record the selected ownership and whether directly caused old surface is retired, deliberately retained with cited evidence, absent, or `no direct retirement found`; do not add a mandatory heading or seek unrelated cleanup. Don't write a step-by-step of reversible mechanics; see "One filter, two surfaces."
7. Move to the next item. Repeat until every item has a written final-form detail section, or is marked ⏸ deferred / 🚫 dropped.

**Before asking, check the record.** Where a project has planned this way for a while, its own plans are the decision record, and a question about something they already settle spends the user's attention on a matter that has an answer. So when Step 1 found a record, check it before each ask-lane question goes out, against that one question rather than against the item or the plan.

Do the check in a fresh evidence worker using `{{SKILL_DIR}}/src/workers/interview-research.md` in decision-record-query mode, never in this context. Give it exactly one proposed question, the record locations Step 1 found, source state, separate evidence and result paths for that query, evidence-profile attribution, and the 4096-byte ceiling. It returns only candidate prior-record matches, exact `file:line` citations, and the decision's own words; it does not decide applicability, conflict, or reversal. A new question gets a new worker; never load or summarize the corpus in the coordinator.

No candidate means the mechanically specified locations do not answer the question. Any candidate match, conflict, uncertain applicability, or possible reversal goes file-first to a fresh `judgment`-profile worker, which decides whether the record settles this exact question and whether the current plan reverses it. The coordinator reads only that worker's bounded envelope, records both routes in `routing.tsv`, and never reads the candidate corpus or evidence notes.

A question the record answers is not asked. It becomes a disclosed decision naming where it was settled, and it reaches the user at the Step 4 gate as overridable like any other, because a prior plan's decision is a citable authority (see "What reaches the user"). A question the record does not answer is asked exactly as it would have been.

**What the check is not.** It is not a test of whether this plan may contradict what was decided before. A `{{PLN_CMD}}` session exists to change existing behavior, and overturning an earlier decision is routinely the point of the work. So the judgment step never adds a question, never vetoes anything, and never fires on a choice nobody is asking about — its whole job is removing a question, and it either removes one or it changes nothing.

One thing it does raise. A decision already reflected in the codebase is not changed silently, whoever made it: where the plan reverses one, the item's section says which decision it reverses and where it was made, it gets a line in the dashboard's Reversals section, and it goes to the gate as a disclosure the user can act on rather than as a question that stops the interview.

**How a decision is recorded.** The reviewer (Step 3.5) and every implementer get the plan and nothing else, so a decision has to mean the same thing to someone who never saw the interview as it did to the person who made it. A decision the user made is recorded as a pair, and marked as theirs so it is never confused with one made on their behalf:

- **The winning option's own line, copied as it was written to the user** — the bolded label plus its em-dash clause, one line (see Message shape). Not the label alone: "flag for review", read a week later, names nothing. Not the option list: the losing options are proposals the user rejected, and the document implementers treat as the spec is the wrong place to keep them. When the answer picks from a list defined in an earlier message rather than the one directly above it, the earlier message's line is the one to copy. For a binary question, which has no list, copy the sentence that named what was being decided.
- **Everything the user typed past the selector, verbatim.** Quote it. Don't smooth the grammar, don't finish the sentence, and don't fold it into the option's line. The selector is an address; the qualifier is the content, and it routinely changes what was decided — "(c), but you don't need to run the full suite" is not option (c). Recording the option's text as the answer when the user's own words narrowed it is how the wrong thing gets built.

A bare selector with nothing after it is recorded as a bare choice, and the record says so: write "no reason given" and leave it at that. Never attach a rationale the user didn't give. An invented one is indistinguishable from a real one, and the next reader — the reviewer, or an implementer weighing whether a hard failure justifies departing from the plan — treats it as something the user would defend.

```
**Decision (user, selected).** *Flag for review* — the cancel action marks the
payment for a person to refund. In their words: "b, but the queue has to be
per-property or support will never look at it." (Option text written by the agent.)

**Decision (user, selected).** *Refund on cancel* — the cancel action issues the
refund and marks the payment refunded. No reason given. (Option text written by
the agent.)

**Decision (user, originated).** *No refund after check-in* — a cancellation past
the check-in time keeps the charge. In their words: "we've never refunded those
and I'm not starting now."
```

**Which of the two it was.** A decision the user raised themselves and a decision they picked from options the agent wrote are different evidence, so the marker says which: `**Decision (user, originated).**` where the substance came from them, `**Decision (user, selected).**` where they chose from a list the agent wrote, and `**Decision (agent).**` for one made on their behalf. Plain `Decision (user)` is retired. A selected decision also records that the option text is the agent's, in a short parenthesis after the qualifier, so a reader can tell whose sentence they are looking at.

Both user forms carry the same weight. The plan-review merge worker never applies a finding over either, and every rule that protects a decision because the user made it protects both, unchanged. What differs is how the decision is cited: a later turn leaning on a selected decision says the agent wrote the wording, and never quotes the option line back as the user's own words. Their words are the part after the selector, and only that part. An interview asks enough questions that agreeing to a proposal is not the same as having written it, and a reader who is told otherwise defends a sentence they never composed.

**Four checks as an item's section is written.** A review finds two kinds of thing: judgment calls, which need a reader, and mechanical slips made while writing, which don't. These four are the slips. Run them as the section is written and again whenever it is revised — at the gate, or after a finding is applied — and none of them is ever recited to the user; they govern your own writing.

- **A decision that changes an item's premise means re-reading that item whole and reconciling it.** Appending the new decision under what is already there leaves every sentence written for the old premise standing beside it, reading as current, and an implementer has no way to tell which half to build. Reconciling means editing or deleting those sentences, not adding a correction below them.
- **Acceptance criteria are re-derived from the item's prose whenever it gains or changes a decision** — never edited in place beside the old ones. Writing them last isn't enough, because an item is never finished: it picks up decisions at the gate and from review rounds, and criteria patched next to their predecessors end up contradicting each other while the prose carries the user's actual answer. This is the check above applied to the criteria in particular.
- **Open every `file:line` as you write it into the plan.** The plan-review merge contract requires this before a finding is repaired; the same discipline applies one step earlier, to your own writing. An unopened citation sends an implementer to a line that says something else, and it reads exactly like a checked one.
- **A claim about the shape of the work is a factual claim — check it before it goes in.** "One-line change", "no test changes needed", "already covered by X", "the same in every build" all say something about the repository that is either true or not, and none of them is checked by being written confidently. In a project whose sources build into more than one output, that last shape is the recurring one, and it fails in both directions: asserting a seam that isn't there costs as much as missing one that is.

Cross-item interactions are normal during the interview. If answering item N's question forces a change to item M's detail (already written), update M in place and tell the user one short line: "Item M revised to match: <one-line summary>." Where the interaction is a fact both items turn on — a precedence order, a substitution several items make — write it once in the dashboard's Cross-item notes as well, rather than describing it separately in each. Each item still says what it does; the shared fact has one home.

When the interview is done, every item's section pins down the intent and the decisions other work depends on, enough that the implementer can't take it somewhere the user would veto. Reversible mechanics are deliberately left open: "decide this in contact with the code" is a valid, intended end state for a deferred choice, not a gap to be filled. What must be complete is the set of ask-lane answers, not a prescription of how every line gets written.
### Continuous learning + memory capture

This happens during item work, which now runs in subagents — so these instructions live in the subagent brief (Step 5), not in the orchestrator. The orchestrator captures memory only for things that surface in its own conversation (e.g., during the interview or at a blocker).

<!-- pln:only claude -->
- **Memory:** the moment something surfaces that fits an auto-memory category (user role, feedback, project fact, reference), write a new memory immediately to `~/.claude/projects/<project>/memory/` per the standard memory rules. Don't batch for end-of-task.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Memory:** the moment something surfaces that fits a memory category (user role, feedback, project fact, reference), record it immediately; don't batch for end-of-task. Codex keeps no memory directory of its own, so put it where the next session will actually see it: the item's Discoveries in `PLAN.md`, or the project's own notes / `AGENTS.md` when it is a durable project fact.
<!-- pln:endonly -->
- **Dream/Psychic learnings (gated):** active only when pre-flight saw both `RECORD_PSYCHIC_LEARNINGS` set and Dream/Psychic context. When active, the moment a learning surfaces that's not in `/psychic-skill`, append it to `<project-root>/WHAT_I_LEARNED_ABOUT_PSYCHIC_<YYYY-MM-DD>.md`. The filename is fixed, not parameterized by topic. Content scope is narrow: only learnings about Dream ORM and the Psychic web framework that are missing from `/psychic-skill`. The user is co-author of Dream/Psychic and uses this file to feed back to the skill maintainer. When the env var is unset, this entire concern is off and the orchestrator omits it from the subagent brief.
