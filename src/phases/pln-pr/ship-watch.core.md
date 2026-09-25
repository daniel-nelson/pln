---
name: pln-pr-phase-ship-watch
---

# /pln-pr phase: ship and watch

<!-- pln:include active-turn-lifecycle -->

Read this file in full before version/changelog, final-gauntlet, push, PR, or CI actions. Reconcile the stored tree fingerprint, command/environment fingerprint, PR identity, and CI round before reusing results or repeating an external action. Conflicts or uncertain external completion fail closed.

Every gauntlet, PR, watch, CI-round, blocker, and completion ledger mutation is a complete next-generation candidate published through `{{OUTPUT_ROOT}}/bin/pln-publish-review` with the current digest/generation before the next external action. Never edit or recreate canonical `REVIEW.md`; stale publication means reread the ledger and reconcile forge/tree state before continuing.

Write new tree/command/environment/candidate fingerprints after every fix, non-metadata edit, command graph, environment, or CI edit and invalidate stale verification. A proven version/release-metadata-only late correction follows the narrow reuse rule below. Persist the final gauntlet before push; persist PR identity immediately after create/update; persist every CI round and outcome before another fix/watch cycle. After terminal handoff, watched-green status, or the user's deliberate stop is durable, set `Phase: complete`.

<!-- pln:include assurance-policy -->

### Step 6. Version and changelog (conditional — before the gauntlet)

First refresh the already resolved base and run `bin/pln-assurance diff-fingerprint --root . --base "origin/$BASE"`. Compare its `DIFF_BASE` and `REVIEW_DIFF_SHA256` with the ledger-bound reviewed subject. A byte-identical reviewed diff preserves review even when the base ref moved. Any changed reviewed byte invalidates review and returns to the review phase before gauntlet dispatch or any version-only reuse decision. Never let “the base was refreshed” stand in for this comparison.

This runs *before* the final gauntlet so the release files are verified by it, not after. Read the repo's `CLAUDE.md`/`AGENTS.md` first for a stated version-bump rule and follow it, whatever file(s) it names. Treat `VERSION`/`CHANGELOG.md` as one common shape of that convention, not the definition of "this repo has a version" — a repo that states its own rule around different files still gets a bump; a repo with no stated rule and no `VERSION` file and no `CHANGELOG.md` gets skipped entirely. If neither the stated rule nor the `VERSION`/`CHANGELOG.md` shape applies, skip this step entirely; most repos don't use either and pln-pr must not impose one.

**Skip the bump if the branch already carries one.** A retry, or a branch that bumped its own version as part of the work, must not bump again. Compare the branch's version file against the base — `<base>` here is whatever Step 0 resolved (the stacked-PR override when one was given, the repo default otherwise), so the "already bumped" check compares against the actual PR base, never silently against the repo default when an override is in play:

```bash
git show "origin/<base>:VERSION" 2>/dev/null
```

If that base value differs from the working-tree version (the branch is already ahead), the bump is done — do not touch the version file(s), just note "version already bumped (X → Y)" and continue. Only when the branch's version still matches the base do you bump.

When you do bump: raise the version per the repo's scheme (read recent changelog entries to infer major/minor/patch conventions) and add a matching changelog entry describing what shipped. If the repo's `CLAUDE.md`/`AGENTS.md` states a bump rule, follow it over the `VERSION`/`CHANGELOG.md` default. Commit these with the co-author trailer, so they are part of the tree the Step 7 gauntlet runs against.

Run the cheap declared gates now, before fingerprinting or dispatching the functional gauntlet: base/version freshness, release metadata consistency, and repository package/version validation. A failure here stops without spending the expensive run. Only after they pass, write the final command graph and environment identity.

### Step 7. Final gauntlet — once

In this step `<plan-dir>` and `<plan-root>` both mean the ledger's `Worker artifacts`: every file the step writes is the gauntlet worker's input or output, and the result is recorded in the ledger. Write the ordered legacy commands or `PLN_GAUNTLET_V1` graph to `<plan-dir>/evidence/final-gauntlet.commands` and the normalized non-secret environment/executor requirements to `<plan-dir>/evidence/final-gauntlet.environment`. Compute the exact candidate fingerprint with `bin/pln-assurance fingerprint`, and persist all four hashes before functional work runs. Confirm untrusted commands first.

For a declared graph with coordinator commands, run the known coordinator-only subset first with `$_PLN_DIR/bin/pln-gauntlet run --root <project-root> --commands <plan-root>/evidence/final-gauntlet.commands --environment <plan-root>/evidence/final-gauntlet.environment --logs <plan-root>/evidence/final-gauntlet.coordinator.logs --status <plan-root>/evidence/final-gauntlet.coordinator.status --executor coordinator`. They are never first attempted in a worker. Persist that status before dispatch. Then spawn one fresh-context agent to run the worker subset on the same recorded graph and candidate—including version/changelog changes—with the coordinator status as its prerequisite evidence. A V1 graph containing a coordinator command refuses the default `--executor all`, so omission cannot collapse this split. A legacy list has no executor declarations and keeps its serial default.

Recompute afterward; any mismatch fails. Record pass/fail/refused/incomplete per command plus tree/command/environment/candidate hashes in `REVIEW.md`, and which tier and executor each command belongs to.

Legacy plain command lists stay serial. For `PLN_GAUNTLET_V1`, only commands in the same declared-ready parallel group overlap. Dependencies and exclusive resources gate readiness; declared tree-mutating commands serialize. Each command has its own raw log and exit status, and the joined result follows declaration order. The exact graph is fingerprinted. Aggregate failure, an incomplete dependency, or any command-caused tree mutation fails closed even when the command declared that it mutates. The skill never infers parallel safety.

**The static checks always run here. The behavior suite runs only under an exception below.** The two are not the same purchase. Static checks cost seconds, catch what an agent's edit actually breaks, and a lint or build error that reaches CI burns a whole CI run — every job, every container — to report something a local command reports instantly. The behavior suite costs minutes, and CI runs it across parallel jobs that no single machine matches; running it locally first buys a slower copy of an answer CI is about to produce anyway, and then CI produces it again regardless.

**Running the whole suite locally has exactly two justifications**, and neither is a judgment call:

- **The project's own instructions say to.** A `CLAUDE.md`/`AGENTS.md` that names a full local run before pushing is the answer; follow it. This is the only "unless" — the project knows things about its suite that this run does not.
- **There is no CI that will run it.** No CI configured, or none on this branch. Then the local run is not a duplicate, it is the only run there will ever be.

Everything else that seems to argue for the suite argues for **targeted tests instead**. When the change touches tests, or touches code the required checks demonstrably do not cover, run *those* tests — the specific files, or the narrowest selector the runner takes — and never the suite to reach them. Changing four specs is a reason to run four specs. This matters most for feature and end-to-end specs: each one drives a real headless browser, the per-test overhead makes local parallelism awkward to configure and rare in practice, and a full local feature run is the single most expensive thing this flow can do. CI parallelizes them across jobs; a laptop mostly does not.

If the project names no static checks at all, there is simply nothing to run here — that is a thin local gate, not a reason to fall back to the suite. Record in `REVIEW.md` what ran and, where the suite ran, which of the two justifications applied.

Outside those, a green static pass plus any targeted tests is what this step certifies, and the suite is CI's job. This is a change in *what is verified locally*, not in how strictly: a red static check still means the branch does not ship, and the candidate fingerprint still covers the commands that actually ran.

**Step 7 spawns exactly one agent, and there is no adjudication worker.** The coordinator records the result from that agent's envelope and from the exit status of anything it runs or reruns below. Evidence the coordinator already holds is never handed to a second agent to be judged.

**This step carries its worker brief inline, below — there is no separate contract file for the final gauntlet.** The installed `src/workers` directory holds contracts for other phases; the one there whose subject most resembles this step's is addressed to a different skill, opens by requiring a `PLAN.md` that a standalone `{{PLN_PR_CMD}}` run does not have, and rules a refused command out of existence on that skill's terms rather than on these. A real run searched that directory, found it, and followed the wrong rule. Execution instructions come only from the inline brief; the shared context-envelope contract named there supplies the return shape, not gauntlet policy.

Give it that root once; it derives the two artifact files, evidence path, and result path beneath it. Also give the persisted fingerprint, project root, routing attribution, and a 2048-byte budget:

"Read `$_PLN_DIR/src/workers/context-envelope.md` for the one shared result format. For `PLN_GAUNTLET_V1`, run exactly `$_PLN_DIR/bin/pln-gauntlet run --root <project-root> --commands <plan-root>/evidence/final-gauntlet.commands --environment <plan-root>/evidence/final-gauntlet.environment --logs <plan-root>/evidence/final-gauntlet.worker.logs --status <plan-root>/evidence/final-gauntlet.worker.status --executor worker --completed <plan-root>/evidence/final-gauntlet.coordinator.status`; omit `--completed` only when the graph contains no coordinator command. For a legacy list, use the same paths without executor/completed flags; legacy lists are serial. Only the declared graph may overlap. Do not add a command, drop one, or repeat the set. Keep each command's exact invocation, exit status and full output in its assigned evidence log rather than your reply. Recompute the candidate fingerprint after the last command and fail if candidate identity moved. Never turn an absent, skipped, timed-out, empty, dependency-blocked, or tree-mutating result into a pass. Where the execution environment refuses a command outright — a denied write, a blocked network call, a capability you were not given — that is not a verification result: record which command it was and the refusal verbatim, mark it refused rather than failed, and run the remaining commands that are still ready. Write the shared envelope to the derived result path, then self-validate it with `$_PLN_DIR/bin/pln-read-envelope --root <plan-root> --max-bytes 2048`. Return success only after that validator passes, and reply only `RESULT_FILE=<absolute result path>`."

The coordinator runs the same `pln-read-envelope` command itself and remains authoritative. Worker self-validation removes malformed retries; it does not move the trust boundary.

**A refused command leaves the gauntlet incomplete — not failed, and not destroyed.** The coordinator holds access the agent it spawned does not, so the rerun is the coordinator's own: run exactly that one command, with the access it needs, its output redirected to `<plan-dir>/evidence/final-gauntlet.md` and never read back into coordinator context. What reaches this context is the command's exit status plus three recorded facts — **which command was refused, the exact refusal, and what access the rerun was granted**. An exit status is bounded metadata, not a log, so the context firewall holds without a second agent between you and the result. What still forces a whole repeat is the tree changing or the command set changing; a refusal does neither.

Two conditions on combining that rerun with the recorded run, both answerable before you act:

- **Completeness.** Every command in the recorded set carries a result, from the recorded run or from a named rerun. A command that never executed makes the gauntlet incomplete, and an incomplete gauntlet is not a pass.
- **The refusal must not be a claim about the code.** Where the branch's own diff touches the refused command, or changed what that command requires, the refusal *is* a verification result and the rerun does not repair it. Answer that from `git diff "$DIFF_BASE"` and the command set. Without it, a branch that adds an unvendored dependency ships green: the build reaches the network, the agent is denied, and the rerun is granted the network the branch itself now needs.

**What that produces is a qualified pass, not a green.** Record it in `REVIEW.md` and in the PR body as green except the named command, which ran at elevated access, carrying both environment hashes — the one the refused pass ran under and the one the rerun ran under. A command can pass *because* of the privilege it was rerun under, and nothing here tells that apart from a command that merely needed the privilege in order to run, so the qualification is disclosed rather than absorbed into a green nobody can audit. The two hashes differ, and that difference is the record; nothing is being reused under a matching seal.
<!-- pln:only codex -->
Same spawn shape as Step 2: the agent runs with `--sandbox workspace-write` and no network. The refusal rule above is Step 7's own — Step 2's caveat does not govern here.
<!-- pln:endonly -->

If it fails: the branch does not ship. Surface the failure and stop (or spawn one fix agent if the fix is obvious and in-scope, then this single gauntlet re-runs — not the whole flow).

If a second base refresh after this green run forces a release correction, snapshot and compare the exact before/after changed paths and hunks. When every changed byte is a repository-declared mechanical version/release-metadata field, preserve the functional result and rerun only the declared version/package validation; bind the earlier and corrected tree hashes plus that result in the ledger. A mixed version-and-code delta, an unproved whole-file exclusion, a command-graph change, or an environment change invalidates the gauntlet and returns to the appropriate earlier phase. A pure version bump never triggers the functional gauntlet.

### Step 8. Commit, push, and open (or update) the PR

Refresh the resolved base once more before push and repeat the reviewed-diff reconciliation. If the diff changed, return to review. If only repository-declared release metadata must change, apply the proven version-only correction path above; otherwise invalidate the functional gauntlet. This is the late-drift boundary that prevents a base-relative version failure from being discovered after expensive verification with no reuse rule.

**Sweep and file before you push.** Sweep the run's own record for outstanding work (Follow-ups, below) — this is where the follow-up list is assembled, and both closes below reuse it — and file it now: one `{{OUTPUT_ROOT}}/bin/pln-todo add` per candidate that clears the bar, `--source` naming this review. Order matters because the to-do list may live *in* the repository: under a root the project's own instructions named, the filed items are tracked files, and a to-do list write after the push never reaches the pushed `HEAD` — it sits uncommitted on the machine that ran pln-pr while the branch a reviewer opens carries none of it. (Under the `.git` common-dir root, or a root outside the repository, nothing here is pushed either way; filing first is simply always correct.)

Ensure everything intended is committed (fixed files by name; the version/changelog commit if Step 6 ran; the to-do-list files the sweep just wrote, by name, when the to-do-list root sits inside the working tree). Push the branch: `git push -u origin HEAD`.
<!-- pln:only codex -->

The commits, the push and the `gh`/`glab` calls are the orchestrator's own work — a spawned agent has no network and no writable `.git`, so handing any of this to one produces a silent no-op. If the host asks you to approve a command that leaves the sandbox, ask the user for it rather than routing around it.
<!-- pln:endonly -->

Then assemble the PR body: what the branch does, then what's relevant to a reviewer — the final gauntlet result and the genuine follow-ups (Style's "Ending a message" bar), each one line. Drop the rest: a finding that got fixed needs no summary (the commit that fixed it is the record), and there is no "N findings, all fixed" tally. This is the same follow-up list the closing message uses — don't maintain a second one. Every `pre-existing` finding in `REVIEW.md` is on that list, marked as already on the base, and every `out-of-range` finding, marked as outside the range its post-fix round read: each was filed when its merge was published, so the sweep lists it and never files it again.

Every `deferred` finding goes under a heading of its own instead of on that list: one line each, naming the owner constraint that ruled out every repair, quoted, or naming the consequential repair of a test-only finding. Production-reachable findings are not deferred merely because their repair adds state or an effect; the two-notice window in the blocker phase handles those. Each deferred finding was filed when its cluster checkpointed, so the sweep never files it again. The PR's draft/ready state does not change for it.

Every `accepted` finding goes under a heading of its own too: one line each, naming the consequence the user accepted in the plan and the basis it was accepted on — the basis clause the ledger quotes, or `no basis recorded`. It is disclosed, not outstanding work: the sweep never files it, and the PR's draft/ready state does not change for it.

One more section, when the branch came from a `{{PLN_CMD}}` run whose `PLAN.md` carries a non-empty Reversals list: render those lines under their own heading, one each, saying what the branch overturns and where it was originally decided. A decision that reverses something already settled is the part of a branch a reviewer most needs to see, and `{{PLN_CMD}}`'s delegated mode can adopt a plan the user never read.

**Interpolate safely — never inline refs or the body into a shell command.** The base, branch, title, and PR body can all carry shell metacharacters (`$()`, backticks, quotes); a generated body assembled from findings especially so. Bind the refs to quoted shell variables, and write the body to a temp file passed by path — do not splice `<body>` into the command line:

```bash
BASE="<base>"; BRANCH="<branch>"; TITLE="<title>"
BODY_FILE=$(mktemp)
# write the assembled PR body into "$BODY_FILE" (a heredoc, or your host's file-writing tool), then:
```

Now perform best-effort simplification-marker propagation. Run `"$_PLN_DIR/bin/pln-simplify" propagate --repo . --head HEAD --body "$BODY_FILE"`. The helper scans reachable local commit messages, strictly selects the V1 winner, requires its content fingerprint to prove the resolved HEAD, removes prior marker copies, and appends the exact selected line once; exit 3 means omit it without failing shipping. PR/MR descriptions are a redundant preservation route only and never cadence input.

An intervening mutation normally invalidates propagation. The only exception is a repository-rule-driven release-metadata-only delta proven at exact hunk/field granularity: reverse just those declared mechanical version/changelog field edits in a temporary index/tree, recompute the same canonical content fingerprint, and require it to match the selected marker. Never exclude a whole mixed-purpose file, accept an arbitrary path, or treat a similar diff as proof. If that narrow proof cannot be constructed, omit the marker. When this run used a simplification freshness bypass, append a separate one-line disclosure naming the reason; never alter the marker line.

Read the durable `PR disposition`; do not derive it again from `pr_draft`. `ready` creates a ready PR and never enters mandatory CI watch. `keep-draft` and `policy-draft` create with `--draft` and enter Step 9; only a user's explicit draft request or a knowingly selected standing policy can set them. A plain put-up/open/create request, including `review=none` or “skip review,” is `ready` regardless of the default-on legacy config value.

Detect whether a PR already exists for this branch and **update instead of recreate** — re-running pln-pr on a branch that already has an open PR should refresh it, not error or open a duplicate. This check also decides whether Step 9 applies: **an update to an already-open PR never touches its draft/ready state**, no matter what `pr_draft` says — only a PR this run itself creates goes through the draft/watch/undraft cycle.

- GitHub: `gh pr view "$BRANCH" --json number` succeeds → a PR exists (`IS_NEW_PR=false`). Update it: `gh pr edit "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"` (the push above already updated its commits; its draft/ready state is untouched). Otherwise (`IS_NEW_PR=true`) create: `gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"`, adding `--draft` only for `keep-draft` or `policy-draft`.
- GitLab: `glab mr view "$BRANCH"` succeeds → update (`IS_NEW_PR=false`): `glab mr update "$BRANCH" --title "$TITLE" --description "$(cat "$BODY_FILE")"`. Otherwise (`IS_NEW_PR=true`) create: `glab mr create --target-branch "$BASE" --source-branch "$BRANCH" --title "$TITLE" --description "$(cat "$BODY_FILE")"`, adding `--draft` only for `keep-draft` or `policy-draft`.
- Unknown host: print the branch is pushed and give the compare URL if derivable; you cannot open the PR, so nothing below applies.

Clean up: `rm -f "$BODY_FILE"`.

At terminal completion or deliberate stop, consume any recorded simplification freshness bypass so a later invocation on the same candidate must receive a new explicit reason.

**Only fire the completion notification and hand the PR to the user here if Step 9 will not run** — i.e. `IS_NEW_PR=false`, disposition is `ready`, or the host is unknown. In that case, fire it now ({{NOTIFY_CALL}}), then close with the PR URL and a one-line summary — the complete answer on its own, no pointer to `REVIEW.md`. When `REVIEW.md` holds any `deferred` or `accepted` finding, the message's one closing line is `HEADS-UP:` naming them — deferred ones as repairs left for the user and filed, accepted ones as failures the plan accepted and this PR ships; the deferred ones' to-do lines are left out of the follow-up bullets, and a new ready PR's CI-watch offer below becomes a sentence in the message instead of a closing line. A new ready PR offers optional CI watching but never starts it unprompted. Its follow-up bullets are rendered from `{{OUTPUT_ROOT}}/bin/pln-todo list` — the lines the filing above printed back, found in that index — never re-typed from the PR body, which is one of the copies. The to-do-location flow (Follow-ups, below) runs as part of drafting that message, not after it.
<!-- pln:only claude -->
Optionally offer to watch CI (`gh pr checks --watch` via a background command or the Monitor tool) — only if the user wants it; don't start it unprompted.
<!-- pln:endonly -->
<!-- pln:only codex -->
Optionally offer to watch CI (`gh pr checks --watch`, backgrounded) — only if the user wants it; don't start it unprompted.
<!-- pln:endonly -->

Otherwise (`IS_NEW_PR=true`, an explicit draft disposition, host known) say the PR opened as a draft and continue straight to Step 9. When the disposition is `keep-draft`, say in the same line that it will stay a draft for the user to look at.

### Step 9. Watch CI, undraft on green, fix-and-rewatch on red

This step only runs right after Step 8 created a **brand-new explicitly selected** draft PR (`IS_NEW_PR=true`, disposition `keep-draft` or `policy-draft`, host known). Nothing here applies to an update to an already-open PR, a plain ready disposition, or an unknown host — Step 8 already covered those.

**`keep-draft` changes one thing here: the PR is never marked ready.** Read the disposition from `REVIEW.md` rather than from what the conversation remembers. Everything else in this step is unchanged — the watch, the classification, the fix-and-rewatch loop, the recorded CI duration, the notification, the closing message — and every `gh pr ready` (`glab mr update --ready`) below is skipped. Say in the closing message that the PR is left in draft and that marking it ready is the user's call, so an unfamiliar reader does not read the draft state as an unfinished run.

**Not mergeable — leave it in draft.** Ask the forge whether the PR can merge before reading its check list at all: `gh pr view "$BRANCH" --json mergeable,mergeStateStatus` (`glab mr view "$BRANCH"` reports the equivalent). `MERGEABLE` continues. So does `UNKNOWN` — the forge computes mergeability lazily and reports `UNKNOWN` for a PR opened seconds ago, so re-ask once at the first watch interval and continue either way rather than blocking the run on a field that may never resolve. Only a definite `CONFLICTING` stops: leave the PR in draft, fire the notification channels, and tell the user in one line that the branch conflicts with `<base>` and that resolving it is theirs. This run does not rebase — it has already pushed, and rewriting the branch under a PR that is now open is not a thing to do unasked.

That question comes first because the rule immediately below reads an empty check list as "there was never any CI here". A PR that cannot merge may report no checks for an entirely different reason — the forge runs them against a merge commit it cannot construct — and from the list alone the two are identical. Reaching that rule with a conflicting PR would mark it ready and hand it over as finished work.

**No CI configured — undraft immediately.** Check whether the repo reports any checks at all for this PR/MR (`gh pr checks "$BRANCH"`; `glab mr` equivalent). If it reports none — nothing was ever going to turn green — run `gh pr ready` (`glab mr update --ready` equivalent) right away, fire the completion notification ({{NOTIFY_CALL}}) noting there was no CI to wait on, hand the user the PR URL, and stop. Do not enter the watch loop for a repo with no CI. Under `keep-draft`, do the same minus the `gh pr ready`.

**"Green" means required checks if any exist, else all checks.** `gh pr checks "$BRANCH" --required` reports the subset marked required; if the repo has none marked required, fall back to plain `gh pr checks "$BRANCH"` and require all of those to pass instead — this is the same distinction the command ships for. A required check that fails is what drives the fix-and-rewatch loop below; a failing *optional* check when required checks exist is a follow-up, not a blocker, if it clears the follow-up bar (Style's "Ending a message"). The PR body was already assembled at Step 8, so this can't be folded back into it — post it as a PR comment (or a body edit, if the host makes that easy) once found. The comment is a copy: it reaches the closing message the way every other follow-up does, by being filed (Follow-ups, below) before that message is drafted.

**The adaptive poll interval.** Keep a small per-repo state value — this is operational telemetry (how long does this repo's CI usually take), not the kind of durable fact the cross-session memory system is for, so it lives beside the rest of pln's local state: `"$_PLN_DIR/bin/pln-config" get "ci_duration_$REPO_SLUG"`, where `REPO_SLUG` is the `owner-repo` form of `git remote get-url origin` (slashes and colons folded to `-`). If a prior duration `D` (seconds) is on record: wait roughly `D * 0.5` before the first check (no point polling before CI is usually even half done), then poll every `max(20, D * 0.1)` seconds (capped around 2 minutes) as the expected finish nears. With no history at all, fall back to a sane fixed default — wait ~4 minutes before the first check, then poll every 60–90 seconds. Once a round reaches green, record how long *that* round's CI actually took: `"$_PLN_DIR/bin/pln-config" set "ci_duration_$REPO_SLUG" "$ELAPSED"` — so the next run on this repo, in this run or a future one, starts smarter.

<!-- pln:include pr-watch-dispatch -->

**On green:** undraft (`gh pr ready`; `glab mr update --ready` equivalent — skipped entirely under `keep-draft`), record the observed duration as above, fire the completion notification ({{NOTIFY_CALL}}), and close with the PR URL and a one-line summary, same as Step 8's own completion message would have — its follow-up bullets rendered from `{{OUTPUT_ROOT}}/bin/pln-todo list` after this close has filed its own candidates, the ones this watch loop turned up included, and the to-do-location flow (Follow-ups, below) run while that message is drafted.

**Anything this close files is on this machine only, and the closing message must say so where the user cannot miss it.** Step 8 files ahead of its push so the branch carries what it filed; this close cannot, because it runs after the PR is already open and, on the green path, already marked ready — a commit pushed here restarts CI on a PR a reviewer has just been told is theirs to look at. So when the to-do-list root sits inside the working tree, the items filed *here* are uncommitted local changes and the pushed branch does not carry them. Say it in the closing message as its own line, not folded into a follow-up bullet: name the files, say they are not on the branch, and give the commit and push as one command the user can run. It is a statement and never a question — this close is reached by unattended runs, and nothing here waits for an answer. Under the `.git` common-dir root, or a root outside the repository, none of this applies and none of it is said: nothing there was ever going to be pushed. The condition is narrow — a tracked in-tree to-do list, a brand-new draft PR, and a watch that actually turned something up — which is why it is stated rather than engineered around.

**On a red required check:** capture logs file-first and have a fresh judgment worker classify the failure before editing: `infrastructure`, `flaky`, `permission`, or `code`. Infrastructure/flaky/permission failures do not authorize code changes; record evidence and retry/wait/escalate as appropriate. A code failure becomes a verified finding and a new candidate. Dispatch exactly one fresh CI fix cluster with its own `fix-ci-<round>-manifest.tsv`; never reuse a pre-PR worker or manifest. Its brief says it is a CI fix cluster; a consequential repair takes the same two-notice window as any production-reachable finding. If every repair contravenes an explicit owner constraint, that conflict needs an explicit answer and the timer cannot authorize the CI fix.

After a CI code fix, recompute risk and candidate fingerprints, invalidate the earlier review/gauntlet, run the applicable fresh review/post-fix assurance on the changed candidate, and run **the static checks** before pushing. Push only the reverified candidate and re-enter the watch loop.

The behavior suite does not re-run here; the two whole-suite justifications above still stand and nothing else does. Where the fix touched a specific test or an uncovered path, run that test and only that test. Measured on a real run before this rule existed: one CI round going red made a three-file branch re-run its project's full suite four more times, `pnpm lint` ten times, over eighteen minutes of a forty-two-minute "CI watch" that was barely watching CI.

The old bar here was "not exactly subsumed by the required CI checks", where exact subsumption meant the same command, inputs and relevant environment. That never fired: CI runs in a container on a clean checkout, so a local command is never *exactly* the same environment, so everything always re-ran. A guard that cannot be satisfied is not a guard.

Log each round's classification, evidence state, changed fingerprint, local commands, fresh reader attribution, and commit. Retain the same-check three-round stop provisionally.

**Truly stumped — stop, don't loop forever.** Track, per failing check name, how many consecutive rounds it has gone fix-then-still-red. Stop the loop — do not dispatch another fix cluster — the moment either holds: the **same** check has now failed **three rounds in a row**, or a fix cluster's own return is a `BLOCKED:` (it could not identify a concrete fix, the same shape Step 4's fix agents already use). When that happens, leave the PR in draft, fire the notification channels first, then surface the blocker to the user in the same shape as Step 4's needs-a-decision path — one question, as prose, in the option-message shape — naming the check, how many rounds were tried, and what each round's fix cluster attempted. State that in the question itself; do not point at the CI watch log in `REVIEW.md` for it. Nothing here has an upper bound on *how many* rounds run before that point; only the three-in-a-row (or one-explicitly-stuck) condition ends it.

## Follow-ups

All of this runs at whichever close hands the PR to the user — Step 8's or Step 9's — and the order is fixed: sweep, file, then draft. Which candidates the user sees is Style's "Ending a message" bar; every one that clears it is in the to-do list before the closing message is written, the ones Step 9's watch turns up included. The same close closes the to-do list out: every id this run claimed — including the ones a `{{PLN_CMD}}` run declared in its plan's `## To-do items` section and handed over marked — is marked from what landed, and every one standing at `[x]` with the PR's required checks green is archived `--disposition completed` here, with the PR and that green as the evidence. That archive is this close's own action, not a question and not something to hold for the merge; a PR that is red, stuck or blocked archives nothing. A repository that reports no checks at all has no green to wait for, and the open PR is the whole evidence there. Every id still held by this run once that is done is released — `{{OUTPUT_ROOT}}/bin/pln-todo release --id <id> --run <the run that holds it>` — including the ones a red, stuck or blocked PR archived nothing for: this run has stopped either way, and a claim it leaves standing refuses the next run to want those files on behalf of a writer that is no longer writing. Releasing changes nothing about the item but who is on it, so an unarchived item keeps the state it earned and goes back to being work anyone can pick up. `pln-todo stale`'s candidates are different and unchanged: they are named for the user to confirm, never archived on the run's own reading of a merged commit. This run may be a standalone `{{PLN_PR_CMD}}` with no `PLAN.md` and no `{{PLN_CMD}}` step behind it: the helper resolves the to-do list itself on every call, so nothing here waits on one having run.

<!-- pln:include outstanding-sweep -->

<!-- pln:include todo-location -->
<!-- pln:include todo-destination -->
<!-- pln:include todo-format -->

## Failure modes to watch for

- **Re-running the gauntlet after each fix cluster.** This is the exact thrash pln-pr exists to prevent. Fixes accumulate; the mandatory run happens once at Step 7 (plus the optional Step 2 baseline).
- **Treating a failed review as a clean one.** If no reviewer succeeds, that is zero coverage, not zero findings. Fail closed and stop — never write an empty ledger and open the PR.
- **The orchestrator fixing findings itself.** It dispatches fix agents; it does not read code or edit files. If you catch yourself editing in the orchestrator, stop and spawn the cluster.
- **Acting on unverified findings.** A finding with no `motivating_code` is a suspicion, not a bug. It stays in the appendix and is not fixed.
- **Fix agents colliding on a file.** The scheduler adds dependency edges for every overlap or shared effect and serializes unknowns, and clusters run one at a time in the working tree the run was launched in. The coordinator alone commits/integrates explicit leased paths and never includes bytes from a blocked cluster.
- **Splicing refs or the PR body into a shell command.** Bind refs to quoted vars and pass the body by file (`--body-file` / `--description` from a temp file). Never inline `<body>`.
- **Imposing a version bump on a repo that has no stated convention.** Step 6 is conditional. No stated version-bump rule found anywhere (`CLAUDE.md`/`AGENTS.md` or the `VERSION`/`CHANGELOG.md` shape), no bump — and if the branch already bumped, don't bump again.
- **Looking for gstack.** pln-pr is self-contained. It never reads gstack checklists, calls gstack binaries, or assumes gstack is installed.
- **Looping the fix-and-rewatch cycle without ever reaching the stumped threshold.** "Unbounded" (Step 9) means no cap on *rounds*, not a license to keep dispatching fix clusters at the same red check forever. Track the same-check streak; three in a row (or one fix cluster returning `BLOCKED:`) means stop and surface the blocker, even if the underlying check has never been seen before that streak started.
- **Letting a default convert a ready request into a draft hold.** A plain PR request is ready after local verification, including the exact `review=none` late-skip shape. Draft/watch requires an explicit draft disposition.
- **Re-drafting a PR a human is already reviewing.** Step 9's undraft/watch cycle only ever applies to a PR this same run just created (`IS_NEW_PR=true`). An update to a branch's existing PR never touches its draft/ready state either way — not `gh pr ready` on green, not anything else — because a reviewer may already be looking at it.
<!-- pln:only claude -->
- **`PushNotification` never loaded, so the call silently does nothing.** It is a deferred tool; the Notification-setup preamble must have run `ToolSearch (select:PushNotification)` and `notify_push` must not be `false`. If a push is reported missing, check that first.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Reading a spawned agent's exit code as its result.** A `codex exec` call can exit 0 having written nothing; an empty output file is a failed reviewer, not a reviewer that found nothing. That distinction is what the fail-closed gate in Step 3.1 rests on.
- **Reading a transcript into your own context.** `codex review`, CI logs, reviewer output, and spawn event streams stay in artifacts. Read fixed metadata or validated bounded envelopes only; keeping raw material out is why the work is spawned.
- **Delegating a commit, a push, or `gh pr create` to a spawned agent.** It is sandboxed: no network, no writable `.git`. Those are the orchestrator's calls, at every step.
- **Applying the nested-CLI OAuth race to native agents.** Native Codex agents are in-session workers, so readers can run side by side; fix workers still run one at a time because they share one working tree. Only fallback `codex` processes share the login race and must remain serial; any native serialization needs its own dependency or review-coverage reason.
<!-- pln:endonly -->
