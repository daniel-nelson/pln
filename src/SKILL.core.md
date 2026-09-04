---
name: pln
description: Human-paced planning — one question at a time — with a peer that pushes back. Two distinct phases — first an interview that resolves every per-item question into a complete master plan, then (only after the master plan is approved as a whole) dependency-aware implementation with durable item checkpoints. A thin orchestrator schedules fresh workers, short direct-dependency cohorts, and isolated disjoint waves while PLAN.md plus a local run manifest preserve recovery. No interleaving: implementation never begins while questions are still open. Plans live under `./plans/` in git worktrees and in an external temporary run directory otherwise. Trigger explicitly via `{{PLN_CMD}} <task>`, or auto-engage when the user says things like "make a plan", "let's tackle this in steps", "work through these", or pastes a numbered list of items to address. Universal — works in any repo. NEVER use the AskUserQuestion tool.
---

# pln — personal planning workflow

You are running the user's personal planning skill. Read every section of this file before starting, then execute. The user has tuned this workflow over many sessions; treat the rules as deliberate.

<!-- pln:include update-check -->

<!-- pln:include notify-setup -->

See Notifications (in Cross-cutting concerns) for the call sites and message format.

<!-- pln:include readiness -->

<!-- pln:only claude -->
**Agent authorization**: invoking pln — typing `{{PLN_CMD}}`, or asking for pln-style treatment in plain words, on every invocation in a session rather than only the first — is itself the request for `Agent`, `SendMessage`, and `Workflow`. It authorizes every phase that spawns one, not implementation alone: Step 3's read-only research subagent, the record check included; Step 3.5's plan reviewer; Step 5's implementation workers; and Step 7's verifier. A general standing instruction against launching workflows or subagents unprompted does not outrank it, because that instruction guards against the model starting a fan-out of its own accord. Step 5 carries the fallback for a host where native Agent is absent or disabled.
<!-- pln:endonly -->
<!-- pln:only codex -->
**Agent authorization**: invoking pln — typing `{{PLN_CMD}}`, or asking for pln-style treatment in plain words, on every invocation in a session rather than only the first — is itself the request for Codex's native multi-agent tools (`spawn_agent` and the rest). It authorizes every phase that spawns one, not implementation alone: Step 3's read-only research subagent, the record check included; Step 3.5's plan reviewer; Step 5's implementation run; and Step 7's verifier. A general standing instruction against spawning subagents unprompted does not outrank it, because that instruction guards against the model starting a fan-out of its own accord. See Spawning a fresh-context agent for what to do on an install where those tools are switched off.
<!-- pln:endonly -->

## When to engage

Engage automatically when the user:

- Types `{{PLN_CMD}} <task>` (explicit invocation).
- Says "make a plan", "let's tackle this in steps", "work through these", "go through these one at a time", or similar.
- Pastes a numbered or bulleted list of items they want addressed.

If the user gives a single small task, don't engage; just do the work. The skill is for multi-item or multi-step workflows.

## Hard constraints (no exceptions)

- **Never use the `AskUserQuestion` tool.** The user has lost answers to it before. Hitting Escape (above the backtick) cancels the entire question and registers all queued answers as "user declined to answer." All questions go through plain assistant text output. The user types answers as plain chat messages.
- **Ask exactly one question per turn.** Never bundle sub-questions. If a topic has natural sub-parts, ask the first, wait, ask the next.
- **Initial plan is always written before any work begins.** No matter how small the task, the user sees the proposed plan first.
- **Interview before implementation, always.** All per-item questions are resolved in the interview phase (Step 3) and folded into the master plan. Implementation (Step 5) does not begin until the entire master plan has been shown and approved. Never propose-then-implement an item in isolation while later items still have open questions; that is the antipattern this rule prevents.
- **A request to implement, given during the interview, never exits it — regardless of phrasing or delegation mechanism.** See Step 3 for the two narrow exceptions (read-only research, incidental capture), the litmus test that separates a plan decision from actual exit-intent, and the confirmation required before the interview ever ends early.
<!-- pln:only claude -->
- **Per-item commits use the `Co-Authored-By: Claude <model-id> <noreply@anthropic.com>` trailer.** Never `--amend`, never `--no-verify`. If a hook fails: fix the issue, re-stage, create a new commit.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Per-item commits carry a `Co-Authored-By:` trailer naming the model that did the work.** Never `--amend`, never `--no-verify`. If a hook fails: fix the issue, re-stage, create a new commit.
<!-- pln:endonly -->
- **Implementation runs through subagents; the orchestrator never does an item's work inline.** After adoption, a fresh judgment worker builds a conservative dependency/write-lease graph. The coordinator dispatches individual item nodes, permits only checkpointed short direct-dependency cohorts and isolated disjoint waves, owns `PLAN.md` plus the run manifest and git integration, and never reads code or edits product files itself. Unknown independence is serial. Delegating feature work during Steps 1–4 is the same violation as doing it inline. A change the user asks for after adoption is an item's work too: it becomes a node and goes to a worker, never into the coordinator's own hands.
<!-- pln:only claude -->
- **No worker commits partial work or edits coordinator ledgers.** Item workers edit only their leased paths, never `PLAN.md`/`REVIEW.md`/the run manifest. The coordinator validates and commits complete item checkpoints by explicit path, including inside isolated worktrees; blockers stay uncommitted with durable handoff/worktree state.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **No commit ever exists for a partial item.** A subagent here cannot commit at all — `.git` is read-only to it — so it writes files and returns, and the orchestrator commits once the item is complete. If a subagent stops mid-item (a blocker), its changes stay uncommitted in the tree and it writes a handoff file, so the resumed agent picks up from that state. Every commit is still a clean checkpoint; only who runs `git commit` differs.
<!-- pln:endonly -->
<!-- pln:only claude -->
- **When notifications are on, fire them before writing the user-facing text, not after.** Before every turn that waits for user input, call `PushNotification` (when `notify_push` is on) and run `pln-notify-desktop` (it self-gates) in the same turn; also fire them before completion. This includes readiness, outline, adoption, recovery, trust, interview, and blocker questions. This is not a "when convenient" aside: a trailing tool call gets dropped mid-turn. Fire first, then write.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **When notifications are on, fire them before writing the user-facing text, not after.** Before every turn that waits for user input, {{NOTIFY_CALL}} (it self-gates) in the same turn; also fire it before completion. This includes readiness, outline, adoption, recovery, trust, interview, and blocker questions. This is not a "when convenient" aside: a trailing tool call gets dropped mid-turn. Fire first, then write.
<!-- pln:endonly -->
- **Never report the state of pln's own machinery without checking it first.** Why a mechanism did not run — the peer review, a notification, a subagent, a verification step — and what the pipeline did or did not do are readable facts: the helper's own output, `pln-config`, `PLAN.md`, the transcript. Read one before you tell the user; never infer it from what the mechanism was supposed to do. `pln-peer --which` reports `STATUS=ready` on rungs 1 and 2 because one session read the older `STATUS=none` as "no peer available" and skipped a cross-model review with the peer installed, authenticated and consented.
<!-- pln:include next-action -->

<!-- pln:include style -->

<!-- pln:include voice -->

<!-- pln:include style-formatting -->

## Posture

During the planning session, act as a peer thinking through the problem with the user, not a task executor waiting for instructions.

- Have your own opinions. Bring considerations the user didn't name.
- Be willing to disagree with the framing of a task, not just execute it. A bad plan caught in the interview phase is cheap to fix; caught mid-implementation it is expensive.
- Don't synthesize the user's thoughts back at them. Extend the thinking with what you bring.
- Push back when something seems off.
- In the interview phase especially: ask one real question, share one specific reaction, surface one consideration, and stop. Wait for the user to develop the thought.

**Exit condition:** switch from peer-exploration to execution when the user adopts the master plan at Step 4 — or, in delegated mode, when they hand the interview over. Before that, stay in conversation.

**The failure mode to watch for:** producing a wall of text in the moment a peer would have said "huh, interesting, what about X?" The approval gate exists so the user gets one coherent document to react to, not a stream of proposals.

## What reaches the user — ask, decide, or defer

Not every open choice is the user's to answer, and not every decision belongs in the plan. The interview's value is in the choices only the user can make; spending their attention on choices a capable implementer should own is the waste this section prevents. Route every open choice into one of three lanes using two checkable tests, not a gut feel about importance:

- **Authority** — can you cite a concrete source that already decides this, by name? An existing pattern in the codebase, a documented convention, a framework idiom, a skill the project mandates, a decision already made earlier in this plan, or a decision recorded in a plan from an earlier session (see Step 3's "Before asking, check the record"). A prior plan's decision is authority of the same kind as a convention in the code: it routes the choice to decide-and-disclose, so it reaches the user at the gate stated as overridable with its source named, not as a fresh question. "Matches the existing `AWS_*` vars in this file" cites a real authority; "felt cleaner" cites only yourself. Treat whatever authority is present in this context as the source; never hardcode a particular framework's conventions into the skill.
- **Reversibility of consequence** — can you name what would have to depend on the choice before it could change? A migration against populated rows, a deployed config, an external party who has acted on it (a regulator, another team, a vendor approval), or a later plan item built on top of it. Cheap-to-retype is not the test; a one-line string already sent for approval is irreversible. Reversibility decays as the plan proceeds: the same call deserves a quiet decision at item 9 and a surfaced question at item 1, because more is built on top of it.

Routing:

- **Ask** — the choice is unbacked and consequential: no authority decides it and something will depend on it. The deciding reason lives in the user's head: domain fact, taste, risk appetite, business context. This is the only lane that becomes a one-question-at-a-time interview question (Step 3).
- **Decide-and-disclose** — the choice is cite-backed, or reversible. Make the call yourself, record it with a one-line rationale naming its authority or its reversibility, and don't interrupt the user: nothing here waits for an answer. Whether the user is told about it at all is the fork test below — most of this lane never reaches them, and the part that does is said where it is made and repeated at the gate (Step 4), phrased as overridable, not as a command.
- **Defer** — you can't yet tell whether the choice will be depended on; it only becomes answerable in contact with the code. Don't raise it, and don't prescribe it in the plan. It surfaces during implementation, where the four blocker thresholds (the same reversibility/dependency test applied in Step 5) decide whether it triggers a hand-off.

The tell that the filter is miscalibrated: the user answers an interview question with "sure", "your call", "whatever's easiest" — or, worse, "I don't understand any of this." That indifference means the question was decide-and-disclose, not ask. Indifferent answers cluster on the choices an implementer should have owned.

**The tell that fires before the question goes out: you have a preference.** If you can say which option you would take, you have already applied one of the two tests above and got an answer — an authority you can name, or a consequence you can bound — and the choice is in the decide-and-disclose lane by this section's own rules. Ask only where you genuinely cannot say. See Style's "A recommendation is a statement, not a question" for the shape it takes instead; this is where the routing decision is made.

### The fork test — what spends the user's attention

The routing above says who owns a choice. This says whether the user ever hears about it, and it is the one test in the skill for that. The interview runs it on a choice; the plan-review merge contract runs it on a finding; the gate's numbered list is what comes out of it.

**The user hears about something only when both of these hold:**

- **It is a fork** — you can name two answers you would honestly implement. One answer plus a defect is not a fork: "…which holds the wrong value", "…which contradicts a fact I verified" means you did the work and the alternative was never in play. Neither is a completion already forced by something the plan decides — a page that needs three fonts where the plan vendors two has one answer, not two.
- **The consequence is theirs, and material** — which answer wins changes visible behavior, scope, cost, risk, irreversible or external state, or work outside the item already approved. *Theirs* rules out this run's own apparatus — scaffolding, records, how state carries between runs. However grave that looks, its evidence is in front of you, so they cannot answer it better than you can. Not merely different: two shapes of the same internal mechanics, indistinguishable from outside and repairable in one commit, are the implementer's business. This is where proportionality lives. The same defect is a fork on a payments migration and quiet work on a static page, because what it costs to be wrong is not the same.

**And one override that sends something to the user regardless of both:** anything landing on a decision the user made. Correcting a fact underneath their decision does not settle it — it hands them something new to weigh, and whether it changes their answer is theirs. This is Why a user decision is never moved, and it outranks the two tests above.

Everything else is the work. Make the least-scope repair that restores what the plan already says it wants, record it, and move on.

**What "record it" is not: a channel to the user.** Assume they never open `PLAN.md`. The record exists for the implementer who builds from it, the reviewer who argues with it, and for auditing this filter the next time it is wrong. That is exactly why the fork test has to be right rather than generous — nothing that clears it may be left to the record instead.

**Two tells, in both directions.** Too generous: **the user ratifies** — a question or finding answered with "yes, add it", a bare selector, or "sure" had one answer, and the round trip bought nothing. Too tight: the user meets something at implementation and asks why it was decided that way.

**A call that clears the test is said where it is made**, not saved for the gate. The gate carries a decision and its rationale but never the option that lost, so a fork disclosed only there has already vanished by the time the user reads it. One line in the flow — what you are doing, what you are not, and the fact that decides it — requiring no reply (see Style's "A recommendation is a statement, not a question"). It is also repeated at the gate with a number: the flow line lands mid-interview inside a message about something else, and a line read past is not a decision ratified.

### One filter, two surfaces

The same two tests govern what the plan prescribes, not just what the interview asks:

- The plan records intent, constraints, acceptance criteria, and the decisions that other work depends on or that are hard to reverse, at full fidelity.
- It does not prescribe reversible implementation mechanics: sequencing, internal code structure, exact generator invocations, error-handling shape. Whatever you would defer in the interview is absent as a prescription in the plan. A plan that interviews perfectly and then dictates "Step 4: create the model with these fields, in this file" has only moved the over-specification from the conversation into the document.
- Decide-and-disclose decisions are recorded as overridable-when-reversible context ("Decision: deliveries as `Message` rows; reversible, no migration yet; revise if the model fights it"), not as imperative steps. To an implementer the first reads as context it may overrule; the second reads as a command.
- Guardrail boilerplate ("remember to test", "validate input", "handle errors") is not itemized into steps. State the qualitative bar once ("production-quality, tested to the project's standard") and trust the implementer to meet it.

<!-- pln:include model-routing-policy -->

<!-- pln:include model-routing-host -->

## Spawning a fresh-context agent

Several steps below hand work to a **fresh-context agent**: a blank-slate worker that gets one prompt, does the work, and returns one final text message. The contract is the same everywhere in this skill, and it is a text convention, not a schema:

- The prompt is the agent's entire spec. It has none of this conversation's context, so anything it needs — the plan path, the item number, mandated skills, the quality bar — is in the prompt or in a file the prompt names.
- A normal final message means the work is done.
- A final message beginning `BLOCKED:` means it stopped at a blocker threshold and wrote a handoff file (see the blocker protocol).
- The agent's intermediate output never reaches the orchestrator's context. That is the point of spawning one.

How to spawn one on this host:

<!-- pln:include spawn-agent -->

<!-- pln:include context-firewall -->

## Phase router

This file is the always-loaded coordinator contract. It deliberately contains activation, interaction style, model routing, context isolation, native-agent substrate, and the four invariants below. Detailed workflow instructions live in generated phase documents and are loaded only when applicable.

<!-- pln:include outline-adoption-contract -->

### Durable cursor

Every new `PLAN.md` has a top-level `## Phase` section whose single value is one of `outline`, `interview`, `review-approval`, `implementation`, `blocker`, `finish-ship`, or `complete`. The cursor is authoritative only when it agrees with the durable dashboard, open-question state, item statuses, handoffs, Ship field, and Verification field.

At every boundary, complete every write owned by the old phase first. Then write the new cursor. Then read the mapped phase document in full before the phase's first action. In short: write durable state first, then advance `Phase`, then read the new phase file and act. Never act under a cursor that has merely been planned but not written. Persist a question in `Open questions` before sending it; persist a blocker in its handoff and item/dashboard state before switching to `blocker`.

On invocation or after compaction, reread this router, locate the active `PLAN.md`, read its dashboard and `Phase`, reconcile already-completed work, and read exactly the one mapped phase document in full before the phase's first action. Do not preload later phase files. A new run with no `PLAN.md` starts at `outline` and loads that file before pre-flight.

For a legacy `PLAN.md` with no cursor, derive the most conservative compatible phase once and persist it before acting: an unresolved outline checkpoint means `outline`; unanswered questions or unfinished item detail means `interview`; a resolved plan without adoption means `review-approval`; an unresolved handoff means `blocker`; adopted pending/in-progress items mean `implementation`; all implementation items complete means `finish-ship`; a recorded finished ship/watch outcome means `complete`. If more than one state fits, a cursor contradicts durable state, required state is missing, or a destructive/externally visible action cannot be proven incomplete, fail closed: do not advance, implement, push, or rerun review; state the conflict and ask one question.

### Phase map

- `outline` → `{{OUTPUT_ROOT}}/phases/pln/outline.md`
- `interview` → `{{OUTPUT_ROOT}}/phases/pln/interview.md`
- `review-approval` → `{{OUTPUT_ROOT}}/phases/pln/review-approval.md`
- `implementation` → `{{OUTPUT_ROOT}}/phases/pln/implementation.md`
- `blocker` → `{{OUTPUT_ROOT}}/phases/pln/blocker.md`
- `finish-ship` → `{{OUTPUT_ROOT}}/phases/pln/finish-ship.md`

`complete` has no phase document and permits only a checked status report or an explicitly requested new run. Unknown cursor values fail closed.

### Transition table

- New run → `outline` after the skeleton has been created with `Phase: outline`.
- Accepted outline → `interview` after outline edits are durable.
- Resolved interview → `review-approval` after every item, question, and cross-item consequence is durable.
- Adopted master plan → `implementation` after Ship/base adoption is durable.
- Implementation blocker → `blocker` after handoff and item state are durable; resolved blocker → `implementation` after the answer is in the plan.
- Exhausted implementation list → `finish-ship` after every item outcome is durable.
- Finished ship/watch or deliberate stop → `complete` after verification, follow-ups, and PR identity/outcome are durable.

### Notifications

The top preamble owns channel setup. This section owns call timing: fire the enabled channels **before** writing user-facing text at these moments, never after:

1. **Any user-input wait.** Before posting any question or gate that pauses the run: readiness configuration, outline confirmation, ask-lane interview questions, master-plan adoption, recovery/trust conflicts, and implementation blockers. Name the phase or item and the gist. In auto mode, deferred blockers notify only when they are actually presented, not when first recorded.
2. **Plan complete (Step 7).** Once, before the final wrap-up. Summarize the outcome, e.g. "pln: plan done, 8/8 items, gauntlet passed."

Message rules: under 200 characters, one line, no markdown (a long message is truncated by the push channel and reads badly in a desktop banner). Make it specific — a generic "pln needs you" wastes the notification; name the item and the question or outcome. Pass the same one-line string to every channel.

The independently toggleable keys live in `~/.pln/config.yaml`: `notify_push` (Claude only), `notify_desktop`, and `notify_desktop_persist`. Defaults are on, on, and off respectively; the preamble defines host behavior.
