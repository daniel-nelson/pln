---
name: pln-pr
description: Review a branch and put up a pull request, the pln way — a fresh-context review army finds issues, a fix pass clears them under one durable ledger, and the gauntlet runs once before the PR opens. {{REVIEW_ARMY_SHORT}}; findings land in `REVIEW.md`; fixes run as clustered fix agents; verification happens once at the end, not per fix cycle. Universal — depends only on git, {{ORCH_TOOLS}}, and optionally the GitHub/GitLab CLI. No external service, no server, no gstack. Trigger explicitly via `/pln-pr`, or when the user asks to put up / open / create / make a PR or "ship it" — including when that ask is embedded in a larger instruction like "bump the version and open the PR", "and open the PR", or "push this up". Typically right after a `/pln` run, but works standalone on any branch with commits ahead of its base. A larger imperative that ends in opening a PR still routes here; do not push and run `gh pr create` directly for it unless the user explicitly says to skip the review.
---

# pln-pr — review and open a pull request

You are running the user's personal PR workflow. It is the ship half of a plan: take the work on the current branch, review it with fresh-context reviewers, fix what they find, verify once, and open the pull request. Read every section of this file before starting, then execute. The user tuned this to be lean on purpose — it carries the review intelligence and none of the runtime scaffolding a heavier ship tool drags along. Do not add ceremony it does not ask for.

<!-- pln:only claude -->
**Resolve pln's helpers**: `/pln-pr` reuses `/pln`'s `bin/` scripts. They live at the pln repo root, one level *above* this skill's own directory, so `${CLAUDE_SKILL_DIR}/bin` does **not** point at them (this skill is a subdirectory of the pln repo, symlinked in as its own command). Find the install once and reuse it:
<!-- pln:endonly -->
<!-- pln:only codex -->
**Resolve pln's helpers**: `/pln-pr` reuses `/pln`'s `bin/` scripts, which live at the pln repo root, one level *above* this skill's own directory. Find the install once and reuse it:
<!-- pln:endonly -->

```bash
_PLN_DIR=""
for d in "$HOME/.claude/skills/pln" "$HOME/.agents/skills/pln" ".claude/skills/pln" ".agents/skills/pln"; do
  [ -x "$d/bin/pln-config" ] && _PLN_DIR="$d" && break
done
echo "PLN_DIR: ${_PLN_DIR:-none}"
```

<!-- pln:only claude -->
If `PLN_DIR` is `none`, the helpers aren't found: skip the config-gated notification setup below and treat notifications as off. The skill still works end to end; you just won't get pushes. Every `pln-config` / `pln-notify-desktop` call below is `"$_PLN_DIR/bin/..."` and only runs when `_PLN_DIR` is set.
<!-- pln:endonly -->
<!-- pln:only codex -->
If `PLN_DIR` is `none`, the helpers aren't found: skip the config-gated notification setup below and treat notifications as off. The skill still works end to end; you just won't get desktop notifications. Every `pln-config` / `pln-notify-desktop` call below is `"$_PLN_DIR/bin/..."` and only runs when `_PLN_DIR` is set — substitute the real path, since each shell call starts fresh and the variable does not persist.
<!-- pln:endonly -->

<!-- pln:include pr-notify-setup -->

<!-- pln:include readiness -->

## When to engage

Engage when the user types `/pln-pr`, or asks to put up / open / create / make a PR or "ship it", on a branch that has commits ahead of its base. Most often this comes right after a `/pln` run completed its own gauntlet; it also works standalone on any feature branch.

**The trigger holds even when the PR ask is one clause of a bigger instruction.** "Bump the version and open the PR", "commit and push this up", "and then open the PR" all route here. Review depth is the user's to set and no one else's: it is `full`, `broad`, or `none`, and it comes from `/pln`'s adoption gate, a `review=` argument, an explicit instruction in the invoking message, or the one ask scope-baseline makes when none of those supplied it. `plan_review=false` never applies to PR review. Honor whatever depth is set, but classify risk first and warn clearly when a depth below the tier's roster is what runs — for `none` at R3, that critical assurance was skipped entirely. A repository's explicit self-hosting rule for the workflow that defines `/pln-pr` counts as that repository's narrow skip only when its named substitute gauntlet/manual-install assurance is performed; never generalize it.

If the branch has no commits ahead of base, say so and stop — there is nothing to put up.

## Interaction discipline

This skill follows pln's discipline. Never call the `AskUserQuestion` tool. Surface at most one decision at a time, as plain prose. When you record a user's answer, echo it back in one short line before moving on. The Style section below is the same text `/pln` carries, generated from one shared source, and it governs every message this skill produces.

<!-- pln:include style -->

<!-- pln:include voice -->

<!-- pln:include style-formatting -->

## Hard constraints (no exceptions)

<!-- pln:only claude -->
- **No dependency on any external service or the gstack ecosystem.** git, `gh`/`glab` (optional), the harness Agent/Workflow tools, and optionally a peer agent CLI (`codex`, or whatever `peer_command` names) are the only tools. If a tool is absent, degrade gracefully and continue.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **No dependency on any external service or the gstack ecosystem.** git, `gh`/`glab` (optional), the `codex` CLI itself, and optionally a peer agent CLI (`claude`, or whatever `peer_command` names) are the only tools. If a tool is absent, degrade gracefully and continue.
<!-- pln:endonly -->
- **Never re-run the gauntlet after a fix cycle, and never run the behavior suite locally when CI is going to run it.** Verification happens at most twice in a flow: an *optional* pre-review baseline (Step 2, skipped whenever a green baseline already exists) and the *mandatory* post-fix run (Step 7, on the final tree). Fixes accumulate between them; nothing runs per fix cycle. Both of those runs are the project's **static checks** — lint, type-check, build, generated-artifact freshness — because those are what an agent's edit breaks and a lint error reaching CI wastes an entire CI run. The **behavior suite** stays with CI, which parallelizes it across jobs no single machine matches; it runs locally only where CI will not run it at all (no CI, a change to the tests themselves, uncovered code, or the user asking). This is the whole reason this skill exists instead of a re-run loop.
- **Reviewers run in fresh context.** Every reviewer and fix agent is a blank-slate agent. The orchestrator does not read code or apply fixes itself.
- **Findings are durable, best-effort.** Merged findings live in `REVIEW.md` before any fix runs, and Step 1 resumes an existing ledger rather than re-reviewing from scratch. Resume is best-effort, not transactional: a fix commit lands before its status is written back, so a crash in that narrow window can leave a fixed finding still marked `open` — on resume, re-checking it is cheap and safe, so prefer re-running a possibly-done fix over skipping a possibly-open one.
- **Commit discipline:** commit only complete, verified work with the co-author trailer; never `--amend`, never `--no-verify`, never `git add -A` (stage fixed files by name).
<!-- pln:include next-action -->

<!-- pln:include model-routing-policy -->

<!-- pln:include model-routing-host -->

<!-- pln:include context-firewall -->

## Spawning a fresh-context agent

Every reviewer, fix pass, and verification run below is a **fresh-context agent**: a blank-slate worker that gets one prompt, does the work, and returns one final message. It has none of this conversation's context, so its brief carries everything it needs — the diff command, the ledger path, the findings it owns.

How to spawn one on this host:

<!-- pln:include spawn-agent -->

## Phase router

This file is the always-loaded PR coordinator contract. Detailed scope, review, fix, blocker, and ship/watch instructions live in generated phase documents. Read this router in full on every invocation and after compaction.

Every `REVIEW.md` has a top-level `## State` section containing one `Phase` value: `scope-baseline`, `review`, `fix`, `blocker`, `ship-watch`, or `complete`. The same state section persists a durable run identity, the validated base/source, trust/command confirmation, diff base, review depth, tree/command/environment/candidate fingerprints, simplification freshness status/policy/bypass binding, semantic risk and roster, review status, PR identity, and CI round/status. Those fields, not conversational memory, decide safe resume behavior.

At every boundary, finish the old phase's ledger/state writes first. Then write the new cursor. Then read the mapped document in full before the phase's first action. In short: write durable state first, then advance `Phase`, then read the new phase file and act. Persist a user decision or blocker question before sending it, and persist external identities/results before advancing past the action that created them.

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
