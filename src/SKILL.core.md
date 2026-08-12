---
name: pln
description: Human-paced planning — one question at a time — with a peer that pushes back. Two distinct phases — first an interview that resolves every per-item question into a complete master plan, then (only after the master plan is approved as a whole) an implementation phase that walks the items one at a time. Implementation runs autonomously: a thin orchestrator spawns a fresh subagent per item, with `PLAN.md` as the durable source of truth, so the whole plan executes without per-item intervention. No interleaving: implementation never begins while questions are still open. Plans live at `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` relative to the session CWD. Trigger explicitly via `/pln <task>`, or auto-engage when the user says things like "make a plan", "let's tackle this in steps", "work through these", or pastes a numbered list of items to address. Universal — works in any repo. NEVER use the AskUserQuestion tool.
---

# pln — personal planning workflow

You are running the user's personal planning skill. Read every section of this file before starting, then execute. The user has tuned this workflow over many sessions; treat the rules as deliberate.

<!-- pln:include update-check -->

<!-- pln:include notify-setup -->

See Notifications (in Cross-cutting concerns) for the call sites and message format.

<!-- pln:only claude -->
**Agent authorization**: invoking pln — typing `/pln`, or asking for pln-style treatment in plain words, on every invocation in a session rather than only the first — is itself the request for `Agent` and `Workflow`. It authorizes every phase that spawns one, not implementation alone: Step 3's read-only research subagent, the record check included; Step 3.5's plan reviewer; Step 5's implementation run; and Step 7's verifier. A general standing instruction against launching workflows or subagents unprompted does not outrank it, because that instruction guards against the model starting a fan-out of its own accord. Step 5 carries the full resolution and the fallback for a session where `Workflow` is missing or refused.
<!-- pln:endonly -->
<!-- pln:only codex -->
**Agent authorization**: invoking pln — typing `/pln`, or asking for pln-style treatment in plain words, on every invocation in a session rather than only the first — is itself the request for Codex's native multi-agent tools (`spawn_agent` and the rest). It authorizes every phase that spawns one, not implementation alone: Step 3's read-only research subagent, the record check included; Step 3.5's plan reviewer; Step 5's implementation run; and Step 7's verifier. A general standing instruction against spawning subagents unprompted does not outrank it, because that instruction guards against the model starting a fan-out of its own accord. See Spawning a fresh-context agent for what to do on an install where those tools are switched off.
<!-- pln:endonly -->

## When to engage

Engage automatically when the user:

- Types `/pln <task>` (explicit invocation).
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
- **Implementation runs through subagents; the orchestrator never does an item's work inline.** In the implementation phase (Step 5) the main session is a thin orchestrator: it reads `PLAN.md`, spawns one subagent per item, checks the file was updated, and moves on. It does not read code or edit files itself. Doing the work inline defeats the fresh-context guarantee and fills the orchestrator's context across the run. Delegating an item's feature work to a sub-agent during Steps 1–4 is the same violation as doing it inline — see Step 3 for what counts as feature work and the two exceptions that are fine mid-interview.
<!-- pln:only claude -->
- **A subagent commits only a complete, verified item — never partial work.** If a subagent stops mid-item (a blocker), it leaves its changes uncommitted and writes a handoff file; it never commits a half-done item. This keeps every commit a clean checkpoint and lets a fresh subagent resume from the uncommitted state.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **No commit ever exists for a partial item.** A subagent here cannot commit at all — `.git` is read-only to it — so it writes files and returns, and the orchestrator commits once the item is complete. If a subagent stops mid-item (a blocker), its changes stay uncommitted in the tree and it writes a handoff file, so the resumed agent picks up from that state. Every commit is still a clean checkpoint; only who runs `git commit` differs.
<!-- pln:endonly -->
<!-- pln:only claude -->
- **When notifications are on, fire them before writing the user-facing text, not after.** At each of the three notify moments (interview question, blocker, completion), call `PushNotification` (when `notify_push` is on) and run `pln-notify-desktop` (it self-gates) in the same turn, before producing the message the user reads. This is not a "when convenient" aside: asking the model to fire a notification *after* it has already written the text is the exact wording that made an earlier version fail — the trailing tool call gets dropped mid-turn. Fire first, then write.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **When notifications are on, fire them before writing the user-facing text, not after.** At each of the three notify moments (interview question, blocker, completion), {{NOTIFY_CALL}} (it self-gates) in the same turn, before producing the message the user reads. This is not a "when convenient" aside: asking the model to fire a notification *after* it has already written the text is the exact wording that made an earlier version fail — the trailing tool call gets dropped mid-turn. Fire first, then write.
<!-- pln:endonly -->
- **Never report the state of pln's own machinery without checking it first.** Why a mechanism did not run — the peer review, a notification, a subagent, a verification step — and what the pipeline did or did not do are readable facts: the helper's own output, `pln-config`, `PLAN.md`, the transcript. Read one before you tell the user; never infer it from what the mechanism was supposed to do. `pln-peer --which` reports `STATUS=ready` on rungs 1 and 2 because one session read the older `STATUS=none` as "no peer available" and skipped a cross-model review with the peer installed, authenticated and consented.

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
- **Decide-and-disclose** — the choice is cite-backed, or reversible. Make the call yourself. Record it with a one-line rationale that names its authority or its reversibility. Don't interrupt the user: nothing here waits for an answer. These surface at the gate (Step 4), in its numbered list, phrased as overridable, not as commands.

  **Most of what lands in this lane is never told to the user at all.** The lane's bar is low on purpose — cite-backed *or* reversible describes nearly every choice an implementer makes in an hour — so a lane treated as a disclosure list becomes a log of the agent's own work, and the two or three calls the user would actually have changed are buried in it. A call is told to the user only when all three of these hold:

  - **The runner-up is live** — you can name what you rejected without arguing that it was wrong. If naming it needs "…which holds the wrong value", "…which the repo's rule forbids", or "…which contradicts a fact I verified", there was no fork: you did the work and the alternative was a defect.
  - **The user holds the stake** — the alternative changes something they meet: behavior, cost, scope, a file they read, work they'd have to do later. Two shapes of the same internal mechanics, indistinguishable from outside, are the implementer's business.
  - **The deciding fact is yours, not theirs** — if what settled it is an answer they gave earlier this session, or a rule written in their own repo, saying it back tells them what they already told you. Follow it and say nothing.

  Fail any one and it is not a decision, it is the work. Record it in its item's section, where the reviewer and the implementer read it, and let the plan carry it. Measured on a real gate: of six disclosed decisions, one dropped a colour variable holding the wrong value, one followed the repo's own version-bump rule, and one named the single doc that describes the file being replaced — half the list, none of it anything the user could have wanted otherwise.

  **A call that clears all three is said where it is made**, not saved for the gate. The gate carries a decision and its rationale but never the option that lost, so a runner-up disclosed only there has already vanished by the time the user reads it. One line in the flow — what you are doing, what you are not, and the fact that decides it — requiring no reply (see Style's "A recommendation is a statement, not a question", which also caps this at one per message). This is the lane's safety valve: the user's corrections in a real interview come as "that's the wrong framing" far more often than as "I pick (b)", and they can only arrive if the framing was visible.
- **Defer** — you can't yet tell whether the choice will be depended on; it only becomes answerable in contact with the code. Don't raise it, and don't prescribe it in the plan. It surfaces during implementation, where the four blocker thresholds (the same reversibility/dependency test applied in Step 5) decide whether it triggers a hand-off.

The tell that the filter is miscalibrated: the user answers an interview question with "sure", "your call", or "whatever's easiest." That indifference means the question was decide-and-disclose, not ask. Indifferent answers cluster on the choices an implementer should have owned.

**The tell that fires before the question goes out: you have a preference.** If you can say which option you would take, you have already applied one of the two tests above and got an answer — an authority you can name, or a consequence you can bound — and the choice is in the decide-and-disclose lane by this section's own rules. Ask only where you genuinely cannot say. See Style's "A recommendation is a statement, not a question" for the shape it takes instead; this is where the routing decision is made.

What this reroutes is the round trip, never the visibility. A preference that goes unsaid is worse than one put as a needless question, because the user cannot overrule what they were never shown — so the disclosure is the part that survives, and it is what the decide-and-disclose lane above requires in the flow.

### One filter, two surfaces

The same two tests govern what the plan prescribes, not just what the interview asks:

- The plan records intent, constraints, acceptance criteria, and the decisions that other work depends on or that are hard to reverse, at full fidelity.
- It does not prescribe reversible implementation mechanics: sequencing, internal code structure, exact generator invocations, error-handling shape. Whatever you would defer in the interview is absent as a prescription in the plan. A plan that interviews perfectly and then dictates "Step 4: create the model with these fields, in this file" has only moved the over-specification from the conversation into the document.
- Decide-and-disclose decisions are recorded as overridable-when-reversible context ("Decision: deliveries as `Message` rows; reversible, no migration yet; revise if the model fights it"), not as imperative steps. To an implementer the first reads as context it may overrule; the second reads as a command.
- Guardrail boilerplate ("remember to test", "validate input", "handle errors") is not itemized into steps. State the qualitative bar once ("production-quality, tested to the project's standard") and trust the implementer to meet it.

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

**Adoption is given once, in advance.** The instruction that entered the mode is the adoption signal for the run, so both prompts that would otherwise block are self-adopted: write the Step 2 skeleton and keep going, and move from the finished plan into Step 5 without showing it for approval. Record `Ship: PR after implementation` in the dashboard — the mode takes the implement-and-open-a-PR shape of Step 4's three-way prompt.

**What still stops the run: one short list, printed before implementation starts.** Three things reach it, each resolved with the user before Step 5 begins:

- A decision that reverses something already settled or already built, or one that cannot be undone. Record the reversals in the dashboard's Reversals section as well, so `/pln-pr` carries them into the PR body.
- A Step 3.5 finding the review flagged rather than applied. Flagged findings are the gate's business (see What a finding becomes), and there is no gate here, so a flagged false factual claim would otherwise be built with nobody having seen it.
- A question the sources above do not answer.

Print the list, then offer to walk it the way Step 4 offers to walk its triaged entries — one question per turn, each item restated in full, per Walking the flagged entries. There is no gate in this mode, so this is where that offer lives. Declining is itself the answer to the list: the user has read it and said go, and Step 5 starts. What the offer replaces is a list the user can only act on by naming entries back at you.

Nothing waives that list, including a spoken "just go, don't check with me" — that instruction is what entering the mode already means, and the list is what it was traded against. A run with nothing on the list says so in one line and proceeds. Everything else runs without interruption, which is the point of the mode.

## Spawning a fresh-context agent

Several steps below hand work to a **fresh-context agent**: a blank-slate worker that gets one prompt, does the work, and returns one final text message. The contract is the same everywhere in this skill, and it is a text convention, not a schema:

- The prompt is the agent's entire spec. It has none of this conversation's context, so anything it needs — the plan path, the item number, mandated skills, the quality bar — is in the prompt or in a file the prompt names.
- A normal final message means the work is done.
- A final message beginning `BLOCKED:` means it stopped at a blocker threshold and wrote a handoff file (see the blocker protocol).
- The agent's intermediate output never reaches the orchestrator's context. That is the point of spawning one.

How to spawn one on this host:

<!-- pln:include spawn-agent -->

## Consulting a peer model

Some of this skill's work is worth putting to a **peer**: a model other than the one running this session, asked to check what that model produced. A fresh agent on this host is a fresh context; a peer is a fresh context *and* a different set of blind spots. Below, `$PLN_BIN` stands for `{{SKILL_DIR}}/bin` — substitute the real path when you run it.

<!-- pln:include peer-consult -->

## The plan review switch

Before the approval gate, the finished plan itself goes under review (Step 3.5): a reader that never saw the interview argues with the plan and checks its claims against the files it names. It is on by default, and exactly two things turn it off — a standing preference in config, and an instruction in the session. Nothing else does. **The size of the plan never does:** a two-item plan and a twelve-item plan get the same review. There is no small-plan shortcut, because the reviewer's cost is reading the plan and checking its claims, which already scales with the plan, and because the short plan is regularly the dangerous one — two items that change how every future run behaves are worth more scrutiny than nine items of one-line edits.

**The standing preference** is `plan_review` in `~/.pln/config.yaml`, read once where the review would start:

```bash
{{SKILL_DIR}}/bin/pln-config get plan_review
```

`false` or `no` means off, for every plan in every repository. Anything else — including absent, which is what an install that has never been told otherwise reads — means on. Off is a clean no-op rather than a degraded run: no brief is assembled, no peer is selected, no consent question is raised, and Step 4 is exactly the gate it would have been without the step. Don't announce the skip; a line explaining what didn't happen is noise on every plan of a user who already opted out. `{{SKILL_DIR}}/bin/pln-config set plan_review false` turns it off, `true` back on.

**A spoken instruction wins over the key, for that run only**, in both directions — "skip the review" where the key is on, "review this one" where it is off — and never writes to config. Config is the standing preference; a sentence is about this plan. Honor it whenever it arrives before the gate, including mid-interview, and don't literal-match: infer the intent from natural phrasing, the way the defer / drop / think-offline signals are inferred.

The review has three parts that can be switched off separately, and an instruction naming one leaves the others running:

- **The whole step** — "skip the review", "no review this time", "straight to the gate". Step 3.5 doesn't run.
- **The peer** — "skip the cross-model pass", "don't send it anywhere", "keep it local". The review still runs, on a fresh same-model agent, exactly as if no peer had been available. Treat it as a `peer_consent` of `false` for that run: nothing is sent, no consent question is raised, and the result says which rung ran as always.
- **Applying anything** — "just tell me, don't change the plan", "flag everything". The review runs and every finding reaches the gate flagged; nothing is written into `PLAN.md`.

An instruction broader than any one of those (a bare "skip it") is the whole step. When it is genuinely ambiguous which part is meant, ask one short question instead of guessing — guessing wrong either sends a plan the user meant to keep on the machine, or throws away a review they wanted.

## The reviewer's brief

Step 3.5's reviewer is a stranger to the conversation, and it gets the plan and nothing else: not the interview transcript, not the user's turns, not the options that lost. The plan is already the whole artifact every implementer works from. If the reviewer needs more than the plan to argue with it, the plan is the defect — and saying so is one of the findings worth having.

The same brief goes to everyone who reads the plan — a peer CLI *and* a fresh same-model agent, or whichever of the two is available (see Consulting a peer model). Write it once to a file and use it on every rung and for both readers. Two briefs that say almost the same thing drift, and then a finding depends on which reader happened to produce it.

What the brief carries:

- **The plan itself, inline and whole.** A peer may be a plain prompt-in, text-out CLI with no way to open a file, so the text goes in the brief rather than a path to it. Name `PLAN.md`'s path and the repository root as well, for a reviewer that *can* read — that is what makes checking the plan's claims possible at all. Name the commit the tree is at too (`git rev-parse HEAD`): the plan's claims are about that state, and a reader that finds `HEAD` somewhere else can say the files have moved instead of reporting the difference as the plan's error.
- **What a plan is**, in two lines, because the reviewer has likely never seen one: a dashboard plus one section per item, where each item is implemented by a fresh agent that reads that section and nothing else, and the sections record both the decisions the user made and the decisions the plan's author made on their behalf.
- **The instruction to be adversarial**, with the reason this plan in particular needs it: it was written by the same model that ran the interview, so it carries that conversation's assumptions and cannot see them, and it is biased toward changes that feel productive. No praise, no inventory of what the plan gets right — the parts that are fine need no comment.
- **Check the plan's factual claims against the files it names.** A plan asserting something untrue about the code it edits is the failure this step exists to catch, and it is invisible from inside the conversation that wrote it.
- **Every finding quotes what it rests on** — `file:line` and the verbatim text for a claim about the repository, the plan's own sentence for a contradiction between two of its parts. A reviewer that cannot open files says so per claim instead of guessing; an unquoted correction from a reviewer with no repository access is exactly the confident wrong answer that must never reach the plan.
- **A counterfactual, per item.** Take the problem the plan says exists today and ask whether the plan as written would actually have caught it. A bare "review this plan" produces agreement; a concrete artifact plus "would this have caught it?" produces the finding worth having. Where the plan quotes something real — an output, a message, a behavior the user objected to — that is the artifact; where it doesn't, the item's own acceptance criteria are.
- **Finding nothing is a permitted answer**, said in those words. A review required to produce findings manufactures them, and a manufactured finding that quotes a line reads exactly like a real one.

A brief that carries all of it, ready to fill in:

```
Review the plan below. It was written by an AI agent during an interview with the
user it works for, and it is what the implementers build from. A plan is a
dashboard plus one section per item; each item is implemented by a fresh agent
that reads that section and nothing else. The sections record decisions the user
made and decisions the agent made on their behalf.

Repository root: <path>. The plan file is <path to PLAN.md>. Read any file the
plan names. If you cannot read files, say so per claim rather than guessing.
The plan's claims describe the repository at commit <sha>. If HEAD is not that
commit, the tree has moved past what the plan was written against: say so, and
don't report the difference as a false claim in the plan.

--- PLAN ---
<the plan, verbatim and whole>
--- END PLAN ---

Be adversarial. The plan was written by the same model that ran the interview, so
it carries that conversation's assumptions and cannot see them, and it leans
toward changes that feel productive. Don't tell me what it gets right.

Check its factual claims against the files it names. For each item, take the
problem the plan says exists today and ask whether the plan as written would
actually have caught it.

Every finding quotes what it rests on: `file:line` plus the verbatim text for a
claim about the code, or the plan's own sentence for a contradiction between two
parts of the plan. A claim you could not verify is reported as unverified — not
dropped, and not asserted.

Report each finding as: which item it lands on, one sentence on what is wrong,
the quote it rests on, what you would change, and which kind it is — a false
factual claim, a contradiction inside the plan, or a judgment call (one that
turns on taste, risk appetite or domain knowledge).

"Nothing worth changing" is a complete answer. Don't manufacture findings.
```

The kind label is the reviewer's own reading, and it travels as a claim rather than an instruction: what happens to a finding is decided when the result comes back, not by the reviewer that wrote it.

**Why nothing else travels.** The transcript carries the writing model's own rationalizations alongside the user's words, and a reviewer that reads those is primed by the reasoning it was brought in to audit. Quoting the rejected options has the same effect one step further on: it re-argues a question the user already closed. What makes the plan enough on its own is Step 3's recording rule — a decision is written down as the chosen option's own line plus everything the user said past the selector, so a reader who never saw the interview reads the same decision the user made.

## What a finding becomes

A finding that comes back from Step 3.5 is either **applied** — the plan's own prose is corrected before the user sees it — or **flagged**, which leaves the plan alone and puts the finding at the approval gate for the user to act on. That call is made here, not by the reviewer. Most findings are flagged, and that is the design: applying one is an edit to the document every implementer builds from, made by a reader the user never met.

A finding is applied only when all three of these hold. Failing any one of them flags it:

- **It is a false factual claim, or a contradiction between two parts of the plan.** Those are the two kinds where being right is checkable without knowing what the user wants. Anything turning on taste, risk appetite or domain knowledge is a judgment call and is flagged. The reviewer's own kind label is a claim, not a verdict — read the finding and decide the kind yourself. A stranger to the interview files a decision it disagrees with as a factual error routinely.
- **It quotes what it rests on, and the quote is real.** `file:line` plus the verbatim text for a claim about the repository; the plan's own sentence for a contradiction between two of its parts. Open the file at that line and confirm the text is there before applying anything — a peer with no way to read the repository can still produce a well-formed, confident, invented citation, and that is exactly the finding that would otherwise land in the plan with nobody having seen it. An unquoted finding is flagged however certain it reads, and so is one the reviewer itself reported as unverified. Confidence is not evidence.
- **It does not land on a decision the user made.** The plan marks those as theirs (see "How a decision is recorded" in Step 3) — look for a decision recorded as the user's rather than matching a fixed string, since the marker is a convention and not a syntax. One the user selected from options the agent wrote is as much theirs as one they raised themselves; that distinction changes how a decision is quoted back, never whether it is protected.

**Why a user decision is never moved.** A choice reached the user in the first place because nothing already decided it and the deciding reason lived in their head: a domain fact, taste, risk appetite, business context. Correcting a fact underneath such a decision does not settle it — it gives the user something new to weigh, and whether that changes the answer is theirs. This is the blocker protocol one phase earlier: an implementer that discovers the plan won't work as written stops and hands the question back instead of deciding it, and a reviewer that discovers a decision rested on something false is the same event, found sooner. The correction is not lost — it goes to the gate flagged, with its quote, so reopening the decision there costs one reply.

**Applying one.** Edit the sentences the finding lands on and nothing else: correct the false claim, or make the two contradicting parts agree. Where they cannot be made to agree without picking which one survives, picking is the judgment call — flag it instead. An applied correction never adds an item, widens scope, or rewrites acceptance criteria. Record it in that item's detail section: what the plan said, what it says now, the quote it rested on, and which reader found it. That record is what keeps the correction from being silent — it has to reach the gate (Step 4) even if the context between here and there compacts.

**Flagging one.** Same place, same one line, carrying the reviewer's proposed change rather than an applied one, plus which kind it is and who found it — a peer, or a fresh same-model agent (see Consulting a peer model). A reader weighs a finding differently depending on whose eyes were on the plan. A finding that lands on the plan as a whole rather than on one item — a missing item, an ordering that won't work — is always flagged, because acting on it changes scope; record it in the dashboard's Open questions.

**Two readers, one record.** Where a peer and a same-model agent both read the plan, their findings merge before anything is filed: a defect both raised is one finding, recorded once, naming both readers. Merge first, then write `PLAN.md` once. Filing each reader's findings as they land runs two edit passes over the same file and numbers one defect twice at the gate.

**Both of those happen in one merge agent**, not in the orchestrator — Step 3.5's last item spawns it, and everything above is its brief. Fifty findings read one by one in the context that has to run the gate is the cost the delegation removes, and it is the same call `/pln-pr` makes at its own merge step.

**Confirm the write landed.** Re-read the section you just wrote and check the text is there — merge agent or not, whoever files a finding. A batch of edits over one file can fail on a single bad match and take the edits before it with it, and what comes back says the batch failed, not which of them exist. A finding recorded nowhere while the record says it was filed reaches nobody. This is the hard constraint against reporting a mechanism's state without checking, applied to your own write.

**"Nothing worth changing" is a result, not a failed review.** Record nothing, and let the gate say the review ran and found nothing. Promoting a weak finding so the step looks worthwhile is how a manufactured finding becomes a plan change.

## The workflow (sequential steps)

Steps 1–8 run in order, top to bottom. The skill has two distinct conversational phases separated by an explicit approval gate:

- **Interview phase** (Step 3) — questions only, no code changes, no commits. Walks every item end-to-end, captures decisions in the master plan.
- **Plan review** (Step 3.5) — a reader who never saw the interview argues with the finished plan before the user is asked to adopt it. Still no code changes; only `PLAN.md` is written to.
- **Master-plan approval gate** (Step 4) — show the complete master plan, get a single yes-to-the-whole. Self-adopted in delegated mode, where that yes was given in advance.
<!-- pln:only claude -->
- **Implementation phase** (Step 5) — a thin orchestrator runs one Workflow script covering every item, sequentially, with `PLAN.md` as the spec. No more discussion questions; the only interruptions are a blocker threshold, which pauses and resumes the same run.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Implementation phase** (Step 5) — a thin orchestrator walks the items one at a time, spawning a fresh-context agent per item with `PLAN.md` as the spec. No more discussion questions; the only interruptions are a blocker threshold, which pauses the loop and resumes the blocked item.
<!-- pln:endonly -->

Implementation never begins while items still have open per-item questions. If the user redirects mid-interview ("just go do item 1 now"), note gently that the rest of the interview comes first; the point of the two-phase split is to avoid the "answer Q1, implement, then ask Q2" antipattern.

Cross-cutting concerns (mid-item discovery, auto-mode behavior, spinoffs, continuous learning + memory) are described in the next section.

### Step 1. Pre-flight

Before producing the initial plan, do all of:

1. Read `CLAUDE.md` and `AGENTS.md` at the project root and any nested ones the task touches. Surface any mandated rules (e.g., "invoke the project's required skill first") and persistent TODOs at the top of the eventual `PLAN.md`.
2. Auto-invoke any skill the project explicitly mandates. Document the auto-invocation in the plan.
<!-- pln:only claude -->
3. Read relevant memories from `~/.claude/projects/<project>/memory/` to inform the initial plan.
<!-- pln:endonly -->
<!-- pln:only codex -->
3. Read any project memories this host keeps, to inform the initial plan. Codex has no built-in memory directory, so look at what the project itself carries: `AGENTS.md`, a `docs/` or notes directory, and anything a previous pln run left under `./plans/`.
<!-- pln:endonly -->
4. Check `printenv RECORD_PSYCHIC_LEARNINGS`. If it is unset or empty, skip Dream/Psychic detection entirely — do not detect it, write to a `WHAT_I_LEARNED_ABOUT_PSYCHIC_*.md` file, or mention Dream/Psychic to the user anywhere in the session. Only when it is set: detect Dream/Psychic context (`@rvoh/dream` or `@rvoh/psychic` in `package.json`, presence of a `psy` CLI, or `CLAUDE.md` requiring `psychic-skill`) and cache the result; it gates the learning-capture cross-cutting concern below.
5. Discover verification commands:
   1. Read `CLAUDE.md` / `AGENTS.md` for a completion rule or "before pushing" section.
   2. If silent there, inspect `package.json` / `Cargo.toml` / `pyproject.toml` scripts and pick conventional names like `build`, `lint`, `test`, `spec`.
   3. If still ambiguous, ask the user once and save the answer to memory keyed by repo.
6. Find where past decisions are recorded, if they are recorded anywhere. In-repo, that is a `./plans/` directory left by earlier `/pln` runs and a conventional architecture-decision directory (`docs/adr/`, `doc/adr/`, `adr/`, `decisions/`) — found by looking, with no configuration. A record kept outside the repository is named by `plan_corpus`:

   ```bash
   {{SKILL_DIR}}/bin/pln-config get plan_corpus
   ```

   The value is a path or a list of paths; `{{SKILL_DIR}}/bin/pln-config set plan_corpus <path>` sets it, and absent means in-repo only. The user can also name a location in the session, the way the plan review switch takes a spoken instruction, and that names it for this run without writing to config.

   Note the locations in Pre-flight findings when there are any. This step finds where the record is; it does not read it. What the record says is checked one interview question at a time in Step 3, so nothing is summarized here. When there is no `./plans/`, no decision directory and no key, there is no record, Step 3's check does not run, and nothing is said about it.

### Step 2. Write the initial plan skeleton

Create `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` (relative to the session CWD, not necessarily the git root). Slug derived from the task: short, hyphenated, lowercase. Use today's date.

This is a skeleton: items are one-line summaries on the dashboard, detail sections are stubs. Open per-item questions go into the dashboard's **Open questions** section so they're visible from the top. The interview phase (Step 3) is what fills in the detail sections.

Plan layout — top-of-file dashboard followed by per-item detail sections:

```markdown
# <Task title> — <YYYY-MM-DD>

## Status

1. <one-line summary> — ⬜ pending
2. <one-line summary> — 🟦 in progress
3. <one-line summary> — ⏸ deferred → ./item-3-<slug>.md
4. <one-line summary> — ✅ done (commit <hash>)
5. <one-line summary> — 🚫 dropped

Status legend: ⬜ pending · 🟦 in progress · ✅ done · ⏸ deferred · 🚫 dropped

## Pre-flight findings

- Mandated rules: <e.g., "required skill invoked per CLAUDE.md">
- Persistent TODOs to surface: <e.g., "tenant-scoping reminder">
- Verification commands: `pnpm build:spec`, `pnpm lint`, `pnpm uspec`, `pnpm fspec`

## Open questions

- (none yet)

## Plan review

- (not yet run)

## Ship

- (not yet decided)

## Reversals

- (none)

## Verification

- (not yet run)

## Spinoffs

- (none yet)

## Cross-item notes

- (none yet)

---

## Item details

### 1. <item title>

**Status:** pending

(Brief — fuller detail emerges during the per-item loop.)

### 2. <item title>

**Status:** pending

…
```

**One row shape, for all five states**: the number first, as the ordered list's own marker, then the summary, then the status at the end of the line. The number is the address every later step uses — the Step 4 gate's reply-by-number, a subagent's brief, a cross-item note — so it is a Markdown list number a client can reference rather than text nested inside a bullet.

Rows are never removed and numbers are never reused. An item that is dropped or deferred keeps its row and its number, with its status trailing; deleting it would shift every number after it and stale every reference already written down or already spoken.

Items in the dashboard are one-line summaries. Detail sections are stub-brief at this point; they fill in during the interview and the per-item loop with Decisions, Commit, Open questions, Discoveries, Dead ends, Artifacts as the work unfolds.

After writing the skeleton, **stop**. Show the user the dashboard (not the whole file) and prompt: "Plan written to `<path>`. Ready to start the interview?" If the user answers in the affirmative, begin the interview phase (Step 3). In delegated mode there is nothing to ask: show the dashboard and go straight into Step 3 (see Delegated mode).

### Step 3. Interview phase

This is a **questions-only** phase for the plan's own scope. What's banned is *implementing the feature this interview is defining* — anything that would need the full item workflow (edit, verify, commit, and eventually a PR) — no matter how it's carried out: not in this repo, not in any other repo, sibling, or dependency; not inline, and not by spawning a sub-agent, background task, or workflow to do it. That work is a plan item, and plan items execute in Step 5, never here.

Two things are not that, and are fine to do mid-interview, immediately, without asking:

- **Read-only research, including via a sub-agent.** Dispatching a sub-agent to go read how something actually works — another repo's code, a framework's real behavior, a dependency's source — and report back is exactly the "read enough to propose a concrete approach" this step already asks for, just done in a sub-agent's fresh context instead of filling this one with pages of exploration. It changes nothing and produces no artifact of its own; it only informs the interview.

  **A background one's notification never lands mid-question.** Dispatched non-blocking so a later item's research doesn't stall the current one, its result can complete while an earlier ask-lane question is still open and unanswered. When that happens, do not surface it as a chat turn — write the finding straight into that item's section of `PLAN.md` and say nothing until the interview reaches that item. Traced from a live session: a background sub-agent researching item 5 finished while item 1's a)/b)/c) question sat unanswered, its multi-paragraph result posted as the next turn, and the reply that followed spent one throwaway line pointing back at the still-open question instead of restating it — leaving the user looking at a wall of unrelated findings with the actual question scrolled out of view. The question the user hasn't answered yet is the only thing that belongs in front of them; a finding for a later item is not urgent enough to interrupt it.
- **Incidental capture, done right now.** A small side-note that isn't the item under discussion and isn't part of this plan's own work — write up a bug you noticed, a feature request, a stray discovery — into wherever it belongs (a file in another repo's root, a tracker) so it isn't lost. This isn't implementation: nothing about it needs a test, a review, or a PR of its own, and it doesn't touch the thing the plan item will build. Do it immediately when asked, in this repo or another one, and mention in the plan that it was done so the record isn't silent.

The line between the two lanes is not "is this a write" or "is this delegated" — it's whether what's being asked for is the item's actual feature work. A note that says "this other repo can't do X, someone should add it" is capture. Adding X to that repo is implementation, however small it looks, and it waits for Step 5 even if asked for explicitly and delegated to a non-blocking sub-agent — the ban is on doing the feature work now, not on background execution as a mechanism. When unsure which lane a request is in: would it need its own tests-and-PR treatment? If yes, it's a plan item; capture it, don't start it.

A discovery *during the interview* that warrants separate work — a fix in another repo, an upstream framework change, anything outside the current task's scope — is **captured, not executed** the same way: record it in `PLAN.md` (Open questions, an out-of-scope-follow-ups note, or a spinoff stub) and keep interviewing, unless it's the incidental-capture kind above, which gets written immediately instead of waiting.

None of this exits the interview — not a request to implement the item's own feature work, however phrased ("fix it," "go do X now," "send a sub-agent to do it"), and not a plan decision that merely names something executable ("open a PR for X"). Litmus test for the latter: if the sentence would read naturally as a line inside an item's Decision write-up in `PLAN.md`, capture it silently and keep interviewing — don't ask. Every accepted plan item eventually becomes an executable action; naming one is the interview's whole point, not a signal to leave it.

The only thing that ends the interview early is the user abandoning the plan itself ("stop the plan," "forget the interview, just do it") — and recognizing that language is not itself authorization to act on it. Confirm first: "Really exit `/pln` mode?" Only an explicit yes leaves Step 3; anything else, including silence, means stay. This runs even when the signal reads as unambiguous — unambiguous phrasing is what makes the question worth asking, not a reason to skip it.

**Exploration before prose.** For each item, complete all code reading and exploration before writing any user-facing message. While exploring, emit no prose between tool calls — findings, surprises, and conclusions all belong in the final message after all exploration is done. The user should see one coherent response per item, never a running commentary with tool calls in between.

Walk every item, in order, gathering what the implementer needs to do the work without doing something the user would veto: intent, constraints, and the decisions only the user can make. Not a prescription of reversible mechanics. For each item:

1. Read enough surrounding code to propose a concrete approach (file paths, model/serializer changes, controller surface, front-end consumers, spec updates). Reading is fine; editing is not.
2. Propose a concrete approach, and run every open choice in it through the filter (see "What reaches the user"). Surface only ask-lane choices — unbacked and consequential — as a) / b) / c) options. Make the cite-backed and reversible calls yourself and record them as disclosed decisions. Leave the not-yet-knowable ones to surface in implementation. Don't manufacture an interview question for a choice an implementer should own.

   Put the message in one of the shapes under Message shape. The sentence naming the decision says what happens now and what should happen instead: "In the Past Stays tab, clicking a booking does nothing; in the Upcoming tab it opens that booking's detail panel. We want that panel to open from Past Stays too." Not a label ("the Past-Stays tab wiring"), and not the code-level approach ("wire the `onOpen` prop"). Where the approach itself needs stating, it goes where the evidence goes, in no more than six short bullets.
3. If notifications are on, fire them first (see Notifications): {{NOTIFY_CALL}}, each naming the item and the gist of the question (e.g. "pln: item 4 — which auth provider?"). Then ask **one** ask-lane question at a time. Wait for the answer. Echo the recorded answer in one short line. Move to the next question.
4. Update the item's detail section in `PLAN.md` after each answered question, so the file becomes the durable record and nothing is lost if context compacts.
5. When the item's ask-lane questions are answered, write the item's detail section: intent, constraints, acceptance criteria, the decisions other work depends on, and the disclosed decisions (each tagged with its authority or reversibility, and flagged if low-confidence). Don't write a step-by-step of reversible mechanics; see "One filter, two surfaces."
6. Move to the next item. Repeat until every item has a written final-form detail section, or is marked ⏸ deferred / 🚫 dropped.

**Before asking, check the record.** Where a project has planned this way for a while, its own plans are the decision record, and a question about something they already settle spends the user's attention on a matter that has an answer. So when Step 1 found a record, check it before each ask-lane question goes out, against that one question rather than against the item or the plan.

Do the check in a read-only research subagent (see Spawning a fresh-context agent), never in this context. Its brief is the question, the record's locations, and the instruction to answer only whether the record settles that question and where — the `file:line` and the decision's own words. That is all that comes back; reading a corpus of past plans into the interview's context is what a fresh-context agent exists to prevent.

A question the record answers is not asked. It becomes a disclosed decision naming where it was settled, and it reaches the user at the Step 4 gate as overridable like any other, because a prior plan's decision is a citable authority (see "What reaches the user"). A question the record does not answer is asked exactly as it would have been.

**What the check is not.** It is not a test of whether this plan may contradict what was decided before. A `/pln` session exists to change existing behavior, and overturning an earlier decision is routinely the point of the work. So the check never adds a question, never vetoes anything, and never fires on a choice nobody is asking about — its whole job is removing a question, and it either removes one or it changes nothing.

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

Both user forms carry the same weight. The reviewer never applies a finding over either (see "What a finding becomes"), and every rule that protects a decision because the user made it protects both, unchanged. What differs is how the decision is cited: a later turn leaning on a selected decision says the agent wrote the wording, and never quotes the option line back as the user's own words. Their words are the part after the selector, and only that part. An interview asks enough questions that agreeing to a proposal is not the same as having written it, and a reader who is told otherwise defends a sentence they never composed.

**Four checks as an item's section is written.** A review finds two kinds of thing: judgment calls, which need a reader, and mechanical slips made while writing, which don't. These four are the slips. Run them as the section is written and again whenever it is revised — at the gate, or after a finding is applied — and none of them is ever recited to the user; they govern your own writing.

- **A decision that changes an item's premise means re-reading that item whole and reconciling it.** Appending the new decision under what is already there leaves every sentence written for the old premise standing beside it, reading as current, and an implementer has no way to tell which half to build. Reconciling means editing or deleting those sentences, not adding a correction below them.
- **Acceptance criteria are re-derived from the item's prose whenever it gains or changes a decision** — never edited in place beside the old ones. Writing them last isn't enough, because an item is never finished: it picks up decisions at the gate and from review rounds, and criteria patched next to their predecessors end up contradicting each other while the prose carries the user's actual answer. This is the check above applied to the criteria in particular.
- **Open every `file:line` as you write it into the plan.** What a finding becomes already requires this of a reviewer's citation before anything is applied; the same discipline one step earlier, on your own. An unopened citation sends an implementer to a line that says something else, and it reads exactly like a checked one.
- **A claim about the shape of the work is a factual claim — check it before it goes in.** "One-line change", "no test changes needed", "already covered by X", "the same in every build" all say something about the repository that is either true or not, and none of them is checked by being written confidently. In a project whose sources build into more than one output, that last shape is the recurring one, and it fails in both directions: asserting a seam that isn't there costs as much as missing one that is.

Cross-item interactions are normal during the interview. If answering item N's question forces a change to item M's detail (already written), update M in place and tell the user one short line: "Item M revised to match: <one-line summary>." Where the interaction is a fact both items turn on — a precedence order, a substitution several items make — write it once in the dashboard's Cross-item notes as well, rather than describing it separately in each. Each item still says what it does; the shared fact has one home.

When the interview is done, every item's section pins down the intent and the decisions other work depends on, enough that the implementer can't take it somewhere the user would veto. Reversible mechanics are deliberately left open: "decide this in contact with the code" is a valid, intended end state for a deferred choice, not a gap to be filled. What must be complete is the set of ask-lane answers, not a prescription of how every line gets written.

### Step 3.5. Plan review

Every item's detail section is now written, and nobody has read the plan who wasn't in the conversation that produced it. That reading happens here, before the user is asked to adopt anything, so what reaches the gate is a plan that has already been argued with. When the switch is off, skip the whole step and say nothing about it — see The plan review switch.

None of the review is restated here. What the reviewer is told is The reviewer's brief; who reads the plan is Consulting a peer model; what happens to each finding is What a finding becomes. This step is the order they run in:

1. **Make a scratch directory**, outside the repository so nothing it holds can be swept into a commit:

   ```bash
   RUN="${TMPDIR:-/tmp}/pln-<plan-slug>"; mkdir -p "$RUN"; echo "$RUN"
   ```

   Substitute that printed path everywhere below — every shell call starts a fresh shell, so the variable itself is gone by the next one.

2. **Say one line before any of it runs**, naming who is about to read the plan — `"$PLN_BIN/pln-peer" --which` answers that with no brief written and nothing sent. This step sits between the user's last answer and the gate and can take minutes; unexplained silence there reads as a hung session. `STATUS=ready` names a peer; only rung 3's `none` means there is nobody to send to.

3. **Write the brief** to `$RUN/plan-review.brief.md`, the plan inlined whole, per The reviewer's brief. One file, whichever rung ends up running it.

4. **Run the peer**, and read what it prints per Consulting a peer model — including the one-time consent question, which is reached here on a machine that has never been asked:

   ```bash
   "$PLN_BIN/pln-peer" \
     --brief "$RUN/plan-review.brief.md" \
     --out   "$RUN/plan-review.peer.out"
   ```

5. **Review the plan on a fresh same-model agent as well**, on that same brief file, whether or not a peer ran — and where one did, at the same time as it rather than after (see the host note below). The two readers fail differently, which is the whole reason for both: the same-model agent shares this model's priors, so it is strong on whether the plan contradicts itself and whether its claims about the code are true, and blind to what the model family assumes; a peer carries neither those priors nor this codebase's idiom. `/pln-pr`'s cross-model pass skips at rung 3 because a different model is its whole point; this step's point is a reader who never saw the interview, and a fresh agent of the same model is exactly that. So exit 3 (no peer on the machine, or peer consult switched off), exit 4 (a peer was picked, ran, and failed), and a spoken "keep this one local" all leave this reader as the whole review, and none of them is a degraded run.

6. **Hand both readers' results to one merge agent** — a fresh-context agent (see Spawning a fresh-context agent) that merges the findings and files them, so that reading every finding and deciding what survives never runs in this context. `/pln-pr`'s Step 3.1 delegates the same work for the same reason; this is that mechanism here. Its brief carries four things:

   - **The rules it files by**, which it reads whole from What a finding becomes in `{{SKILL_DIR}}/SKILL.md`: the quote opened and confirmed before anything is applied, the applied-versus-flagged test, and a finding landing on a decision the user made never applied whichever reader raised it. It is a fresh agent, so it has none of this skill loaded — the path is how it gets them.
   - **Both readers' findings**, and which reader each came from: the peer's answer by path (`$RUN/plan-review.peer.out`), the same-model agent's inline, since those exist nowhere but this context.
   - **The plan's path**, and — on a bounded round (Step 4, Re-review after a rewrite) — which items are in scope, and that its findings *replace* those items' earlier findings rather than merging with them.
   - **Which readers actually ran.** A reviewer that errored or came back empty contributes nothing (see below), and a fresh agent handed a short list has no way to tell that from a reader that found little. Say so in the brief, and say if applying is switched off for this run — then every finding is flagged and `PLAN.md` is not written at all (see The plan review switch).

   It files each surviving finding in its item's detail section, adds the round's line to the dashboard's Plan review section — which items were read, by whom, what came back — and returns counts and the items they fell under, not the findings themselves. Those stay in `PLAN.md`, which is what survives a compaction between here and the gate, and where Step 4 reads them back from to build its numbered list. Then go to Step 4.

**Spawning the same-model reviewer on this host, and running it alongside the peer:**

<!-- pln:include plan-review-invoke -->

A reviewer that errored, timed out, or came back empty is a review that did not happen — not a review that found nothing. Take no findings from it, and say which of the two it was where the gate names who read the plan. With two readers that applies to each: one failing leaves the other's reading as the review, and the gate names what actually ran. Both failing is the no-review case, unchanged.

The review runs once, on the finished plan. Re-showing it at the gate is not by itself a reason to read it again: a second pass over a document the user is in the middle of editing spends minutes producing findings about sentences that are still moving. What does earn another pass is a rewrite the user asked for at the gate, on the terms set out under Re-review after a rewrite in Step 4. A correction you applied yourself in response to a finding never does.

**What the plan is checked against** is the tree as it stands before any item runs, and this step finishes before Step 5 starts. A review that overlaps implementation reads a repository the plan no longer describes: an item's own applied fix comes back as the pre-existing state, the plan is reported as wrong about the world, and the items still unbuilt yield nothing, so the half of the review that is still valid is the half that found nothing. Reviewing what implementation produced is a diff review and belongs to `/pln-pr`.

### Step 4. Master-plan approval gate

**Resolve mandated questions first.** Before anything else in this step, check the dashboard's Pre-flight findings for a mandated rule (Step 1: a required decision named by the project's own `CLAUDE.md`/`AGENTS.md`) that the interview never actually resolved — not every mandated rule needs a decision, but one that does isn't allowed to ride into the gate unanswered. If one is still open, ask and resolve it now, in its own message, one question at a time exactly as in Step 3. Record the answer in the dashboard before moving on. Only once every mandated question is resolved does the gate itself get shown, and it gets shown in a message of its own — never folded into the same message as a mandated question, and never bundled with the three-way adopt choice below.

Show the user the master plan in one message, with enough in it to adopt on without opening the file:

- Print the dashboard (status list) — the same bullet list of items the Step 2 skeleton showed, updated. This is the user's overview and their editing surface, and it is cheap: in a measured 9,195-character gate it was under a tenth of the message. It stays.
- **Do not print a digest of the items.** Every item's intent was settled with the user, question by question, in the interview they just finished; restating it back is the largest avoidable block in the message and it is the half they already know. The detail lives in `PLAN.md` for the implementer and the reviewer.
- Print **one numbered list, and only of what the user has not already seen**: the decide-and-disclose calls that clear all three tests in "What reaches the user" and were not already stated in the flow, and — when Step 3.5 ran — the findings the review flagged rather than applied. Those are the calls made without them.

  **Two filters run before anything gets a number, and both cut hard.** A call that fails any of the three tests is not listed — it is the work, and it lives in its item's section. A call that passed them and was therefore already said in the flow is not listed either: the user saw it at the moment it was made, one word would have stopped it, and no word came. Those are covered by a single clause with the count — "the four calls I stated as I made them still stand; name any you want reopened" — not by six numbered entries the user is reading for the second time. What is left with a number is the calls that mattered and that they are seeing for the first time, which is usually a short list. One number space across both kinds (so the user can reply "3, 7, 8" without saying which kind each is), each entry named by its item's title as well as its number per Naming things the user reads. Each entry is one line that opens with its kind:
  - ***decision*** — what was decided, with its cited rationale.
  - ***flagged*** — the finding in one sentence, what the reviewer would change, and which kind it is: a false factual claim, a contradiction inside the plan, or a judgment call.

  When both readers ran, each ***flagged*** entry names the reader that raised it; a defect both raised is one numbered entry naming both.

  **Corrections the review applied are never listed.** A finding the reviewer raised and you applied is you fixing your own drafting inside a document the user does not read — it was never theirs to write and is not theirs to ratify. It is recorded in its item's section, where the reviewer and the implementer see it, and it reaches this message only in the one case where it changed what gets built, in which case it is a *decision* with the rest. In the gate this rule was drawn from, sixteen of thirty-six numbered entries were applied corrections: 44% of the list, none of it actionable.

  A finding that lands on the plan as a whole rather than on any one item — a missing item, an ordering that won't work — is numbered in the same sequence, in a final group of its own after the per-item ones. It is in the dashboard's Open questions, not in an item's section, but it is one of the things the user can act on, so it gets a number like everything else.
- When Step 3.5 ran, say in one clause who read the plan: the peer CLI by name and a fresh agent of the same model when both ran, or whichever one did — and when no peer read it, why (no second CLI on this machine, peer consult switched off, you were asked to keep this plan local for this run, or the peer ran and failed). The user weighs a flagged finding differently depending on whose eyes were on the plan. A review that found nothing gets the same one clause and no more; saying nothing reads as if the step never ran.
- Self-triage the list; don't present forty entries as equals. Lead with the handful you're least sure about and flag them for the user's eye ("worth a look: 3, 7, 12"). One triage line covers the whole list rather than one per kind — the single number space exists so there is one thing to scan and one way to reply. What earns a place on it differs by kind: a decision closest to the ask/decide line, or whose authority is weakest or whose reversibility you're least certain of; a flagged finding that would change what gets built. The rest stand as a scannable list the user can skim or ignore. The risk to avoid is a miscalibrated "all safe here" that buries an entry the user would have changed; when genuinely unsure, flag rather than bury. Then offer to walk the flagged entries one at a time (see Walking the flagged entries below), so the user answers them where they are told about them instead of scrolling back up a forty-entry list to reply by number. The offer rides here, with the triage line — never after the prompt below, which stays the message's last line.
- End with a three-way prompt, one option per line:

  ```
  Adopt this master plan?
  a) implement it and open a PR when done
  b) implement only
  c) reopen anything by number / change something?
  ```

**When no review ran** — `plan_review` is off, the user skipped it, or the plan was written before the step existed — none of the review's part of this appears: no rung clause, no empty findings list, and no note explaining what didn't happen. The numbered list is the disclosed decisions and nothing else, exactly the gate it was before the step existed.

This is the only place implementation-blocking approval lives. Possible responses:

- *Adopt* — either of the two shapes below. Either way, every numbered entry not reopened stands as accepted: decisions hold and flagged findings were seen and left alone. Proceed to Step 5.
  - **a) Implement and open a PR when done.** Record `Ship: PR after implementation` in the dashboard's Ship field, plus `PR base: <branch>` when item 4's stacking override applies. This answers Step 8's ask up front: Step 7's wrap-up hands straight to `/pln-pr` with no further prompt.
  - **b) Implement only.** Record `Ship: implement only` in the dashboard's Ship field. Step 8 still asks once, at the end of Step 7's wrap-up, exactly as it did before this choice existed.
- *Reopen by number* (e.g. "3, 7, 8") — any entry, of either kind. A **decision** returns to the one-question-at-a-time interview, exactly like Step 3, but starting from the recorded position and its rationale, not a blank question ("I chose X because Y; here's the tradeoff; what would you change?"). A **flagged** finding becomes an interview question of the same shape: what the reviewer found, what it would change, what the user wants done. Resolve each, update `PLAN.md`, re-show, re-prompt. Unlisted entries remain accepted.

  An applied correction is not on the list, so it cannot be reopened by number — but the user can still name one they disagree with in prose, and it is then shown with what it replaced and reverted if they say so. The record in the item's detail section is what makes that one edit instead of a reconstruction, and the revert is re-read to confirm it landed, per Confirm the write landed.
- *Change X* — make the change in `PLAN.md`, re-show the affected section(s), re-prompt the same three-way question. Loop until the user adopts.

A rewrite made through either response is an item's section being written again, so it goes through Step 3's four checks — the first of them most of all. A reopened decision has changed that item's premise, and the parts written under the old one are reconciled rather than left standing beside the new answer.

**Walking the flagged entries.** Accepting the offer walks the triaged entries in Step 3's format: one question per turn, `AskUserQuestion` never used, each entry restated in full when its turn comes — its number and title, what it is, and what each answer changes — because by then the list is several screens up and the point of the walk is that nothing has to be found again. It is the *Reopen by number* path with the hunting removed, and it ends the same way: update `PLAN.md`, re-show, re-prompt. Declining leaves the gate as it is — reply by number, or adopt. The offer is not a fourth answer to the adopt prompt: adopting still adopts the whole plan, triaged entries included.

A walked entry the user changes is a rewrite like any other and starts a bounded round below; one they look at and leave alone is not, and starts nothing. When a round produces its own triage line, that line carries the same offer — the user declines it as easily as they accept it, and suppressing it would hide findings that reached the line by the same triage.

**Re-review after a rewrite.** Both responses above are the user changing the plan, and a change the user made is the only thing that starts another round. An edit made through either counts as a rewrite of an item, for this purpose, when it changes that item's premise, intent, acceptance criteria, or a decision another item depends on. An edit that only tightens wording, fixes a typo, or is otherwise trivially correct does not. Neither does a correction you made yourself to apply a review finding: an applied correction is finished once it is applied and recorded in its item's section, and reading your own response to a reviewer is the loop that has no end. So an item a correction touched and the user did not is not a changed item here.

When one or more items are rewritten, re-run Step 3.5 bounded to just those items before re-showing the gate — not the whole plan again. Give the re-review each rewritten item's section plus the sections of any items whose own text names it as a dependency, so a cross-item contradiction the rewrite introduced is still catchable. The new pass's findings replace the rewritten item's prior findings entirely; findings on every other, untouched item stand as they were. Say in one line which items were re-reviewed before re-prompting, and record the round in the dashboard's Plan review section.

**When the rounds stop.** Coverage decides this, not cost. They stop when every item the user changed has been read since they changed it and that latest reading found no false factual claim and no contradiction inside the plan. A judgment call earns no further round; it goes to the gate flagged like any other finding. There is no round cap and none is needed — only the user's own edits start a round, so the rounds end when the user stops editing. A cap would end them somewhere else instead, leaving whatever the last rewrite introduced unread.

Do not enter Step 5 without an explicit adoption signal. Delegated mode is the one exception, and only because the signal was already given: the instruction that entered it adopts the plan in advance for the whole run, and what that mode prints before Step 5 is its short list of reversals, one-way doors, flagged findings and unanswerable questions — not a gate.

### Step 5. Implementation phase

<!-- pln:include step5-orchestration -->

**The subagent brief.** The prompt handed to each subagent must make `PLAN.md` its entire spec and carry every per-item concern, because the orchestrator is no longer doing this work:

1. Read `PLAN.md` in full at `<path>`. The top dashboard (pre-flight findings, mandated skills, verification commands, cross-item notes) and item N's detail section are your spec.
2. Follow any mandated skills noted in the pre-flight findings; you are a fresh context, so re-establish that yourself.
3. Execute item N to its acceptance criteria. The plan records intent and the decisions other work depends on, not reversible mechanics — own those yourself, to the project's quality bar. If the item calls for a new test, hold it to this bar:
   - Test the path the code actually runs, not just its inputs — assert on what crosses a mocked boundary rather than only on the boundary itself. If the boundary (e.g. an external gateway) stays mocked, say so in the report.
   - Before fixing anything, run the new test and paste the actual failure message. Not "it failed."
   - After fixing, report the exact command run and the count it printed (e.g. `pnpm uspec spec/unit/foo → 4 tests, 4 passed`) — not a raw paste of passing output, which is noise. Someone can re-run that exact command to check it.
   - If a test's result could change depending on the time of day or date, say so and account for it.
   - Before reporting verification, re-read the project's completion rule (`CLAUDE.md`/`AGENTS.md`) and reproduce any environmental condition it names — cleared credentials, a specific timezone, a service, a clean database — that this run didn't already match.
<!-- pln:only claude -->
4. Run lightweight verification (type-check + lint, no specs). This gate is about the mandatory pre-commit check, not about whether new tests get written and run at all — a test called for by item 3's bar above still gets written and run, per those bullets. If lightweight verification fails: fix, re-stage. Commit only a complete, verified item, with the co-author trailer; never `--amend`, never `--no-verify`. A decision-only or doc-only item needs no commit; the plan file is the record.
<!-- pln:endonly -->
<!-- pln:only codex -->
4. Run lightweight verification (type-check + lint, no specs). This gate is about the mandatory pre-commit check, not about whether new tests get written and run at all — a test called for by item 3's bar above still gets written and run, per those bullets. If lightweight verification fails: fix it. Do not commit — committing is the orchestrator's job, which is what keeps every per-item commit a clean checkpoint; leave the finished work in the tree and say in your final message what should be committed. A decision-only or doc-only item leaves nothing to commit; the plan file is the record.
<!-- pln:endonly -->
<!-- pln:only claude -->
5. Before returning, update item N's section in `PLAN.md`: status ✅ done, commit hash, dead ends hit, artifacts produced, any discoveries. If this item discovered something a later item needs — a constant to reuse, a field that changed, a trap not to repeat — add one line to the dashboard's Cross-item notes too; skip it if there's nothing later items would need.
<!-- pln:endonly -->
<!-- pln:only codex -->
5. Before returning, update item N's section in `PLAN.md`: status ✅ done, dead ends hit, artifacts produced, any discoveries. Leave the commit hash out — the orchestrator commits and fills it in. If this item discovered something a later item needs — a constant to reuse, a field that changed, a trap not to repeat — add one line to the dashboard's Cross-item notes too; skip it if there's nothing later items would need. Then keep the final message itself to a few lines: what changed, which files should be committed, and anything the next item needs. That message is the only thing that reaches the orchestrator; everything else you have to say belongs in `PLAN.md`.
<!-- pln:endonly -->
6. Capture memories the moment they surface, per the standard memory rules. (Include the Dream/Psychic learning-capture instruction here only when pre-flight detected both `RECORD_PSYCHIC_LEARNINGS` and Dream/Psychic context.)
<!-- pln:only claude -->
7. If you hit a blocker threshold (see Cross-cutting concerns), stop and follow the handoff protocol instead of improvising.
<!-- pln:endonly -->
<!-- pln:only codex -->
7. If you hit a blocker threshold (see Cross-cutting concerns), stop instead of improvising. Leave your changes in the tree exactly as they are: don't revert them, and don't stash or commit them — touching `.git` is the orchestrator's job, not yours. Write the handoff file to the plan dir and return a message beginning `BLOCKED:` with the question and the filename. Stopping is cheap, because you can be resumed with your context intact once the user answers; work you have already done is not thrown away.
<!-- pln:endonly -->

If a recorded step turns out wrong (e.g., a generator command doesn't exist) and the fix is reversible and within scope, the subagent corrects it inline and notes it in the item's Discoveries. If the correction crosses a blocker threshold, it stops and hands off.

The orchestrator breaks silence to the user only when a subagent returns `BLOCKED:` (interactive default), or when the user interrupts. If the user asks a new design question mid-implementation, treat it as a blocker: pause, decide, update the plan, then resume by spawning the next subagent. Don't quietly improvise.

### Step 6. Deferred-item revisit

After the last item completes, before final verification: walk back through any items marked ⏸ deferred (and any deferred sub-questions). For each, ask the user: "Revisit now, push to a future session, or drop?"

Items marked ⏸ blocked (auto mode) are different: each already has a concrete blocking question recorded in its handoff file. Ask that question directly, same one-question-at-a-time format as a live blocker, record the answer, and resume the run per the auto-mode blocker protocol above — don't fold it into the "revisit / push / drop" prompt used for deferred items.

### Step 7. End-of-task verification + wrap-up

1. Spawn one fresh-context agent (see Spawning a fresh-context agent) to run the full gauntlet once and return pass/fail per command. Running it in an agent keeps the large stdout/stderr out of the orchestrator's context; that output stays with the agent and is not persisted to a file. The orchestrator writes the pass/fail summary to the dashboard's Verification section.
2. If anything fails: it's now a new item. Don't paper over. Either spawn an agent to fix-and-rerun, or spawn a spinoff if the failure is out-of-scope.
3. If notifications are on, fire them first (see Notifications): {{NOTIFY_CALL}}, summarizing the outcome (e.g. "pln: plan done, 8/8 items, gauntlet passed").
4. Sweep the run's own record for outstanding work (see Follow-ups) before drafting anything. A run that never looks reports whatever it happens to remember.
5. Final message to the user: one or two sentences saying what changed and what's next, in plain words. This message is the complete answer on its own — no pointer to `PLAN.md` for the rest (see Style's "Ending a message"). If genuine follow-ups remain, list them per the follow-up bar below.
6. If that message listed any follow-ups, run the to-do-location flow below. Anything it asks or offers is a message of its own — never folded into Step 8's ask.

### Step 8. Ship — hand off to `/pln-pr`

A finished plan is not a shipped one, and shipping is `/pln-pr`'s job: it reviews the branch with fresh-context reviewers, fixes what they find, verifies once, and opens the pull request. Pushing and running `gh pr create` from here instead skips all of it.

Read the dashboard's `Ship` field — not what the conversation remembers, so a restarted or resumed session doesn't have to recall a choice made turns ago:

- **`PR after implementation`** — the Step 4 gate already asked and got a yes. Hand off immediately at the end of Step 7's wrap-up, no further prompt.
- **`implement only`, absent, or the plan predates this field** — ask once, at the end of the Step 7 wrap-up message rather than in a message of its own: open the PR now, or stop here? Skip the ask entirely when there is nothing to put up — no commits ahead of the base branch — or when the user has already said where this run ends. On yes, hand off the same way.

Handing off:

<!-- pln:only claude -->
Invoke `/pln-pr` with the `Skill` tool. Its steps then arrive verbatim at the moment they are used, instead of being recalled from a description read an hour of implementation ago — which is why it is a separate skill rather than a section of this file.

When the dashboard's `Ship` field carries a `PR base: <branch>` line (item 4's stacking override), pass that branch through in the `args` string rather than making a human type it at PR time: `Skill({skill: "pln-pr", args: "base=<branch>"})`.
<!-- pln:endonly -->
<!-- pln:only codex -->
This host has no tool that invokes a skill, so load it yourself: read `{{SKILL_DIR}}/pln-pr/SKILL.md` in full and follow it. Its steps then arrive verbatim at the moment they are used, instead of being recalled from a description read an hour of implementation ago — which is why it is a separate skill rather than a section of this file.

When the dashboard's `Ship` field carries a `PR base: <branch>` line (item 4's stacking override), there is no separate tool call to attach that argument to — carry it forward explicitly instead: when you reach `pln-pr/SKILL.md`'s Step 0, tell yourself the base is already decided (the stacked branch, not the auto-detected default) and follow that step's own validation before using it, rather than running its auto-detection.
<!-- pln:endonly -->

This holds for a PR ask anywhere in the session, not only at the end. "Put up a PR", "ship it", and PR asks carried inside a longer instruction — "bump the version and open the PR", "push this up" — all route through `/pln-pr`. The one exception is an explicit "skip the review", which you honor.

## Cross-cutting concerns

These apply throughout the per-item loop; they are not sequential steps.

### Mid-item discovery — the blocker protocol

A subagent can't ask the user anything; it runs in isolation and returns one final message. So the four discovery thresholds become a stop-and-hand-off protocol rather than a pause-and-ask.

A subagent stops and hands off when any of:

- The discovery requires a change **outside** the item's stated scope (different file, different layer, different system).
- The discovery means the original plan **won't work as written** and a real choice has to be made.
- The discovery has **irreversible consequences** (data migration, schema change, anything that touches shared infra).
- The discovery reveals an assumption was wrong that **other items also depend on**.

Recommending a spinoff (see Spinoffs) is one kind of hand-off. Otherwise, the subagent fixes inline — silently, or with a one-line note in the item's Discoveries. No hand-off.

**The hand-off, on hitting a threshold.** The subagent does not roll back. It leaves its changes uncommitted in the working tree and writes a handoff file to the plan dir, `<timestamp>-item-<N>-<slug>.md`, containing what it did, which files it touched, the dead ends, and the self-contained blocking question (same self-containment discipline as interview questions — answerable without the subagent's context). It returns a message beginning `BLOCKED:` with the question and the handoff filename.

**The orchestrator's response:**

<!-- pln:only claude -->
- **Interactive (default):** a running Workflow script has no channel back to the user mid-run — it can't pause in place and wait for a typed answer, only stop. So on a `BLOCKED:` result the script returns immediately with the item number and the question, rather than trying to spawn a follow-up call itself. If notifications are on, the orchestrator fires them first (see Notifications), naming the item and the one-line blocking question; it then surfaces the question to the user as a one-question-at-a-time decision, same filter and format as Step 3, and records the answer in `PLAN.md`. It then resumes the same run: `Workflow({scriptPath, resumeFromRunId, args: {...item N's answer, handoff filename...}})`. Every item's `agent()` call before the blocked one is unchanged and replays from cache instantly; the blocked item's call now includes the answer and handoff filename in its prompt, so it doesn't hit the cache — it reruns live, reads item N's section, the handoff file, and the uncommitted diff (`git status` / `git diff`), resumes from where the first attempt stopped, finishes, commits, updates `PLAN.md`, and deletes the handoff file. Items after it then run for the first time in this same execution. Because the blocker resolves before the next item starts, a dirty tree is fine.
- **Auto (see below):** the script doesn't stop at all. The blocked subagent stashes its partial work under a labeled stash and records the stash ref in the handoff file, leaving a clean tree; the item is marked ⏸ blocked, and the script's own loop moves on to the next non-dependent item without returning. A blocked item that a later item depends on already trips the "assumption other items depend on" threshold, so dependent items defer rather than building on a half-done base. All blocked items surface together at the end-of-run review (Step 6); for each, the orchestrator gets the answer and resumes the same run the same way interactive mode does, letting that item's `agent()` call pop the stash, apply the answer, and finish.
<!-- pln:endonly -->
<!-- pln:only codex -->
Everything the protocol does to the repository — stashing, restoring, committing — is the orchestrator's job, not the agent's. The agent's part is to stop, write the handoff file, and return.

- **Interactive (default):** the loop stops at the blocked item. The orchestrator's first act is to append the item's agent handle to the handoff file (`Agent: <handle>`, the handle `spawn_agent` returned — on the fallback, `Thread: <THREAD_ID>`, the id the helper printed). The agent can't write it — it doesn't know its own handle — and without it a session that is restarted or compacted between the question and the answer has lost the only cheap way to finish the item. Then, if notifications are on, fire them first ({{NOTIFY_CALL}}), naming the item and the one-line blocking question; surface the question to the user as a one-question-at-a-time decision, same filter and format as Step 3; record the answer in `PLAN.md`. Then resume that item's own agent — `resume_agent` on its handle with a short brief carrying the answer (on the fallback, `--resume` with that brief; see the blocker-resume rules in Spawning a fresh-context agent). The resumed agent still holds everything the first attempt worked out, so nothing finished is redone: it reads the handoff file and the uncommitted diff (`git status` / `git diff`), finishes the item, updates `PLAN.md`, and deletes the handoff file. The orchestrator then commits the completed item and moves to the next one. Because the blocker resolves before the next item starts, a dirty tree is fine.
- **Auto (see below):** the loop doesn't stop. After recording the handle, the orchestrator stashes the partial work itself — `git stash push -u -m "pln <plan-slug> item <N>"` — and writes that same label into the handoff file, leaving a clean tree for the next item. Record the label, not `stash@{0}`: every later blocked item pushes another stash and shifts the index, so the ref is resolved back out of `git stash list` by its label at restore time. The item is marked ⏸ blocked and the orchestrator moves on to the next non-dependent item. A blocked item that a later item depends on already trips the "assumption other items depend on" threshold, so dependent items defer rather than building on a half-done base. All blocked items surface together at the end-of-run review (Step 6); for each, the orchestrator gets the answer, pops that item's stash back into the tree, and then resumes its agent exactly as interactive mode does.

If the agent can't be resumed — no handle was kept, or the resume comes back an error — the fallback is a fresh agent pointed at the handoff file and the uncommitted diff, per Spawning a fresh-context agent. That is the Claude path's behavior, so a lost agent costs the first attempt's reasoning and none of its work.
<!-- pln:endonly -->

### Auto-mode behavior

Auto mode applies only to **Step 5 (implementation phase)**. The orchestrator already runs items end-to-end without stopping between them; what auto mode adds is that it does not even stop for blockers — a `BLOCKED:` return is deferred (partial work stashed, item marked ⏸ blocked) and surfaced at the end-of-run review instead of interrupting the user.

It does NOT bypass:

- The Step 2 skeleton gate ("Continue?").
- The Step 3 interview phase: every per-item question must still be asked and answered.
- The Step 4 master-plan approval gate: explicit adoption is always required before implementation begins.
- The four blocker thresholds: a subagent still stops and hands off on any of them. Auto mode only changes whether the orchestrator surfaces the blocker now or defers it.

Delegated mode is the only thing that bypasses the first and third of those, and it does so because the user adopted the plan in advance (see Delegated mode). The two modes compose without cancelling each other: a run in both still stops for delegated mode's pre-implementation short list, and auto mode still defers a blocker to the end-of-run review rather than surfacing it live.

### Spinoffs

Spawn a spinoff plan file when an item meets any of:

- Implementation ripples beyond the current task's stated scope (front-end audit, IaC changes, coordination with another system).
- The item is more naturally tackled by a fresh agent with full context rather than continuing inline.
- The item depends on infrastructure or external work that isn't ready yet.
- The item produces a meaningfully different commit-set / PR than the rest of the task.

Spinoff file path: `./plans/<YYYY-MM-DD>-<slug>/<item-slug>.md` (sibling to `PLAN.md`).

Spinoff file structure (in order):

1. Why this exists — what triggered the spinoff, what's broken/missing today.
2. Target shape / end state — what "done" looks like.
3. Pre-flight audit step ("Step 0") — explicit "examine X before changing code" if the item touches surfaces a fresh agent might not know about (front-end consumers, IaC, etc.).
4. Implementation steps — numbered.
5. Verification — the repo-specific gauntlet for this work.
6. Reminders — cross-cutting TODOs the agent should surface (e.g., persistent-TODO reminders from `CLAUDE.md`).

A subagent does not create a spinoff itself. When it judges an item warrants one, it hands off (`BLOCKED:`) recommending the spinoff with its reasoning; the orchestrator writes the spinoff file and updates `PLAN.md`. After writing the spinoff, update the parent `PLAN.md`: mark the item ⏸ deferred and add a link in the Spinoffs section.

### Follow-ups

Applies at Step 7's wrap-up, and at the equivalent point in `/pln-pr`. The bar and the closing-message shape are Style's "Ending a message" rules — true when checked, not done, and someone will need to act on it or decide about it later; a fixed finding is not a follow-up.

<!-- pln:include outstanding-sweep -->

**Full detail lives in `PLAN.md`,** not the closing message — the bullet list there names each follow-up, `PLAN.md` (or, in a standalone `/pln-pr` run with no `PLAN.md`, `REVIEW.md`) carries the rest.

<!-- pln:include todo-location -->

### Continuous learning + memory capture

This happens during item work, which now runs in subagents — so these instructions live in the subagent brief (Step 5), not in the orchestrator. The orchestrator captures memory only for things that surface in its own conversation (e.g., during the interview or at a blocker).

<!-- pln:only claude -->
- **Memory:** the moment something surfaces that fits an auto-memory category (user role, feedback, project fact, reference), write a new memory immediately to `~/.claude/projects/<project>/memory/` per the standard memory rules. Don't batch for end-of-task.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Memory:** the moment something surfaces that fits a memory category (user role, feedback, project fact, reference), record it immediately; don't batch for end-of-task. Codex keeps no memory directory of its own, so put it where the next session will actually see it: the item's Discoveries in `PLAN.md`, or the project's own notes / `AGENTS.md` when it is a durable project fact.
<!-- pln:endonly -->
- **Dream/Psychic learnings (gated):** active only when pre-flight saw both `RECORD_PSYCHIC_LEARNINGS` set and Dream/Psychic context. When active, the moment a learning surfaces that's not in `/psychic-skill`, append it to `<project-root>/WHAT_I_LEARNED_ABOUT_PSYCHIC_<YYYY-MM-DD>.md`. The filename is fixed, not parameterized by topic. Content scope is narrow: only learnings about Dream ORM and the Psychic web framework that are missing from `/psychic-skill`. The user is co-author of Dream/Psychic and uses this file to feed back to the skill maintainer. When the env var is unset, this entire concern is off and the orchestrator omits it from the subagent brief.

### Notifications

The point is to pull the user back at the moments they're actually needed — an implementation run can take an hour, and they're context-switching away from it. This is not progress reporting; it fires at exactly three moments and no others.

<!-- pln:only claude -->
Two independent channels, each a separate toggle, both default on. Set up once by the top-of-file Notification setup preamble (not Step 1 pre-flight — that is skipped on a "continue" invocation, and notification setup can't be):

- **Phone push** — the harness `PushNotification` tool, gated on `notify_push`. Loaded via `ToolSearch` in the preamble when on. Self-suppresses when the user is watching the terminal, so it reaches them only when actually away.
- **Local desktop** — `{{SKILL_DIR}}/bin/pln-notify-desktop "<message>"`, gated on `notify_desktop`. macOS (`osascript`) and Linux (`notify-send`); a no-op elsewhere. It covers the at-the-computer case the push channel's self-suppression removes. The helper self-gates, so call it unconditionally at each site — don't check `notify_desktop` yourself.

Firing both at every moment is deliberate: between the push's away-only delivery and the desktop's at-computer delivery, the user is covered in either state without pln ever trying to guess which one they're in — the presence guessing is what proved unreliable.
<!-- pln:endonly -->
<!-- pln:only codex -->
One channel on this host, toggleable, default on. Set up once by the top-of-file Notification setup preamble (not Step 1 pre-flight — that is skipped on a "continue" invocation, and notification setup can't be):

- **Local desktop** — `{{SKILL_DIR}}/bin/pln-notify-desktop "<message>"`, gated on `notify_desktop`. macOS (`osascript`) and Linux (`notify-send`); a no-op elsewhere. The helper self-gates, so call it unconditionally at each site — don't check `notify_desktop` yourself.

There is no phone-push channel here. Codex's own `notify` hook is user-configured in `~/.codex/config.toml` and fires on turn completion; a skill cannot call it for a specific moment, so it can't serve pln's three. `notify_push` is ignored on this host.
<!-- pln:endonly -->

The three moments (fire the enabled channels **before** writing the user-facing text — see Hard constraints):

1. **Interview question asked (Step 3).** Before posting each ask-lane question. Name the item and the gist, e.g. "pln: item 4 — which auth provider?" The push self-suppresses when the user is present, so this is safe to fire on every question.
2. **Blocker surfaced (Step 5).** In interactive mode, before surfacing a subagent's `BLOCKED:` handoff as a decision. In auto mode, blockers are deferred; fire once, before presenting them together at the Step 6 end-of-run review, not per-blocker. Name the item and the one-line blocking question, e.g. "pln: item 7 blocked — schema change needed, needs your call."
3. **Plan complete (Step 7).** Once, before the final wrap-up. Summarize the outcome, e.g. "pln: plan done, 8/8 items, gauntlet passed."

Message rules: under 200 characters, one line, no markdown (a long message is truncated by the push channel and reads badly in a desktop banner). Make it specific — a generic "pln needs you" wastes the notification; name the item and the question or outcome. Pass the same one-line string to every channel.

Config (all in `~/.pln/config.yaml`, via `{{SKILL_DIR}}/bin/pln-config`), each independently toggleable:

<!-- pln:only claude -->
- `notify_push` — `false` disables phone push. Default on.
<!-- pln:endonly -->
- `notify_desktop` — `false` disables the local desktop notification. Default on.
- `notify_desktop_persist` — `true` makes the desktop notification stay until dismissed rather than auto-vanishing (macOS: a dialog that waits for a click; Linux: `critical` urgency, which standard daemons don't auto-expire). Default off, because a persistent alert on every question is intrusive for the general audience; a user who tends to miss vanishing banners turns it on. `{{SKILL_DIR}}/bin/pln-config set notify_desktop_persist true`.

Toggle any of these mid-session with `pln-config set <key> false` (or `true`); it takes effect from the next `/pln` invocation's preamble.

## Plan file conventions

- Directory: `./plans/<YYYY-MM-DD>-<slug>/`. Path is relative to the session CWD (where Claude was launched), not the git root.
- Main plan file is always `PLAN.md`.
- Spinoff files use a meaningful slug, e.g., `item-7-first-date-restructure.md`.
- Handoff files (written by a subagent at a blocker) use `<timestamp>-item-<N>-<slug>.md` in the plan dir. They are transient scratch: not committed, and deleted by the resuming subagent once the item completes. The durable record (the decision, the dead ends) folds into `PLAN.md`; the handoff file only bridges one blocked subagent to its replacement.
<!-- pln:only codex -->
- The orchestrator appends two things to a handoff file when it reads a `BLOCKED:` result: the blocked agent's handle (its thread id on the fallback), and — in auto mode — the label of the stash holding the partial work. The agent can write neither; it doesn't know its own handle, and touching `.git` is the orchestrator's job. Without them, an orchestrator that is restarted or compacted before the user answers has no way to continue the agent or find the work.
<!-- pln:endonly -->
- Verification output is **not** persisted; pass/fail summary in the dashboard is enough.

## Tracker contents in `PLAN.md`

Top-of-file dashboard carries:

- **Status** — one numbered row per item: the number, the summary, then the status icon at the end of the line and (if done) the commit hash. Rows are never removed and numbers never reused, so an item's number is permanent (see Step 2).
- **Pre-flight findings** — mandated rules, persistent TODOs, verification commands discovered.
- **Open questions** — questions asked but not yet answered (deferred sub-questions live here so nothing is lost).
- **Plan review** — one line per Step 3.5 round: which items it read, who read them, and what it turned up. The round the user is looking at is the last line, and the count is however many lines there are, so a re-showing gate and a resumed session both know how far the review got without reconstructing it from the conversation.
- **Ship** — the Step 4 adopt choice: `PR after implementation` or `implement only`, plus `PR base: <branch>` when a stacking override (item 4) applies. Set once, at adoption, and read back by Step 8 rather than trusted from the conversation — a restarted or resumed session still knows what was decided.
- **Reversals** — one line per decision in this plan that overturns something already settled or already built: what it reverses, and where that was decided. `/pln-pr` reads it into the PR body, so a reversal reaches the branch's reviewer even when the user adopted the plan without reading it (see Delegated mode).
- **Verification** — pass/fail per command at task end.
- **Spinoffs** — links to any spinoff plan files.
- **Cross-item notes** — one line per fact more than one item turns on: a discovery a completed item makes that a later item needs (a constant to reuse, a field that changed, a trap not to repeat), and an interaction between items (a precedence order, a substitution several items make). An interaction is recorded here, not described inside each item — a subagent reads its own item and the dashboard, so two half-descriptions in two sections never get reconciled by anyone. Only what another item would get wrong without it, not every cross-reference: this is part of the dashboard every subagent already reads in full regardless of plan size, and it stays cheap only while it stays bounded.

Per-item detail sections carry:

- Status.
- Intent, constraints, and acceptance criteria — what "done" means, not how each line gets written.
- Decisions — each a *what* + *why*, tagged with its authority or its reversibility, and flagged if low-confidence (the flag is what puts it on the Step 4 gate's "worth a look" line). Recorded as overridable-when-reversible context, never as imperative steps. The ones the user made are marked as theirs — originated where they raised the substance, selected where they picked from options the agent wrote — and written in their words. See "How a decision is recorded" in Step 3.
- Commit hash if any.
- **Review findings** — what the plan review (Step 3.5) corrected in this section, and what it flagged for the user instead. See "What a finding becomes".
- Discoveries (mid-item findings worth recording).
- **Dead ends / don't repeat** — approaches tried that failed, and why. A re-run after a blocker, or a later item, reads these so it doesn't retry a known dead end.
- **Artifacts** — files created or changed, with locations.
- Open questions.

Each item section must be self-contained: a blank-context subagent reading only the dashboard plus that one section must have everything it needs to execute the item. This is the same self-containment discipline applied to interview questions, now applied to item sections, because a subagent is exactly that blank-context reader.

## Failure modes to watch for

- **Building out the feature under discussion before the plan is adopted** — inline, or by spawning a sub-agent/workflow to do it; delegating is not a loophole. Before any state-changing tool call during Steps 1–4, run Step 3's feature-work-vs-exceptions test. This applies even when the user asked for it directly, named the delegation mechanism themselves, or it targets a different repo. If it happens anyway and the user calls it out — in any words, not just a reference to "pln" or "the interview" — halt immediately: kill any spawned background work, disclose exactly what changed, and offer to revert, rather than acknowledging the pushback and continuing past it.
- **Resuming an in-flight interview from a hand-off note instead of reloading this file** — a session that picks up a `/pln` interview from a summary written by a prior run (a compaction, a session-boundary hand-off) still has to (re-)load `SKILL.core.md`'s interview rules, not rely solely on the note's prose recap of what went wrong last time. A postmortem-toned summary of a past mistake primes overcorrection into the opposite failure — e.g. treating an ordinary plan decision as an ambiguous request to break out of the interview. The note calibrates against repeating the same mistake; it is not a substitute for the actual rule text.
- **Asking an item-2 question while implementing item-1** — if you are inside Step 5 and about to ask a design question that wasn't in the master plan, stop. That question belonged in Step 3. Pause execution, surface it as a master-plan amendment, get the user's decision, update the plan, then resume.
- **Dropping a cross-cutting concern from the subagent brief** — memory capture, mandated-skill invocation, and (when gated on) Psychic learning-capture happen during item work, which now runs in subagents. If the brief omits them, they silently stop happening. The brief carries every per-item concern.
- **Inventing a verification gauntlet** — if you didn't read `CLAUDE.md` / `AGENTS.md` and find the actual commands, ask the user. Don't run guessed commands.
<!-- pln:only claude -->
- **`PushNotification` never loaded, so the call silently does nothing** — it is commonly a deferred tool; "call `PushNotification`" at a site does nothing unless the Notification setup preamble already ran `ToolSearch` (`select:PushNotification`). This fails with no error and nothing in the transcript. (The desktop channel has no such trap: `pln-notify-desktop` is a plain script, always callable.)
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Calling the notifier by bare name, or through a variable a fresh shell doesn't have** — `pln-notify-desktop` is not on `PATH`, and `$_PLN_DIR` is resolved once in the preamble and gone by the next shell call. Every notify site runs the full path you resolved there. A bare `pln-notify-desktop` fails with `command not found`; `"$_PLN_DIR/bin/pln-notify-desktop"` in a later shell silently runs `/bin/pln-notify-desktop`, which doesn't exist either. Neither is visible to the user, who just doesn't get notified.
<!-- pln:endonly -->
- **Assuming Step 1 pre-flight runs on every invocation** — it only runs before writing a *new* plan skeleton. A "continue the plan" invocation or a reopened decision skips Step 1 entirely. Anything that must hold on every invocation regardless of new-vs-continuing — notification setup is the example — belongs in the top-of-file preamble, not inside Step 1.
- **Trusting a remembered item cursor instead of `PLAN.md`'s status** — when building or resuming a run, the pending-item list comes from reading the dashboard fresh, not from what the orchestrator recalls doing earlier in the conversation. A stale cursor after a restart can re-spawn an item already marked ✅ done.
<!-- pln:only claude -->
- **Reading `args` as an object without parsing it first** — inside a Workflow script, `args` arrives as a JSON string regardless of how it was passed to the tool. Code that reads a field off it directly gets `undefined` silently; `JSON.parse(args)` first.
- **Silently substituting sequential `Agent` calls for `Workflow`** — falling back off the mandated `Workflow` script when it's genuinely unavailable or the session forbids it is fine; not disclosing the switch is not. The "starting item work" message must name whichever mechanism is actually running, not the one Step 5 defaults to.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Silently substituting the nested-`codex exec` fallback for the native multi-agent tool** — falling back off the native tool when it's genuinely unavailable is fine; not disclosing the switch is not. The "starting item work" message must name whichever mechanism is actually running, not the one Step 5 defaults to.
- **Treating an empty result as an item with nothing to do** — an agent that reached a final status can still have returned an empty message, and the fallback's `codex exec` can exit 0 having written nothing. Either is a failed run; stop rather than marking the item done. The fallback reports it as `STATUS=empty` and exits non-zero precisely so it can't be read as success.
- **Putting the brief on the command line** — a subagent brief is a page of markdown with backticks, quotes and `$` in it. Compose it in a file and pass its contents as the child's message (or `--brief` on the fallback); hand-escaping it into an argument is how a spawn ends up running a silently truncated prompt.
- **Reading the child's reasoning trace instead of its result** — on the native path the child returns a summary and its final message is the result; on the fallback the events file is the full trace. Read the final message; keeping the trace out of your context is the reason for spawning an agent at all.
- **Re-spawning a blocked item instead of resuming it** — a fresh agent knows nothing of the first attempt and starts the item over on top of the half-finished tree it left behind. Resume by the agent's handle (its thread id on the fallback); a fresh agent is the fallback for when the resume genuinely fails, not the default. Losing the handle is the same mistake one step earlier, which is why it goes into the handoff file the moment a `BLOCKED:` result arrives.
- **Expecting the blocked agent to stash its own work** — that's the orchestrator's job, not the agent's. In auto mode the orchestrator stashes after reading the `BLOCKED:` result. If neither does it, the next item starts on a tree carrying half of the previous one.
<!-- pln:endonly -->
