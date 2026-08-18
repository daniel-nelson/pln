---
name: pln-phase-finish-ship
---

# /pln phase: finish and ship

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first deferred-item revisit, final verification, follow-up, or shipping action. `Phase: finish-ship` is not permission to redo implementation or silently fix verification failures: a failure becomes durable item work and transitions back to `implementation` before any fix dispatch.

Persist verification results, follow-ups, Ship choice, PR base, and any downstream PR identity/outcome before reporting completion. When the requested stopping point or ship handoff is durably complete, set `Phase: complete`. On restart, reconcile those fields before repeating an external action; an uncertain push, PR creation, or CI action fails closed.

<!-- pln:include assurance-policy -->

### Step 6. Deferred-item revisit

After the last item completes, before final verification: walk back through any items marked ⏸ deferred (and any deferred sub-questions). For each, ask the user: "Revisit now, push to a future session, or drop?"

Auto-mode blocked nodes are different: `run-manifest.tsv` carries each concrete handoff and marks dependency descendants `waiting`. Ask each blocking question directly, one at a time, record the answer, continue from its retained worktree, then return to `Phase: implementation` and recompute readiness. Do not fold blockers or dependency waits into the "revisit / push / drop" prompt used for genuinely deferred items.

### Step 7. End-of-task verification + wrap-up

1. Write the exact ordered gauntlet to `evidence/final-verification.commands` and a normalized non-secret environment description to `evidence/final-verification.environment`. Run `bin/pln-assurance fingerprint` and persist all hashes before execution. Spawn one fresh-context agent with `{{SKILL_DIR}}/src/workers/final-verification.md`, those artifacts/fingerprint, `PLAN.md`, the project root, `evidence/final-verification.md`, `results/final-verification.txt`, and a 2048-byte budget. It runs the full gauntlet once, recomputes the fingerprint afterward, and fails if candidate identity moved. Validate its envelope and record only per-command pass/fail plus the exact hashes in the dashboard. Missing, empty, malformed, out-of-root, oversized, skipped, or mismatched results fail verification.
2. If anything fails: it's now a new item. Don't paper over. Either spawn an agent to fix-and-rerun, or spawn a spinoff if the failure is out-of-scope.
3. If notifications are on, fire them first (see Notifications): {{NOTIFY_CALL}}, summarizing the outcome (e.g. "pln: plan done, 8/8 items, gauntlet passed").
4. Sweep the run's own record for outstanding work (see Follow-ups) before drafting anything. A run that never looks reports whatever it happens to remember.
5. Final message to the user: one or two sentences saying what changed and what's next, in plain words. This message is the complete answer on its own — no pointer to `PLAN.md` for the rest (see Style's "Ending a message"). If genuine follow-ups remain, list them per the follow-up bar below.
6. If that message listed any follow-ups, run the to-do-location flow below. Anything it asks or offers is a message of its own — never folded into Step 8's ask.

### Step 8. Ship — hand off to `/pln-pr`

A finished plan is not a shipped one, and shipping is `/pln-pr`'s job: it reviews the branch with fresh-context reviewers, fixes what they find, verifies once, and opens the pull request. Pushing and running `gh pr create` from here instead skips all of it.

If root repository instructions explicitly declare that this repository self-hosts `/pln-pr` and therefore skips its own source review, honor that narrow exception: require the named offline gauntlet and manual installation, warn truthfully that source review did not run, then follow the repository's direct commit/push/PR path. Never apply that exception outside the repository that declares it.

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
### Follow-ups

Applies at Step 7's wrap-up, and at the equivalent point in `/pln-pr`. The bar and the closing-message shape are Style's "Ending a message" rules — true when checked, not done, and someone will need to act on it or decide about it later; a fixed finding is not a follow-up.

<!-- pln:include outstanding-sweep -->

**Full detail lives in `PLAN.md`,** not the closing message — the bullet list there names each follow-up, `PLAN.md` (or, in a standalone `/pln-pr` run with no `PLAN.md`, `REVIEW.md`) carries the rest.

<!-- pln:include todo-location -->
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
