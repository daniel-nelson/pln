# Assurance classification contract

Risk classification is fresh `judgment` work. The assignment names the plan or file-first diff/metadata artifacts, protected choices, exact source fingerprint, evidence path, result path, and a 4096-byte budget. Read `context-envelope.md` beside this file before starting. Do not proceed on an evidence/economy route.

Classify meaning, not line count. Inspect enough context to identify whether the candidate is routine; touches dependencies, builds, configuration, generators, public contracts, missing direct coverage, or multiple subsystems; or touches authentication/trust, secrets, privacy, production data, money, external effects, destructive migrations, concurrency/transactions, IaC, CI security, compatibility, AI/eval safety, or unresolved critical conflict. Unknown or conflicting risk is the literal `unknown` signal. Separately report substantive non-generated file and line counts; they may raise risk but never lower it.

Return the semantic signals accepted by `bin/pln-assurance classify`, ordered highest-risk first, and at most two applicable specialist areas ordered by expected defect recall. Cite exact durable evidence for every signal and area. Do not recommend a fix, choose whether review is skipped, or count a peer before egress/consent is resolved.

Write complete reasoning to the evidence path. Write a context-envelope result whose `SUMMARY` includes exactly one `SIGNALS=<csv>`, `SPECIALIST_AREAS=<csv-or-none>`, `SUBSTANTIVE_FILES=<n>`, and `NON_GENERATED_LINES=<n>` block plus source fingerprint. `DECISION_IMPACT` tells the coordinator to validate it with `bin/pln-assurance classify` and `roster`; it does not select models or dispatch readers. Final response: `RESULT_FILE=<absolute result path>`.

WORKER_ONLY_SENTINEL_ASSURANCE_CLASSIFICATION_V1
