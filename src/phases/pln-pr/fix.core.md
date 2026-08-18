---
name: pln-pr-phase-fix
---

# /pln-pr phase: fix

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first fix decision or dispatch. Rebuild open clusters from `REVIEW.md`, not memory. Keep the cursor here while fixes and their narrow verification/checkpoints complete.

Before asking a decision or handing off a blocked cluster, write it and all partial-state pointers durably, then set `Phase: blocker` and load that phase. Once every finding is durably fixed/skipped and the post-fix result is recorded, set `Phase: ship-watch` and load that phase before versioning, the final gauntlet, push, PR, or CI work.

<!-- pln:include assurance-policy -->

### Step 4. Fix pass — clustered fix subagents

Classify each acted-on finding as **auto-fix** (mechanical, unambiguous — a null check, a missing timeout, a spec for uncovered behavior) or **needs-a-decision** (a judgment call — a design change, a tradeoff, anything where the fix isn't obvious or is destructive).

A structural consolidation uses the same routes. The single behavior-preservation owner is `{{SKILL_DIR}}/src/workers/behavior-preservation.md`; every fix worker handling a removal, replacement, or consolidation reads and applies it before editing. Automatic deletion still requires private reachability, bounded consumer closure, and repository-native discovery, but those facts do not replace repository-native pre-change characterization and post-change comparison through direct/indirect consumers at the externally observable boundary. Public, compatibility, persisted/stateful, consequential, or uncertain effects retain the surface or become destructive/needs-a-decision. No similarity score, raw-growth threshold, deletion target, or cleanup quota can authorize a simplifying mutation.

For needs-a-decision findings, surface them to the user **one at a time**, as prose, in the option-message shape, fire notifications first. Record each answer in `REVIEW.md` against its finding. A skipped finding is marked `skipped`; it becomes a follow-up in the closing message's bullet list only if it clears the follow-up bar (Style's "Ending a message") — someone will actually need to act on it or decide about it later. A skip that was really "not worth doing" gets no follow-up entry.

Before dispatch, snapshot the source tree and send the resolved cluster list to a fresh `judgment`-profile worker on `{{SKILL_DIR}}/src/workers/execution-schedule.md` in `pr-fix-clusters` mode. Validate its envelope and build `<plan-dir>/fix-manifest.tsv` with `bin/pln-scheduler`. Every cluster remains a fresh-worker node; cohorts/context reuse are forbidden. Dependencies, overlapping/ancestor leases, generators, lockfiles, tests, configuration, migrations, and shared effects add edges; unknown means serial. Parallelize only one manifest wave of isolated, pairwise-disjoint clusters. `REVIEW.md`, the manifest, git checkpoints, and integration are coordinator-only. Auto mode never applies to `/pln-pr`.

<!-- pln:include pr-fix-dispatch -->

1. "Read `REVIEW.md` at `<path>`. Your spec is the findings in cluster {K}, listed below. Fix each one to the project's quality bar.
2. Follow any mandated skills or conventions noted in `PLAN.md`'s pre-flight findings (BDD, package manager, where commands run) — you are fresh context, re-establish them yourself.
3. Where a finding has a `test_stub` or is about missing coverage, write the failing spec first, then make it pass. Hold any new test to this bar:
   - Test the path the code actually runs, not just its inputs — assert on what crosses a mocked boundary rather than only on the boundary itself. If the boundary (e.g. an external gateway) stays mocked, say so in the report.
   - Before fixing anything, run the new test and paste the actual failure message. Not "it failed."
   - After fixing, report the exact command run and the count it printed (e.g. `pnpm uspec spec/unit/foo → 4 tests, 4 passed`) — not a raw paste of passing output, which is noise. Someone can re-run that exact command to check it.
   - If a test's result could change depending on the time of day or date, say so and account for it.
   - Before reporting verification, re-read the project's completion rule (`CLAUDE.md`/`AGENTS.md`) and reproduce any environmental condition it names — cleared credentials, a specific timezone, a service, a clean database — that this run didn't already match.
4. Run lightweight verification only (type-check + lint on touched files, not the full suite). Fix on failure — nothing here is staged, since `git` writes are not yours to make.
   For a structural finding, also run its repeatable structural reference check and remap its direct and indirect consumers. For an authorized removal, replacement, or consolidation, preserve the exact repository-native discovery commands, pre-change characterization, post-change output, and comparison required by `{{SKILL_DIR}}/src/workers/behavior-preservation.md` so the merge/verifier can prove both consumer closure and retained behavior.
<!-- pln:only claude -->
5. Do not commit — the coordinator owns the cluster checkpoint and integration. Edit only the assigned isolated worktree and leased paths, then name them in your final message.
6. Do not edit `REVIEW.md` — it is a shared checkpoint file and concurrent writes would race even when code leases are disjoint. Say in your final message which findings the cluster cleared; the orchestrator updates their statuses and commit hashes after it checkpoints the cluster."
<!-- pln:endonly -->
<!-- pln:only codex -->
5. Do not commit — `.git` is read-only to you. Edit only the assigned worktree and leased paths, then name them in your final message.
6. Do not edit `REVIEW.md` or the fix manifest. Say in your final message which findings the cluster cleared; the coordinator records the validated checkpoint."
<!-- pln:endonly -->

<!-- pln:include pr-fix-invoke -->

### Step 5. Post-fix assurance

Every fix creates a new candidate; recompute its exact fingerprint before assurance. R1 narrowly verifies the finding and targeted tests. R2 runs one fresh post-fix verifier across the fixes and specialist risks. R3 runs a full fresh red-team pass after nontrivial fixes; this is separate from the four-reader pre-fix cap. A trivial R3 fix still gets a fresh verifier plus explicit evidence for why a full red team was unnecessary.

At the repair's semantic risk tier, every post-fix path must rerun the structural reference check and consumer map (including direct and indirect consumers) for each structural finding and compare the recorded before/after owners, paths, and knobs. For a removal, replacement, or consolidation, it also rechecks repository-native discovery, bounded closure, and the post-change behavior against the recorded pre-change characterization under `{{SKILL_DIR}}/src/workers/behavior-preservation.md`; deletion additionally rechecks private reachability. Missing or changed proof reopens the same structural repair key and fails closed; do not treat passing post-change tests alone as structural assurance.

The R3 red team writes complete findings to `<plan-dir>/evidence/post-fix-red-team.json` and returns only that pointer. Give it the verified findings/fixes and exact candidate fingerprint:

"Read the exact post-fix candidate. Reproduce the listed fixes and hunt for missed cross-cutting failures or regressions. Write only findings with exact citations and runnable reproduction/test evidence; label unsupported suspicions unverified. Return only the assigned `RESULT_FILE` pointer."

Never open that reviewer output inline. Give its artifact and the exact post-fix fingerprint to a fresh judgment merge/verifier, which updates `REVIEW.md` and returns a bounded envelope. One malformed retry, then fail closed.

- If the red team confirms and finds nothing blocking: record its non-blocking notes in `REVIEW.md`. Only the ones that clear the follow-up bar (Style's "Ending a message") reach the closing message's bullet list and the PR body; the rest stay internal.
- If it surfaces a verified actionable finding: add or reopen it in `REVIEW.md` and apply the progress protocol below. Do not ask whether to begin another repair round.

**Repair progress, not a global round cap.** Adoption of `PR after implementation`, or direct invocation of `/pln-pr`, is standing authority to repair every verified, unambiguous, in-scope finding until assurance is clean and the PR is green. A new repair round is already-authorized repair work, not a new permission boundary. Global round count never blocks it.

The merge worker assigns each verified actionable finding a stable **repair key**. Behavioral keys use the affected boundary and runnable reproduction or named failing test. Structural keys use `bin/pln-assurance repair-key --kind structural` with the responsibility/invariant, established owner, and repeatable reference check or reproduction. Never key a defect by round number, finding title, or `file:line` alone, and never rewrite an existing ledger key. Preserve these fields in `REVIEW.md`: repair key, failed repair attempts, last repair candidate, and last repair outcome.

For each open finding, run `bin/pln-assurance repair-action --disposition <value> --failed-attempts <n>`:

- Use `new` with zero attempts for a repair key not previously acted on. A different verified reproduction is a new finding, even when it appears in a later assurance round.
- Use `persisted` after an attempted fix leaves the same behavioral reproduction failing; increment its failed-attempt count against the candidate just tested. Fewer than three consecutive failed repair attempts returns to Step 4 with a fresh fix worker. A successful narrow reproduction resets the defect's consecutive-failure count; a later different failure gets its own key.
- Use `needs-decision`, `out-of-scope`, or `destructive` only for a genuine user-owned boundary, and `worker-blocked` only when the repair worker returned a durable blocker rather than an incomplete or failed result.

On `ACTION=repair`, rebuild the affected clusters from the ledger, run Step 4 with fresh workers, checkpoint the candidate, and repeat the assurance appropriate to the risk. On `ACTION=block`, persist `Phase: blocker`, the reason, exact candidate, and partial-state pointers before asking the one question the blocker actually requires. For `same-defect-stuck`, name the three failed candidates and why the identical reproduction survived. Do not run the full project gauntlet during these cycles; Step 7 runs it once after assurance is clean.
