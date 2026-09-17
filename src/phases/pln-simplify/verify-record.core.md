---
name: pln-simplify-phase-verify-record
---

# /pln-simplify phase: verify and record

<!-- pln:include active-turn-lifecycle -->

Enter only after the existing `{{PLN_CMD}}` implementation phase has checkpointed every adopted simplification item. A `nothing worth changing` assessment enters here with no product commit. Reuse `{{OUTPUT_ROOT}}/src/workers/final-verification.md`, the shared assurance policy, and the plan's exact gauntlet; this phase adds only the unpublished marker candidate and success publication protocol.

<!-- pln:include assurance-policy -->

V1's one exact marker line is:

`PLN-SIMPLIFY-V1 completed=YYYY-MM-DDTHH:MM:SSZ content-sha256=<64 lowercase hex>`

The line is ASCII, starts in column one, has exactly the shown single spaces and field order, and has no leading/trailing whitespace. `completed` is canonical UTC. `content-sha256` comes from `bin/pln-simplify fingerprint`: SHA-256 over NUL-delimited records in Git's canonical recursive tree order, containing byte-length, path bytes, git mode/type, and the repository-native object ID for every entry in the committed content tree. Tracked files are included even if an ignore rule names them; untracked, ignored, generated-but-untracked files, commit identity, and commit messages are excluded. Recording requires a clean non-ignored tree, while the existing assurance fingerprint separately binds the full exact candidate and environment.

After ordinary checkpoints:

1. Record the supported branch and its exact HEAD. Require a clean non-ignored tree. Create a uniquely named local candidate branch/ref from that HEAD; do not push it.
2. Immediately before the final gauntlet, capture canonical UTC and generate the line with `bin/pln-simplify marker --repo <root> --completed <UTC>`. Create one marker-bearing `--allow-empty` commit whose full message contains that line once. This same metadata-only commit records a verified `nothing worth changing` assessment.
3. Fingerprint this HEAD with `bin/pln-assurance`, then dispatch one fresh judgment worker under `{{OUTPUT_ROOT}}/src/workers/final-verification.md`. It runs the plan's full gauntlet once. Recompute the exact-candidate fingerprint afterward. A mismatch or any failed/absent check fails the candidate. A check the execution environment refused is neither a mismatch nor a failed check — the worker marks the aggregate environment-blocked and stops there, because clearing a refusal needs access it does not hold, and the rule under 4 is what you do with that.
4. On failure, return to the supported branch, delete only the named unpublished candidate ref, record the failure, and stop. Never merge, cherry-pick, amend, or copy its marker into supported ancestry. A refusal is not that failure and this step does not run on one: deleting the candidate ref over a refusal destroys the run's work on a permissions problem that said nothing about the tree.

   **A refused command leaves the gauntlet incomplete — not failed, and not destroyed.** An environment refusal — a denied write, a blocked network call, a capability the worker was not given — is not a verification result: the attempt is not spent and the candidate is not implicated. Keep the candidate ref. You hold access the worker you dispatched does not, so the rerun is yours: run exactly that one command against the tested candidate HEAD, with the access it needs, its output redirected to the assigned evidence file and never read back into coordinator context. What reaches this context is the command's exit status plus three recorded facts — **which command was refused, the exact refusal, and what access the rerun was granted**. An exit status is bounded metadata, not a log, so the context firewall holds without a second agent between you and the result. What still forces a whole repeat is the tree changing or the command set changing; a refusal does neither.

   Two conditions on combining that rerun with the recorded run, both answerable before you act. **Completeness:** every command in the recorded set carries a result, from the recorded run or from a named rerun. A command that never executed makes the gauntlet incomplete, and an incomplete gauntlet is not a pass, so it never reaches the fast-forward in 5. **The refusal must not be a claim about the code:** where the candidate's own diff against the supported branch touches the refused command, or changed what that command requires, the refusal *is* a verification result and the rerun does not repair it. A simplification that removed what a command needed is exactly what this gauntlet exists to catch, and a rerun granted the access the removal now demands hides it.

   **What that produces is a qualified pass, not a green.** Record it with the durable result as green except the named command, which ran at elevated access, carrying both environment hashes — the one the refused pass ran under and the one the rerun ran under. A command can pass *because* of the privilege it was rerun under, and nothing here tells that apart from a command that merely needed the privilege in order to run, so the qualification is disclosed rather than absorbed into a green nobody can audit. Where the refusal is never cleared — the access is not yours to grant either — the candidate ref stays where it is, unpublished and unmerged, and the run records an incomplete gauntlet and stops.
5. On success, verify candidate HEAD still equals the tested commit, return to the supported branch, and fast-forward it with `git merge --ff-only <candidate>`. Verify the supported HEAD equals that exact commit, then delete the temporary ref. Do not rewrite, squash, cherry-pick, or recreate the commit.

Set `Phase: complete` only after the unchanged fast-forward and durable result record. `{{PLN_SIMPLIFY_CMD}}` does not auto-run `{{PLN_PR_CMD}}`; a later ship request follows `{{PLN_PR_CMD}}`, whose best-effort body propagation never establishes freshness by itself.

Marker selection is deterministic: scan reachable local commit messages; accept only full-line supported V1 markers whose claimed fingerprint matches that marker commit's content; choose the greatest completion timestamp, then the lexicographically greatest exact line for a tie. Unsupported, malformed, non-ancestral, or unverifiable metadata never becomes stale—it yields `unknown` when no valid winner exists.
