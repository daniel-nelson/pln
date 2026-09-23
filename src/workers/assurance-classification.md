# Assurance classification contract

Risk classification is fresh `judgment` work. The assignment names the plan or file-first diff/metadata artifacts, protected choices, exact source fingerprint, evidence path, result path, and a 4096-byte budget. Read `context-envelope.md` beside this file before starting. Do not proceed on an evidence/economy route.

Classify meaning, not line count. Inspect enough context to decide which of the signals below the candidate carries. Unknown or conflicting risk is the literal `unknown` signal. Separately report substantive non-generated file and line counts; they may raise risk but never lower it. When the assignment carries `pln-assurance diff-stats` totals (`FILES`, `DIFF_LINES`), those are the raw counts: start from them and subtract only the generated files you can name, rather than counting again.

**The accepted signals are these exact tokens, and nothing else.** They are spelled here so this work never costs a search through pln's own source for them; `bin/pln-assurance classify` accepts these and its `--help` repeats them.

- Routine: `routine`
- Raises to R2: `dependencies` `builds` `configuration` `generators` `public-contracts` `missing-coverage` `multiple-subsystems`
- Raises to R3: `authentication` `trust` `secrets` `privacy` `production-data` `money` `external-effects` `destructive-migrations` `concurrency` `transactions` `iac` `ci-security` `compatibility` `ai-safety` `eval-safety` `critical-conflict` `unknown`

A token outside that set is not a near miss that gets corrected — it classifies as R3 with the reason `unknown:<token>`, which is safe but records a signal nobody can act on. Spell them as written. Underscores and capitals are folded, so `PRODUCTION_DATA` reaches `production-data`; anything else does not.

Specialist areas are **not** a closed vocabulary and there is no list to find: each one you return becomes a reviewer slot named `risk-<area>`, so write the area as it should read there — `production-data-integrity`, `transactions-concurrency`. At most two, ordered by expected defect recall.

Return the signals ordered highest-risk first. Cite exact durable evidence for every signal and area. Do not recommend a fix, choose whether review is skipped, or count a peer before egress/consent is resolved.

Write complete reasoning to the evidence path. Write a context-envelope result whose `SUMMARY` includes exactly one `SIGNALS=<csv>`, `SPECIALIST_AREAS=<csv-or-none>`, `SUBSTANTIVE_FILES=<n>`, and `NON_GENERATED_LINES=<n>` block plus source fingerprint. `DECISION_IMPACT` tells the coordinator to validate it with `bin/pln-assurance classify` and `roster`; it does not select models or dispatch readers. Final response: `RESULT_FILE=<absolute result path>`.

WORKER_ONLY_SENTINEL_ASSURANCE_CLASSIFICATION_V1
