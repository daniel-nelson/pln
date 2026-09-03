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
3. Fingerprint this HEAD with `bin/pln-assurance`, then dispatch one fresh judgment worker under `{{OUTPUT_ROOT}}/src/workers/final-verification.md`. It runs the plan's full gauntlet once. Recompute the exact-candidate fingerprint afterward. A mismatch or any failed/absent check fails the candidate.
4. On failure, return to the supported branch, delete only the named unpublished candidate ref, record the failure, and stop. Never merge, cherry-pick, amend, or copy its marker into supported ancestry.
5. On success, verify candidate HEAD still equals the tested commit, return to the supported branch, and fast-forward it with `git merge --ff-only <candidate>`. Verify the supported HEAD equals that exact commit, then delete the temporary ref. Do not rewrite, squash, cherry-pick, or recreate the commit.

Set `Phase: complete` only after the unchanged fast-forward and durable result record. `{{PLN_SIMPLIFY_CMD}}` does not auto-run `{{PLN_PR_CMD}}`; a later ship request follows `{{PLN_PR_CMD}}`, whose best-effort body propagation never establishes freshness by itself.

Marker selection is deterministic: scan reachable local commit messages; accept only full-line supported V1 markers whose claimed fingerprint matches that marker commit's content; choose the greatest completion timestamp, then the lexicographically greatest exact line for a tie. Unsupported, malformed, non-ancestral, or unverifiable metadata never becomes stale—it yields `unknown` when no valid winner exists.
