---
name: pln-pr
description: Review a branch and put up a pull request, the pln way — fresh-context reviewers find issues, a fix pass clears them under one durable ledger, and verification runs once before the PR opens. Universal — depends only on git, {{ORCH_TOOLS}}, and optionally the GitHub/GitLab CLI. Trigger explicitly via `{{PLN_PR_CMD}}`, or when the user asks to put up / open / create / make a PR or "ship it" — including when that ask is embedded in a larger instruction like "bump the version and open the PR", "and open the PR", or "push this up". Typically right after a `{{PLN_CMD}}` run, but works standalone on any branch with commits ahead of its base. A larger imperative that ends in opening a PR still routes here; do not push and run `gh pr create` directly for it unless the user explicitly says to skip the review.
---

# pln-pr — review and open a pull request

Take the work on the current branch, review it with fresh-context reviewers, fix what they find, verify once, and open the pull request. Read every section of this file before starting, then execute. Keep the workflow lean; do not add ceremony it does not ask for.

<!-- pln:include compaction-recovery -->

<!-- pln:include update-check -->

<!-- pln:include pr-notify-setup -->

<!-- pln:include readiness -->

## When to engage

Engage when the user types `{{PLN_PR_CMD}}`, or asks to put up / open / create / make a PR or "ship it", on a branch that has commits ahead of its base. Most often this comes right after a `{{PLN_CMD}}` run completed its own gauntlet; it also works standalone on any feature branch.

**The trigger holds even when the PR ask is one clause of a bigger instruction.** "Bump the version and open the PR", "commit and push this up", "and then open the PR" all route here. Review depth is the user's to set and no one else's: it is `full`, `broad`, or `none`, and it comes from `{{PLN_CMD}}`'s adoption gate, a `review=` argument, an explicit instruction in the invoking message, or the one ask scope-baseline makes when none of those supplied it. `plan_review=false` never applies to PR review. Honor whatever depth is set, but classify risk first and warn clearly when a depth below the tier's roster is what runs, naming the concrete trigger that set the tier rather than a tier name — for `none` on critical work, that critical assurance was skipped entirely. A repository's explicit self-hosting rule for the workflow that defines `{{PLN_PR_CMD}}` counts as that repository's narrow skip only when its named substitute gauntlet/manual-install assurance is performed; never generalize it.

If the branch has no commits ahead of base, say so and stop — there is nothing to put up.

## Hard constraints (no exceptions)

<!-- pln:only claude -->
- **No dependency on any external service or the gstack ecosystem.** git, `gh`/`glab` (optional), the harness Agent/Workflow tools, and optionally a peer agent CLI (`codex`, or whatever `peer_command` names) are the only tools. If a tool is absent, degrade gracefully and continue.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **No dependency on any external service or the gstack ecosystem.** git, `gh`/`glab` (optional), the `codex` CLI itself, and optionally a peer agent CLI (`claude`, or whatever `peer_command` names) are the only tools. If a tool is absent, degrade gracefully and continue.
<!-- pln:endonly -->
- **Never re-run the gauntlet after a fix cycle, and never run the behavior suite locally when CI is going to run it.** Verification happens at most twice in a flow: an *optional* pre-review baseline (Step 2, skipped whenever a green baseline already exists) and the *mandatory* post-fix run (Step 7, on the final tree). Fixes accumulate between them; nothing runs per fix cycle. Both of those runs are the project's **static checks** — lint, type-check, build, generated-artifact freshness — because those are what an agent's edit breaks and a lint error reaching CI wastes an entire CI run. The **behavior suite** stays with CI, which parallelizes it across jobs no single machine matches — feature and end-to-end specs most of all, since each drives a real browser and local parallelism is rarely configured for them. The whole suite runs locally for two reasons only: the project's instructions say to, or there is no CI that will. A change touching tests or uncovered code buys *those* tests, targeted, never the suite. This is the whole reason this skill exists instead of a re-run loop.
- **Reviewers run in fresh context.** Every reviewer and fix agent is a blank-slate agent. The orchestrator does not read code or apply fixes itself.
- **Findings are durable, best-effort.** Merged findings live in `REVIEW.md` before any fix runs, and Step 1 resumes an existing ledger rather than re-reviewing from scratch. Resume is best-effort, not transactional: a fix commit lands before its status is written back, so a crash in that narrow window can leave a fixed finding still marked `open` — on resume, re-checking it is cheap and safe, so prefer re-running a possibly-done fix over skipping a possibly-open one.
- **No push and no PR unless `REVIEW.md` reads `Phase: ship-watch`.** Before `git push`, `gh pr create`/`gh pr edit` or `glab mr create`/`glab mr update`, read the ledger's `Phase`. If there is no ledger or it names another phase, do not run the command; go back to the phase it names. A helper or reviewer that fails is a blocker to record, not a reason to leave the ledger and ship by hand. One run did that and opened a PR with its ledger still at `scope-baseline`. It had never read the phase that bumps the version, so the PR shipped without the bump the repository requires.
- **Commit discipline:** commit only complete, verified work with the co-author trailer; never `--amend`, never `--no-verify`, never `git add -A` (stage fixed files by name).
<!-- pln:include next-action -->

## Phase router

This file is the always-loaded PR coordinator contract. Detailed scope, review, fix, blocker, and ship/watch instructions live in generated phase documents. Read this router in full on every invocation and after compaction.

Every `REVIEW.md` has a top-level `## State` section containing one `Phase` value: `scope-baseline`, `review`, `fix`, `blocker`, `ship-watch`, or `complete`. The same state section persists a durable run identity, the canonical plan root, validated base/source, trust/command confirmation, diff base and reviewed-diff fingerprint, review depth, owner constraints, command graph, tree/command/environment/candidate fingerprints, simplification freshness status/policy/bypass binding, semantic risk and roster, review status, PR identity/disposition, and CI round/status. Resolve the plan root once from the ledger's canonical parent and derive every coordinator-written path from it, and every worker's evidence/result path from the ledger's worker artifact root, which differs from it only when the plan root is outside the repository; never keep re-transcribing paths from a prompt. Those fields, not conversational memory, decide safe resume behavior.

At every boundary, finish the old phase's ledger/state writes first. Then write the new cursor. Then read the mapped document in full before the phase's first action. In short: write durable state first, then advance `Phase`, then read the new phase file and act. Persist a user decision or blocker question before sending it, and persist external identities/results before advancing past the action that created them. A constraint the owner states mid-run on what repairs may build or how far scope may grow, or a statement lifting one, is appended verbatim to `Owner constraints` in a candidate of its own, sourced `owner message`: after any in-flight merge's candidate is published or fails, and before the next review brief is assembled or worker is dispatched. A worker already running finishes on its brief.

Every canonical ledger mutation uses `{{OUTPUT_ROOT}}/bin/pln-publish-review`: write a complete nonempty candidate beneath the plan root with the same `Run identity` and `Ledger generation` incremented by one, then publish it with the current generation and SHA-256 (or `absent`/`0` for creation). Never edit, append, delete, recreate, or rename onto `REVIEW.md` directly. A stale rejection means reread and reconcile; it never authorizes retrying the old candidate. This gives process-visible old-or-new replacement, not power-loss durability.

For an existing pre-publisher ledger with a Run identity but no `Ledger generation`, preserve every byte of its state in a candidate that adds `Ledger generation: 1`, and publish it once with the legacy ledger's exact digest and expected generation `0`. This is a resume migration, not a new run or permission to overwrite the ledger.

On invocation or after compaction, reread this router, locate `REVIEW.md`, read its `State` section, reconcile completed commits/review/PR/CI work, and read exactly one mapped phase file in full before the phase's first action. Do not preload later phases. With no ledger, start `scope-baseline` and load that file before probing remotes or running commands.

For a legacy ledger without `Phase`, derive and persist the most conservative compatible cursor: an absent baseline/trust record means `scope-baseline`; no completed review means `review`; open findings mean `fix`; a handoff or unanswered fix decision means `blocker`; resolved findings awaiting final verification/PR/CI mean `ship-watch`; a terminal PR/CI or deliberate local stop means `complete`. If more than one state fits, the cursor contradicts the ledger/tree, the recorded base or trust state is missing, or an external action may already have happened without its identity being recorded, fail closed: do not rerun review, fix, push, create a PR, or advance CI; state the conflict and ask one question.

### Phase map

- `scope-baseline` → `{{OUTPUT_ROOT}}/phases/pln-pr/scope-baseline.md`
- `review` → `{{OUTPUT_ROOT}}/phases/pln-pr/review.md`
- `fix` → `{{OUTPUT_ROOT}}/phases/pln-pr/fix.md`
- `blocker` → `{{OUTPUT_ROOT}}/phases/pln-pr/blocker.md`
- `ship-watch` → `{{OUTPUT_ROOT}}/phases/pln-pr/ship-watch.md`

`complete` has no phase document. Unknown values fail closed.

### Transition table

- No ledger → `scope-baseline`; write the State skeleton before durable scope work.
- Trusted, fingerprinted scope/baseline → `review` after its commands and results are recorded.
- Review merged → `fix` when acted-on findings remain, otherwise `ship-watch`.
- Fix decision or worker blocker → `blocker` after its question/handoff is recorded; resolved blocker → `fix` after its answer is durable.
- Findings resolved and post-fix checks recorded → `ship-watch`.
- Final gauntlet plus PR/CI outcome or deliberate stop recorded → `complete`.

<!-- pln:include model-routing-policy -->

<!-- pln:include model-routing-host -->

<!-- pln:include context-firewall -->

## Spawning a fresh-context agent

Every reviewer, fix pass, and verification run below is a **fresh-context agent**: a blank-slate worker that gets one prompt, does the work, and returns one final message. It has none of this conversation's context, so its brief carries everything it needs — the diff command, the ledger path, the findings it owns.

How to spawn one on this host:

<!-- pln:include spawn-agent -->
<!-- pln:only codex -->

<!-- pln:include goal-persistence -->
<!-- pln:endonly -->

## Interaction discipline

This skill follows pln's discipline. Never call the `AskUserQuestion` tool. Surface at most one decision at a time, as plain prose. When you record a user's answer, echo it back in one short line before moving on. The Style section below is the same text `{{PLN_CMD}}` carries, generated from one shared source, and it governs every message this skill produces.

<!-- pln:include style -->

<!-- pln:include voice -->

<!-- pln:include style-formatting -->

<!-- pln:include router-end -->
