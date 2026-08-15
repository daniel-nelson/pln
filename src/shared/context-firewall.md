## Coordinator context firewall

The coordinator owns conversation, durable decisions/cursors, blockers, and hand-off. Route every other read before running it.

### Three context tiers

- **Coordinator-direct:** known-stop coordination state or one exact fact; at most two exact operations, 40 lines, and 2 KiB combined, provably bounded before execution. Router/active-phase, root-instruction, `PLAN.md`, and `REVIEW.md` reads are coordination-state exceptions.
- **Evidence:** a fresh `src/workers/evidence-collection.md` worker for mechanically closed facts beyond that budget. It returns facts, citations, counterevidence, and uncertainty only. `evidence_profile` inherits by default and uses economy only after opt-in.
- **Judgment:** a fresh `judgment`/high-effort worker for synthesis, scope/question changes, conflicting-record applicability, reversals, recommendations, architecture/API seams, concurrency/transactions, migrations/destructive lifecycle, security/privacy, external/AI/eval effects, and all review, verification, or merges.

Raw diffs, source neighborhoods, logs, decision corpora, reviewer output, and peer output never enter coordinator context. Write them to artifacts; read only fixed metadata or validated envelopes. Possibly unbounded commands redirect before execution—post-generation `head`/`tail` is not proof of boundedness.

### Escalation and retry

A direct lookup needing an exploratory follow-up escalates immediately. Evidence writes `ESCALATE: frontier` for non-closure, conflict, applicability, or risk; dispatch judgment on its artifact paths.

Missing, empty, malformed, out-of-root, oversized, or wrong-scope output gets one fresh same-tier retry. Then evidence escalates once to judgment; failed judgment fails closed. Unavailable opted-in economy falls back to inherited evidence with attribution. Never fall back inline.

### File-first boundary and routing record

For every worker crossing this boundary:

1. Give contract/plan paths, exact scope/source state, evidence/result paths, budget, and routing controls—not pasted evidence.
2. Workers write beneath `<plan-dir>/evidence/` and return only `RESULT_FILE=<absolute envelope path>`.
3. Read results only through `bin/pln-read-envelope`; never `cat` after failure or open raw artifacts.
4. Accept only `src/workers/context-envelope.md` shape with durable citations; missing facts require a narrow follow-up worker.

After every lookup/attempt, append `<plan-dir>/routing.tsv` with `{{SKILL_DIR}}/bin/pln-route-ledger`: scope, tier/reason, risk flags, requested/actual profile/model/effort, fallback/escalation, source state, status, and artifacts. It is local recovery state, not user-facing.

Envelope ceilings remain 8192 bytes preflight and 4096 bytes per-item/follow-up.
