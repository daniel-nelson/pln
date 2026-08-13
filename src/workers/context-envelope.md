# Worker result envelope contract

This file is worker-owned runtime instruction. The coordinator may name this path but does not paste or load this contract into its own conversation.

Write complete research notes to the assigned path beneath `<plan-dir>/evidence/`. Then write a concise plain-text envelope to the assigned result path. The result path must also be beneath the plan directory and must fit the byte budget in the assignment.

The envelope has this exact top-level shape:

```text
STATUS: <complete or blocked>
SCOPE: <the exact question or item investigated>

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
- Every factual claim that could change the plan needs an exact durable reference. Use line numbers where the source format supports them.
- Keep raw command output, long excerpts, exhaustive file lists, and discarded paths in the evidence file, never the envelope.
- Do not implement, edit product files, commit, or broaden the assigned scope.
- Your final chat response is exactly one line: `RESULT_FILE=<absolute envelope path>`.

WORKER_ONLY_SENTINEL_CONTEXT_ENVELOPE_V1
