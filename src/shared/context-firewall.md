## Coordinator context firewall

The coordinator owns conversation/state/blockers/hand-off. Route other reads before execution.

### Three context tiers

- **Coordinator-direct:** known-stop coordination state or one exact fact; at most two exact operations, 40 lines and 2 KiB combined, bounded before execution. Router/active-phase, root-instruction, `PLAN.md` and `REVIEW.md` reads are coordination-state exceptions.
- **Evidence:** a fresh `src/workers/evidence-collection.md` worker for mechanically closed facts beyond that budget. Return facts, citations, counterevidence and uncertainty. `evidence_profile` inherits unless economy is opted in.
- **Judgment:** fresh `judgment` for substantive synthesis, source review, scope/reversals, conflicting applicability, architecture/risk, failure interpretation and new repair admission. Clean post-fix verification may prepare its ledger under the fix phase's contract.

The coordinator mechanically checks leases/evidence/checkpoints and publishes records; this is not source assurance. It may execute trusted sealed graphs file-first, preserving dependencies/resources/executors/access/approvals. Consume bounded statuses; delegate failure/uncertainty judgment.

Raw diffs, source, logs, corpora and reviewer/peer output never enter coordinator context. Redirect unbounded output before execution; a later `head`/`tail` does not prove boundedness.

### Escalation and retry

Exploratory direct follow-ups escalate. Evidence returns `ESCALATE: frontier` for non-closure/conflict/applicability/risk; judgment reads its artifacts. Invalid results get one fresh same-tier retry; confined format-only errors may continue the idle worker under a recorded assignment. Consume no rejected bytes. Evidence then escalates once; failed judgment fails closed. Unavailable opted-in economy falls back with attribution. Never fall back inline.

### File-first boundary and routing record

Give contract/plan sections, scope/source, artifact paths, budget and routing, not pasted evidence. Workers write under the assigned root and return `RESULT_FILE=<absolute envelope path>`. Read through `bin/pln-read-envelope`, never raw artifacts after rejection. Require `src/workers/context-envelope.md` and citations. Missing facts get narrow follow-up; mechanical corrections may continue, independent judgment stays fresh.

Append `<plan-dir>/routing.tsv` through `{{SKILL_DIR}}/bin/pln-route-ledger` after every lookup/attempt: scope, tier/reason, risk, requested/actual profile/model/effort, fallback/escalation, source, status and artifacts. Envelope ceilings remain 8192 bytes preflight and 4096 bytes per-item/follow-up.
