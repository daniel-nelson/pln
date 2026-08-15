---
name: pln-pr-phase-fix
---

# /pln-pr phase: fix

Read this file in full before the first fix decision or dispatch. Rebuild open clusters from `REVIEW.md`, not memory. Keep the cursor here while fixes and their narrow verification/checkpoints complete.

Before asking a decision or handing off a blocked cluster, write it and all partial-state pointers durably, then set `Phase: blocker` and load that phase. Once every finding is durably fixed/skipped and the post-fix result is recorded, set `Phase: ship-watch` and load that phase before versioning, the final gauntlet, push, PR, or CI work.

### Step 4. Fix pass — clustered fix subagents

Classify each acted-on finding as **auto-fix** (mechanical, unambiguous — a null check, a missing timeout, a spec for uncovered behavior) or **needs-a-decision** (a judgment call — a design change, a tradeoff, anything where the fix isn't obvious or is destructive).

For needs-a-decision findings, surface them to the user **one at a time**, as prose, in the option-message shape, fire notifications first. Record each answer in `REVIEW.md` against its finding. A skipped finding is marked `skipped`; it becomes a follow-up in the closing message's bullet list only if it clears the follow-up bar (Style's "Ending a message") — someone will actually need to act on it or decide about it later. A skip that was really "not worth doing" gets no follow-up entry.

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
<!-- pln:only claude -->
5. Do not commit — clusters run in parallel and share this working tree, so a commit from you here could race another cluster's. Leave the fixed files in the tree and name them in your final message; the orchestrator commits the cluster.
6. Do not edit `REVIEW.md` — it is a shared checkpoint file and concurrent writes would race even when code leases are disjoint. Say in your final message which findings the cluster cleared; the orchestrator updates their statuses and commit hashes after it checkpoints the cluster."
<!-- pln:endonly -->
<!-- pln:only codex -->
5. Do not commit — `.git` is read-only to you. Leave the fixed files in the tree and name them in your final message; the orchestrator commits the cluster.
6. Update each finding's status in `REVIEW.md` to `fixed` before returning, and say in your final message which findings the cluster cleared."
<!-- pln:endonly -->

<!-- pln:include pr-fix-invoke -->

### Step 5. Red team — verify the fixes

After the fix pass, dispatch one red-team judgment agent against the **post-fix** diff. It writes complete findings to `<plan-dir>/evidence/post-fix-red-team.json` and returns only that pointer. Give it the list of what was already found and fixed, and tell it its job is to find what the reviewers missed and confirm the fixes:

"The diff has already been reviewed and fixed. Read the current diff (`DIFF_BASE=$(git merge-base origin/<base> HEAD) && git diff \"$DIFF_BASE\"`). Verify the listed fixes and hunt for missed cross-cutting failures or regressions. Write only real, line-quoted findings plus the recommendation to the assigned artifact; return only its `RESULT_FILE` pointer."

Never open that reviewer output inline. Give its artifact and the exact post-fix fingerprint to a fresh judgment merge/verifier, which updates `REVIEW.md` and returns a bounded envelope. One malformed retry, then fail closed.

- If the red team confirms and finds nothing blocking: record its non-blocking notes in `REVIEW.md`. Only the ones that clear the follow-up bar (Style's "Ending a message") reach the closing message's bullet list and the PR body; the rest stay internal.
- If it surfaces a new blocking finding: add it to `REVIEW.md` and run **one** more fix cluster (Step 4's mechanism) to clear it, then continue. Do not loop indefinitely — a second blocking round means stop and hand the situation to the user.
