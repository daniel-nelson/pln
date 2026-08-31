# Worker result envelope contract

This file is worker-owned runtime instruction. The coordinator may name this path but does not paste or load this contract into its own conversation.

Write complete research notes to the assigned path beneath `<plan-dir>/evidence/`. Then write a concise plain-text envelope to the assigned result path. The result path must also be beneath the plan directory and must fit the byte budget in the assignment.

The envelope has this exact top-level shape:

```text
STATUS: <complete or blocked>
SCOPE: <the exact question or item investigated>
REQUESTED_PROFILE: <inherit, judgment, or evidence>
ACTUAL_PROFILE: <profile that actually ran>
ACTUAL_MODEL: <host-reported model, or selected alias plus "underlying unreported">
ACTUAL_EFFORT: <host-reported effort, or unreported>
ROUTING_FALLBACK: <fallback/escalation, or none>
ESCALATE: <frontier or none>

SUMMARY:
<decision-relevant findings only>

COUNTEREVIDENCE:
<facts that weaken the leading approach, or "none found">

UNCERTAINTY:
<material unknowns, or "none">

REFERENCES:
- <repo-relative-path>:<line> — <claim supported>

DECISION_IMPACT:
<what the coordinator should decide or ask next; no implementation>

EVIDENCE_FILE: <plan-directory-relative path to the detailed notes>
```

Rules:

- Use `STATUS: complete` only after investigating the whole assigned scope. If blocked, use `STATUS: blocked` and explain the blocker under `UNCERTAINTY`; do not manufacture a successful result.
- Copy routing attribution from the assignment and update it from host-reported runtime metadata when available. Never turn a requested alias into an invented underlying model. If routing fell back or escalated, name why.
- Evidence workers write `ESCALATE: frontier` as soon as the assigned question stops being mechanically closed or crosses a semantic-risk boundary. Other workers write `ESCALATE: none`.
- Every factual claim that could change the plan needs an exact durable reference. Use line numbers where the source format supports them.
- Keep raw command output, long excerpts, exhaustive file lists, and discarded paths in the evidence file, never the envelope.
- Measure and trim before you finalize, rather than learning the limit from a rejection. Write the draft envelope to the result path, measure it with `wc -c`, and while it exceeds the assigned budget, trim and measure again: move detail into the evidence file, cut `SUMMARY` to what changes a decision, and drop references that support no decision-relevant claim. Every field above stays present at every size — trim what a field says, never the field itself. Do not report the result until a measurement shows it fits.
- Do not implement, edit product files, commit, or broaden the assigned scope.
- Your final chat response is exactly one line: `RESULT_FILE=<absolute envelope path>`.

WORKER_ONLY_SENTINEL_CONTEXT_ENVELOPE_V1
