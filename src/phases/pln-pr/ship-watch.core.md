---
name: pln-pr-phase-ship-watch
---

# /pln-pr phase: ship and watch

<!-- pln:include active-turn-lifecycle -->

Read this file in full before version/changelog, final-gauntlet, push, PR, or CI actions. Reconcile the stored tree fingerprint, command/environment fingerprint, PR identity, and CI round before reusing results or repeating an external action. Conflicts or uncertain external completion fail closed.

Write new tree/command/environment/candidate fingerprints after every fix, version, command, environment, or CI edit and invalidate stale verification. Persist the final gauntlet before push; persist PR identity immediately after create/update; persist every CI round and outcome before another fix/watch cycle. After terminal green/merge-ready status or the user's deliberate stop is durable, set `Phase: complete`.

<!-- pln:include assurance-policy -->

### Step 6. Version and changelog (conditional — before the gauntlet)

This runs *before* the final gauntlet so the release files are verified by it, not after. Read the repo's `CLAUDE.md`/`AGENTS.md` first for a stated version-bump rule and follow it, whatever file(s) it names. Treat `VERSION`/`CHANGELOG.md` as one common shape of that convention, not the definition of "this repo has a version" — a repo that states its own rule around different files still gets a bump; a repo with no stated rule and no `VERSION` file and no `CHANGELOG.md` gets skipped entirely. If neither the stated rule nor the `VERSION`/`CHANGELOG.md` shape applies, skip this step entirely; most repos don't use either and pln-pr must not impose one.

**Skip the bump if the branch already carries one.** A retry, or a branch that bumped its own version as part of the work, must not bump again. Compare the branch's version file against the base — `<base>` here is whatever Step 0 resolved (the stacked-PR override when one was given, the repo default otherwise), so the "already bumped" check compares against the actual PR base, never silently against the repo default when an override is in play:

```bash
git show "origin/<base>:VERSION" 2>/dev/null
```

If that base value differs from the working-tree version (the branch is already ahead), the bump is done — do not touch the version file(s), just note "version already bumped (X → Y)" and continue. Only when the branch's version still matches the base do you bump.

When you do bump: raise the version per the repo's scheme (read recent changelog entries to infer major/minor/patch conventions) and add a matching changelog entry describing what shipped. If the repo's `CLAUDE.md`/`AGENTS.md` states a bump rule, follow it over the `VERSION`/`CHANGELOG.md` default. Commit these with the co-author trailer, so they are part of the tree the Step 7 gauntlet runs against.

### Step 7. Final gauntlet — once

Write the ordered commands and normalized non-secret environment to artifacts, compute the exact candidate fingerprint, then spawn one fresh-context agent to run the full gauntlet on that candidate—including version/changelog changes. Recompute afterward; any mismatch fails. Record pass/fail per command plus tree/command/environment/candidate hashes in `REVIEW.md`. This is the mandatory post-fix run; the only other full-suite run is the optional baseline. Confirm untrusted commands first.
<!-- pln:only codex -->
Same spawn shape and the same sandbox caveat as Step 2.
<!-- pln:endonly -->

If it fails: the branch does not ship. Surface the failure and stop (or spawn one fix agent if the fix is obvious and in-scope, then this single gauntlet re-runs — not the whole flow).

### Step 8. Commit, push, and open (or update) the PR

Ensure everything intended is committed (fixed files by name; the version/changelog commit if Step 6 ran). Push the branch: `git push -u origin HEAD`.
<!-- pln:only codex -->

The commits, the push and the `gh`/`glab` calls are the orchestrator's own work — a spawned agent has no network and no writable `.git`, so handing any of this to one produces a silent no-op. If the host asks you to approve a command that leaves the sandbox, ask the user for it rather than routing around it.
<!-- pln:endonly -->

Sweep the run's own record for outstanding work first (Follow-ups, below) — this is where the follow-up list is assembled, and both closes below reuse it. Then assemble the PR body: what the branch does, then what's relevant to a reviewer — the final gauntlet result and the genuine follow-ups (Style's "Ending a message" bar), each one line. Drop the rest: a finding that got fixed needs no summary (the commit that fixed it is the record), and there is no "N findings, all fixed" tally. This is the same follow-up list the closing message uses — don't maintain a second one.

One more section, when the branch came from a `/pln` run whose `PLAN.md` carries a non-empty Reversals list: render those lines under their own heading, one each, saying what the branch overturns and where it was originally decided. A decision that reverses something already settled is the part of a branch a reviewer most needs to see, and `/pln`'s delegated mode can adopt a plan the user never read.

**Interpolate safely — never inline refs or the body into a shell command.** The base, branch, title, and PR body can all carry shell metacharacters (`$()`, backticks, quotes); a generated body assembled from findings especially so. Bind the refs to quoted shell variables, and write the body to a temp file passed by path — do not splice `<body>` into the command line:

```bash
BASE="<base>"; BRANCH="<branch>"; TITLE="<title>"
BODY_FILE=$(mktemp)
# write the assembled PR body into "$BODY_FILE" (a heredoc, or your host's file-writing tool), then:
```

Now perform best-effort simplification-marker propagation. Run `"$_PLN_DIR/bin/pln-simplify" propagate --repo . --head HEAD --body "$BODY_FILE"`. The helper scans reachable local commit messages, strictly selects the V1 winner, requires its content fingerprint to prove the resolved HEAD, removes prior marker copies, and appends the exact selected line once; exit 3 means omit it without failing shipping. PR/MR descriptions are a redundant preservation route only and never cadence input.

An intervening mutation normally invalidates propagation. The only exception is a repository-rule-driven release-metadata-only delta proven at exact hunk/field granularity: reverse just those declared mechanical version/changelog field edits in a temporary index/tree, recompute the same canonical content fingerprint, and require it to match the selected marker. Never exclude a whole mixed-purpose file, accept an arbitrary path, or treat a similar diff as proof. If that narrow proof cannot be constructed, omit the marker. When this run used a simplification freshness bypass, append a separate one-line disclosure naming the reason; never alter the marker line.

**Read `pr_draft` before creating anything:** `"$_PLN_DIR/bin/pln-config" get pr_draft`. Unless it prints `false`, draft mode is on (default on) — a brand-new PR opens as a draft and Step 9 below watches it. `pr_draft false` reverts Step 8 to opening straight to ready, and Step 9 does not run at all. The one exception is Step 0's `draft=keep`: it turns draft mode on for this run whatever `pr_draft` says, and Step 9 runs — it is the disposition that decides whether Step 9 ever marks the PR ready, not whether it runs.

Detect whether a PR already exists for this branch and **update instead of recreate** — re-running pln-pr on a branch that already has an open PR should refresh it, not error or open a duplicate. This check also decides whether Step 9 applies: **an update to an already-open PR never touches its draft/ready state**, no matter what `pr_draft` says — only a PR this run itself creates goes through the draft/watch/undraft cycle.

- GitHub: `gh pr view "$BRANCH" --json number` succeeds → a PR exists (`IS_NEW_PR=false`). Update it: `gh pr edit "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"` (the push above already updated its commits; its draft/ready state is untouched). Otherwise (`IS_NEW_PR=true`) create: `gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE"`, adding `--draft` when `pr_draft` is on.
- GitLab: `glab mr view "$BRANCH"` succeeds → update (`IS_NEW_PR=false`): `glab mr update "$BRANCH" --title "$TITLE" --description "$(cat "$BODY_FILE")"`. Otherwise (`IS_NEW_PR=true`) create: `glab mr create --target-branch "$BASE" --source-branch "$BRANCH" --title "$TITLE" --description "$(cat "$BODY_FILE")"`, adding `--draft` when `pr_draft` is on.
- Unknown host: print the branch is pushed and give the compare URL if derivable; you cannot open the PR, so nothing below applies.

Clean up: `rm -f "$BODY_FILE"`.

At terminal completion or deliberate stop, consume any recorded simplification freshness bypass so a later invocation on the same candidate must receive a new explicit reason.

**Only fire the completion notification and hand the PR to the user here if Step 9 will not run** — i.e. `IS_NEW_PR=false`, `pr_draft` is off, or the host is unknown. In that case, fire it now ({{NOTIFY_CALL}}), then close with the PR URL and a one-line summary — the complete answer on its own, no pointer to `REVIEW.md`. If any genuine follow-ups made it into the PR body above, list them again as the closing message's bullet list, then run the to-do-location flow (Follow-ups, below).
<!-- pln:only claude -->
Optionally offer to watch CI (`gh pr checks --watch` via a background command or the Monitor tool) — only if the user wants it; don't start it unprompted. (This is the `pr_draft false` path only — the default path watches unprompted, in Step 9.)
<!-- pln:endonly -->
<!-- pln:only codex -->
Optionally offer to watch CI (`gh pr checks --watch`, backgrounded) — only if the user wants it; don't start it unprompted. (This is the `pr_draft false` path only — the default path watches unprompted, in Step 9.)
<!-- pln:endonly -->

Otherwise (`IS_NEW_PR=true`, draft mode on, host known) say the PR opened as a draft and continue straight to Step 9 — no confirmation needed, this is the default behavior, not an offer. When the disposition is `keep-draft`, say in the same line that it will stay a draft for the user to look at.

### Step 9. Watch CI, undraft on green, fix-and-rewatch on red

This step only runs right after Step 8 created a **brand-new** draft PR (`IS_NEW_PR=true`, draft mode on, host known). Nothing here applies to an update to an already-open PR, to a `pr_draft false` run with no `draft=keep`, or to an unknown host — Step 8 already covered those.

**`keep-draft` changes one thing here: the PR is never marked ready.** Read the disposition from `REVIEW.md` rather than from what the conversation remembers. Everything else in this step is unchanged — the watch, the classification, the fix-and-rewatch loop, the recorded CI duration, the notification, the closing message — and every `gh pr ready` (`glab mr update --ready`) below is skipped. Say in the closing message that the PR is left in draft and that marking it ready is the user's call, so an unfamiliar reader does not read the draft state as an unfinished run.

**No CI configured — undraft immediately.** Check whether the repo reports any checks at all for this PR/MR (`gh pr checks "$BRANCH"`; `glab mr` equivalent). If it reports none — nothing was ever going to turn green — run `gh pr ready` (`glab mr update --ready` equivalent) right away, fire the completion notification ({{NOTIFY_CALL}}) noting there was no CI to wait on, hand the user the PR URL, and stop. Do not enter the watch loop for a repo with no CI. Under `keep-draft`, do the same minus the `gh pr ready`.

**"Green" means required checks if any exist, else all checks.** `gh pr checks "$BRANCH" --required` reports the subset marked required; if the repo has none marked required, fall back to plain `gh pr checks "$BRANCH"` and require all of those to pass instead — this is the same distinction the command ships for. A required check that fails is what drives the fix-and-rewatch loop below; a failing *optional* check when required checks exist is a follow-up, not a blocker, if it clears the follow-up bar (Style's "Ending a message"). The PR body was already assembled at Step 8, so this can't be folded back into it — post it as a PR comment (or a body edit, if the host makes that easy) once found, and carry it into the eventual closing message's bullet list.

**The adaptive poll interval.** Keep a small per-repo state value — this is operational telemetry (how long does this repo's CI usually take), not the kind of durable fact the cross-session memory system is for, so it lives beside the rest of pln's local state: `"$_PLN_DIR/bin/pln-config" get "ci_duration_$REPO_SLUG"`, where `REPO_SLUG` is the `owner-repo` form of `git remote get-url origin` (slashes and colons folded to `-`). If a prior duration `D` (seconds) is on record: wait roughly `D * 0.5` before the first check (no point polling before CI is usually even half done), then poll every `max(20, D * 0.1)` seconds (capped around 2 minutes) as the expected finish nears. With no history at all, fall back to a sane fixed default — wait ~4 minutes before the first check, then poll every 60–90 seconds. Once a round reaches green, record how long *that* round's CI actually took: `"$_PLN_DIR/bin/pln-config" set "ci_duration_$REPO_SLUG" "$ELAPSED"` — so the next run on this repo, in this run or a future one, starts smarter.

<!-- pln:include pr-watch-dispatch -->

**On green:** undraft (`gh pr ready`; `glab mr update --ready` equivalent — skipped entirely under `keep-draft`), record the observed duration as above, fire the completion notification ({{NOTIFY_CALL}}), and close with the PR URL and a one-line summary, same as Step 8's own completion message would have — including any genuine follow-ups (found during review or during this watch loop) as a closing bullet list, then the to-do-location flow (Follow-ups, below).

**On a red required check:** capture logs file-first and have a fresh judgment worker classify the failure before editing: `infrastructure`, `flaky`, `permission`, or `code`. Infrastructure/flaky/permission failures do not authorize code changes; record evidence and retry/wait/escalate as appropriate. A code failure becomes a verified finding and a new candidate. Dispatch exactly one fresh CI fix cluster with its own `fix-ci-<round>-manifest.tsv`; never reuse a pre-PR worker or manifest.

After a CI code fix, recompute risk and candidate fingerprints, invalidate the earlier review/gauntlet, run the applicable fresh review/post-fix assurance on the changed candidate, and run every local gauntlet command not exactly subsumed by the required CI checks before pushing. Exact subsumption means the same command, inputs, and relevant environment—not a similar check name. Push only the reverified candidate and re-enter the watch loop. Log each round's classification, evidence state, changed fingerprint, local commands, fresh reader attribution, and commit. Retain the same-check three-round stop provisionally.

**Truly stumped — stop, don't loop forever.** Track, per failing check name, how many consecutive rounds it has gone fix-then-still-red. Stop the loop — do not dispatch another fix cluster — the moment either holds: the **same** check has now failed **three rounds in a row**, or a fix cluster's own return is a `BLOCKED:` (it could not identify a concrete fix, the same shape Step 4's fix agents already use). When that happens, leave the PR in draft, fire the notification channels first, then surface the blocker to the user in the same shape as Step 4's needs-a-decision path — one question, as prose, in the option-message shape — naming the check, how many rounds were tried, and what each round's fix cluster attempted. State that in the question itself; do not point at the CI watch log in `REVIEW.md` for it. Nothing here has an upper bound on *how many* rounds run before that point; only the three-in-a-row (or one-explicitly-stuck) condition ends it.

## Follow-ups

Both halves run at whichever close hands the PR to the user — Step 8's or Step 9's: the sweep before that message is drafted, the recording flow after its bullet list. Which items belong on the list is Style's "Ending a message" bar; the flow is where the ones that do get recorded somewhere durable.

<!-- pln:include outstanding-sweep -->

<!-- pln:include todo-location -->

## Failure modes to watch for

- **Re-running the full gauntlet after each fix cluster.** This is the exact thrash pln-pr exists to prevent. Fixes accumulate; the mandatory gauntlet runs once at Step 7 (plus the optional Step 2 baseline).
- **Treating a failed review as a clean one.** If no reviewer succeeds, that is zero coverage, not zero findings. Fail closed and stop — never write an empty ledger and open the PR.
- **The orchestrator fixing findings itself.** It dispatches fix agents; it does not read code or edit files. If you catch yourself editing in the orchestrator, stop and spawn the cluster.
- **Acting on unverified findings.** A finding with no `motivating_code` is a suspicion, not a bug. It stays in the appendix and is not fixed.
- **Fix agents colliding on a file.** The scheduler adds dependency edges for every overlap or shared effect and serializes unknowns. Both hosts may launch only a manifest wave of isolated disjoint clusters. The coordinator alone commits/integrates explicit leased paths and never includes bytes from a blocked cluster.
- **Splicing refs or the PR body into a shell command.** Bind refs to quoted vars and pass the body by file (`--body-file` / `--description` from a temp file). Never inline `<body>`.
- **Imposing a version bump on a repo that has no stated convention.** Step 6 is conditional. No stated version-bump rule found anywhere (`CLAUDE.md`/`AGENTS.md` or the `VERSION`/`CHANGELOG.md` shape), no bump — and if the branch already bumped, don't bump again.
- **Looking for gstack.** pln-pr is self-contained. It never reads gstack checklists, calls gstack binaries, or assumes gstack is installed.
- **Looping the fix-and-rewatch cycle without ever reaching the stumped threshold.** "Unbounded" (Step 9) means no cap on *rounds*, not a license to keep dispatching fix clusters at the same red check forever. Track the same-check streak; three in a row (or one fix cluster returning `BLOCKED:`) means stop and surface the blocker, even if the underlying check has never been seen before that streak started.
- **Re-drafting a PR a human is already reviewing.** Step 9's undraft/watch cycle only ever applies to a PR this same run just created (`IS_NEW_PR=true`). An update to a branch's existing PR never touches its draft/ready state either way — not `gh pr ready` on green, not anything else — because a reviewer may already be looking at it.
<!-- pln:only claude -->
- **`PushNotification` never loaded, so the call silently does nothing.** It is a deferred tool; the Notification-setup preamble must have run `ToolSearch (select:PushNotification)` and `notify_push` must not be `false`. If a push is reported missing, check that first.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Reading a spawned agent's exit code as its result.** A `codex exec` call can exit 0 having written nothing; an empty output file is a failed reviewer, not a reviewer that found nothing. That distinction is what the fail-closed gate in Step 3.1 rests on.
- **Reading a transcript into your own context.** `codex review`, CI logs, reviewer output, and spawn event streams stay in artifacts. Read fixed metadata or validated bounded envelopes only; keeping raw material out is why the work is spawned.
- **Delegating a commit, a push, or `gh pr create` to a spawned agent.** It is sandboxed: no network, no writable `.git`. Those are the orchestrator's calls, at every step.
- **Applying the nested-CLI OAuth race to native agents.** Native Codex agents are in-session workers and can run concurrently when leases are disjoint. Only fallback `codex` processes share the login race and must remain serial; any native serialization needs its own dependency or review-coverage reason.
<!-- pln:endonly -->
