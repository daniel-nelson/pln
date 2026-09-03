---
name: pln-phase-finish-ship
---

# /pln phase: finish and ship

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first deferred-item revisit, final verification, follow-up, or shipping action. `Phase: finish-ship` is not permission to redo implementation or silently fix verification failures: a failure becomes durable item work and transitions back to `implementation` before any fix dispatch.

Persist verification results, follow-ups, the queue close, Ship choice, PR base, and any downstream PR identity/outcome before reporting completion. When the requested stopping point or ship handoff is durably complete, set `Phase: complete`. On restart, reconcile those fields before repeating an external action; an uncertain push, PR creation, or CI action fails closed.

<!-- pln:include assurance-policy -->

### Step 6. Deferred-item revisit

After the last item completes, before final verification: walk back through any items marked ⏸ deferred (and any deferred sub-questions). For each, ask the user: "Revisit now, push to a future session, or drop?"

Auto-mode blocked nodes are different: `run-manifest.tsv` carries each concrete handoff and marks dependency descendants `waiting`. Ask each blocking question directly, one at a time, record the answer, continue from its retained worktree, then return to `Phase: implementation` and recompute readiness. Do not fold blockers or dependency waits into the "revisit / push / drop" prompt used for genuinely deferred items.

### Step 7. End-of-task verification + wrap-up

1. Write the exact ordered gauntlet to `evidence/final-verification.commands` and a normalized non-secret environment description to `evidence/final-verification.environment`. Run `bin/pln-assurance fingerprint` and persist all hashes before execution. Spawn one fresh-context agent with `{{SKILL_DIR}}/src/workers/final-verification.md`, those artifacts/fingerprint, `PLAN.md`, the project root, `evidence/final-verification.md`, `results/final-verification.txt`, and a 2048-byte budget. It runs the full gauntlet once, recomputes the fingerprint afterward, and fails if candidate identity moved. Validate its envelope and record only per-command pass/fail plus the exact hashes in the dashboard. Missing, empty, malformed, out-of-root, oversized, skipped, or mismatched results fail verification.
2. If anything fails: it's now a new item. Don't paper over. Either spawn an agent to fix-and-rerun, or spawn a spinoff if the failure is out-of-scope.
3. If notifications are on, fire them first (see Notifications): {{NOTIFY_CALL}}, summarizing the outcome (e.g. "pln: plan done, 8/8 items, gauntlet passed").
4. Sweep the run's own record for outstanding work (see Follow-ups) before drafting anything. A run that never looks reports whatever it happens to remember. Then file it: every candidate that clears the follow-up bar goes into the queue here, one `{{OUTPUT_ROOT}}/bin/pln-queue add` per item with `--source` naming this run, before the message below is drafted rather than after it. Close the queue out in the same step: every item this run claimed gets the state its work actually reached, an item it finished is archived with the evidence that closed it, and `pln-queue stale`'s candidates are carried into the message below for the user to confirm — their answer is what archives one of those, and an unanswered candidate is named again at the next close.
5. Final message to the user: one or two sentences saying what changed and what's next, in plain words. This message is the complete answer on its own — no pointer to `PLAN.md` for the rest (see Style's "Ending a message"). If genuine follow-ups remain, list them per the follow-up bar below.
6. The to-do-location flow below is part of drafting that message rather than a step after it, and it is never gated on what the message turned out to list — filing already happened above, so the message is written from the queue. What the flow settles is what that message has to say: where the follow-ups went, and whether this project names a destination pln did not write to. Anything it asks or offers is a message of its own, separate from the ship ask Step 8 makes under `implement only`, an absent field, or a plan predating it. Under either PR-bearing value there is no ask to be separate from: the hand-off is an action, not a question.

### Step 8. Ship — hand off to `{{PLN_PR_CMD}}`

A finished plan is not a shipped one, and shipping is `{{PLN_PR_CMD}}`'s job: it reviews the branch with fresh-context reviewers, fixes what they find, verifies once, and opens the pull request. Pushing and running `gh pr create` from here instead skips all of it.

If root repository instructions explicitly declare that this repository self-hosts `{{PLN_PR_CMD}}` and therefore skips its own source review, honor that narrow exception: require the named offline gauntlet and manual installation, warn truthfully that source review did not run, then follow the repository's direct commit/push/PR path. Never apply that exception outside the repository that declares it.

Read the dashboard's `Ship` field — not what the conversation remembers, so a restarted or resumed session doesn't have to recall a choice made turns ago:

- **`draft PR after implementation`** — the Step 4 gate already asked and got a yes, and asked for the PR to be left in draft. Hand off with no further prompt, on the state condition below, carrying the `draft=keep` argument through (see below) so `{{PLN_PR_CMD}}` opens the PR as a draft and closes with it still a draft rather than marking it ready on green.
- **`PR after implementation`** — the Step 4 gate already asked and got a yes. Hand off with no further prompt, on the state condition below.
- **`implement only`, absent, or the plan predates this field** — ask once, at the end of the Step 7 wrap-up message rather than in a message of its own: open the PR now, or stop here? Skip the ask entirely when there is nothing to put up — no commits ahead of the base branch — or when the user has already said where this run ends. On yes, hand off the same way. That ask is the last human turn before the PR is up, so it carries the review depth too: say in the same line that the branch's tier calls for its full roster and that `light` or `no review` cuts it. Record the answer in the Ship field before handing off, defaulting to `full`.

**Always hand off a review depth.** `{{PLN_PR_CMD}}` asks for one itself when none arrives, and a plan that leaves it unset turns a run that was meant to go unattended into one waiting on an answer. Read it from the Ship field; where the field predates it and no ask was made, pass `full`.

**When the hand-off fires, under either PR-bearing value.** Not at the end of Step 7's wrap-up: that is a position in this file, and a to-do-location question, a compaction, a session restart or a user interruption all leave it behind while the PR still isn't open. The trigger is a condition read out of durable state, the way `Ship` itself was just read. While `Phase: finish-ship` stands and `Ship` names a PR:

- **False until Steps 6 and 7 are recorded done** — every ⏸ deferred item carries the user's revisit/push/drop answer, the dashboard's Verification section carries the gauntlet's per-command results and fingerprint hashes, the sweep's outcome is recorded in the plan, and the queue close below has run. `Phase: finish-ship` is written before any of that happens, so without this bound a run resumed at that instant ships past its own verification. The wrap-up message leaves no durable mark of its own, so a turn that finds those writes in place and no sign the message went out sends it first and hands off in the same turn — the one thing the hand-off waits behind.
- **True from there until PR identity is durable** — the `PR identity` field in the `## State` section of the `REVIEW.md` beside this plan, which `{{PLN_PR_CMD}}` writes as soon as it creates or updates the PR. Without this bound every turn of the review, fix and blocker cycle the hand-off launched reads the same state and is told to hand off again.
- **While it holds, the hand-off is the first action of the turn,** and no message goes out in its place. The one exception is a question already persisted in the plan and still unanswered: it may be asked and the turn may end on it, and the hand-off is then the first action of the turn that carries the answer. `{{PLN_PR_CMD}}`'s own asks all come after the hand-off anyway.

**When the queue close fires.** Step 7's item 4 is a position in this file the same way the hand-off was, and the same compaction, restart or interruption leaves it behind. It leaves no durable mark of its own, so a close that never ran reads exactly like one that did. Its trigger is a condition over durable state too, stated here because a run cannot reach the hand-off's lower bound above without it. While `Phase: finish-ship` stands:

- **False until the sweep has filed** — every candidate that cleared the follow-up bar is in the queue. That keeps file-first-then-draft intact and stops the close reading a record the sweep is still writing.
- **True from there until every id this run claimed carries an outcome** — `[x]` archived with the evidence that closed it, or `[-]` with what remains readable as sub-items in its detail file. The claimed set is the ids the dashboard's `## Queue items` section records as claimed. An id whose record there is a refusal — the holder it named, or the collision `check` reported — is not in that set and needs no outcome. An id carrying no recorded claim result at all has not been shown to be outside it either, so it holds the bound until the run records what the attempt returned or drops the id from the declaration; a claim can be live in the queue with nothing on the plan side saying so, and nothing else recovers it. Neither state is read off the absence of the other. A plan carrying no `## Queue items` section declared nothing and satisfies this bound.
- **Also true while any id the plan records as archived still has a live record** at `<queue-root>/q/<id>.md` held by this run — `claimed_by` and `claimed_in` both matching, or `claimed_by` alone where the record predates `claimed_in` and reads back empty. Archiving removes the record, so its presence there contradicts the plan's own prose about its own id. One file open per archived id; it never tries to confirm that an archive happened, and it is not a `stale` line, so the rule that nothing waits on those candidates is untouched.
- **While it holds, the close is the turn's first action and precedes the wrap-up message.** That is the opposite of the hand-off above, which waits behind that message. A divergence either bound reports goes to the user and holds the run short of `Phase: complete`; it is never noted and passed over. Where the queue cannot be resolved or written at all, the escape below stands as it is: say so, and list inline.

Handing off:

<!-- pln:only claude -->
Invoke `{{PLN_PR_CMD}}` with the `Skill` tool. Its steps then arrive verbatim at the moment they are used, instead of being recalled from a description read an hour of implementation ago — which is why it is a separate skill rather than a section of this file.

When the dashboard's `Ship` field carries a `PR base: <branch>` line (item 4's stacking override), pass that branch through in the `args` string rather than making a human type it at PR time: `Skill({skill: "pln-pr", args: "base=<branch>"})`. When the field says `draft PR after implementation`, pass `draft=keep` the same way. The Ship field's review depth always travels as `review=full|broad|none`, so the args carry every applicable one together: `Skill({skill: "pln-pr", args: "base=<branch> draft=keep review=broad"})`.
<!-- pln:endonly -->
<!-- pln:only codex -->
This host has no tool that invokes a skill, so load it yourself: read `{{SKILL_DIR}}/pln-pr/SKILL.md` in full and follow it. Its steps then arrive verbatim at the moment they are used, instead of being recalled from a description read an hour of implementation ago — which is why it is a separate skill rather than a section of this file.

When the dashboard's `Ship` field carries a `PR base: <branch>` line (item 4's stacking override), there is no separate tool call to attach that argument to — carry it forward explicitly instead: when you reach `pln-pr/SKILL.md`'s Step 0, tell yourself the base is already decided (the stacked branch, not the auto-detected default) and follow that step's own validation before using it, rather than running its auto-detection. Carry `draft=keep` forward the same way when the field says `draft PR after implementation`, and the Ship field's review depth as `review=full|broad|none` always: at that same Step 0, record the leave-in-draft disposition and the review depth in `REVIEW.md` as if both had arrived as arguments.
<!-- pln:endonly -->

This holds for a PR ask anywhere in the session, not only at the end. "Put up a PR", "ship it", and PR asks carried inside a longer instruction — "bump the version and open the PR", "push this up" — all route through `{{PLN_PR_CMD}}`. The one exception is an explicit "skip the review", which you honor.
### Follow-ups

Applies at Step 7's wrap-up, and at the equivalent point in `{{PLN_PR_CMD}}`. The bar and the closing-message shape are Style's "Ending a message" rules — true when checked, not done, and someone will need to act on it or decide about it later; a fixed finding is not a follow-up.

<!-- pln:include outstanding-sweep -->

**Full detail lives in `PLAN.md`,** not the closing message — the bullet list there names each follow-up, `PLAN.md` (or, in a standalone `{{PLN_PR_CMD}}` run with no `PLAN.md`, `REVIEW.md`) carries the rest.

<!-- pln:include todo-location -->
<!-- pln:include queue-format -->

## Failure modes to watch for

- **Building out the feature under discussion before the plan is adopted** — inline, or by spawning a sub-agent/workflow to do it; delegating is not a loophole. Before any state-changing tool call during Steps 1–4, run Step 3's feature-work-vs-exceptions test. This applies even when the user asked for it directly, named the delegation mechanism themselves, or it targets a different repo. If it happens anyway and the user calls it out — in any words, not just a reference to "pln" or "the interview" — halt immediately: kill any spawned background work, disclose exactly what changed, and offer to revert, rather than acknowledging the pushback and continuing past it.
- **Resuming an in-flight interview from a hand-off note instead of reloading this file** — a session that picks up a `{{PLN_CMD}}` interview from a summary written by a prior run (a compaction, a session-boundary hand-off) still has to (re-)load `SKILL.core.md`'s interview rules, not rely solely on the note's prose recap of what went wrong last time. A postmortem-toned summary of a past mistake primes overcorrection into the opposite failure — e.g. treating an ordinary plan decision as an ambiguous request to break out of the interview. The note calibrates against repeating the same mistake; it is not a substitute for the actual rule text.
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
- **Trusting a remembered item cursor instead of durable state** — rebuild outcomes from `PLAN.md` and execution state from the validated run manifest. A stale cursor after restart can respawn integrated work or skip a checkpoint waiting to integrate.
<!-- pln:only claude -->
- **Stringifying structured Workflow input** — saved-workflow `args` is structured data already. Read it directly; stringifying or parsing it recreates an obsolete contract and can corrupt a resumed fan-out's input.
- **Putting the user-interruptible item loop inside Workflow** — Workflow has no mid-run user-input channel. Sequential item work uses named background Agents; Workflow remains for genuine independent fan-out. If native Agent is unavailable and the helper fallback runs, disclose that switch.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Silently substituting the nested-`codex exec` fallback for the native multi-agent tool** — falling back off the native tool when it's genuinely unavailable is fine; not disclosing the switch is not. The "starting item work" message must name whichever mechanism is actually running, not the one Step 5 defaults to.
- **Treating an empty result as an item with nothing to do** — an agent that reached a final status can still have returned an empty message, and the fallback's `codex exec` can exit 0 having written nothing. Either is a failed run; stop rather than marking the item done. The fallback reports it as `STATUS=empty` and exits non-zero precisely so it can't be read as success.
- **Putting the brief on the command line** — a subagent brief is a page of markdown with backticks, quotes and `$` in it. Compose it in a file and pass its contents as the child's message (or `--brief` on the fallback); hand-escaping it into an argument is how a spawn ends up running a silently truncated prompt.
- **Reading the child's reasoning trace instead of its result** — on the native path the child returns a summary and its final message is the result; on the fallback the events file is the full trace. Read the final message; keeping the trace out of your context is the reason for spawning an agent at all.
- **Re-spawning a blocked item instead of continuing it** — a fresh agent knows nothing of the first attempt. Use `followup_task` on the idle native agent (or the captured thread id on the CLI fallback); a fresh agent is only the recovery path when that identity is genuinely gone. Persist the identity in the handoff the moment `BLOCKED:` arrives.
- **Moving blocked work through an anonymous stash** — blocker recovery is the manifest's named retained worktree plus handoff/result, not a shifting `stash@{N}`. Keep it isolated and dispatch only proven-independent nodes.
<!-- pln:endonly -->
