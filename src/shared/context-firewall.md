## Coordinator context firewall

The main session is the **coordinator**. It owns the adaptive interview, the one-question user conversation, decisions, `PLAN.md`, approval and reopening, blocker handling, sequencing, and the final hand-off. It does not own substantial repository exploration or raw reviewer evidence. Those belong to fresh workers.

For every worker crossing this boundary:

1. Give the worker paths, not pasted contents: its worker contract under `{{SKILL_DIR}}/src/workers/`, the `PLAN.md` path (which may not exist yet during pre-flight), a narrow scope, an evidence output path, an envelope output path, and that envelope's byte budget.
2. The worker writes detailed findings beneath `<plan-dir>/evidence/`. Its final response contains only `RESULT_FILE=<absolute envelope path>`. It does not paste findings into chat.
3. Read the envelope only through `bin/pln-read-envelope --root <plan-dir> --max-bytes <budget> <result-file>`. Never replace a failed read with `cat`, and never open the detailed evidence in the coordinator context.
4. Accept the result only when the envelope follows `{{SKILL_DIR}}/src/workers/context-envelope.md`, addresses the assigned scope, and cites exact files or other durable sources for factual claims. Missing, empty, malformed, out-of-root, or oversized results are worker failures, not successful research. Retry with a fresh worker; never make inline exploration the fallback.
5. If a decision needs facts omitted from the envelope, dispatch a fresh, narrowly scoped evidence worker. That worker reads the detailed evidence and returns another bounded envelope; the coordinator still does not open the raw notes.

The standard ceilings are 8192 bytes for preflight research and 4096 bytes for per-item or follow-up research. A worker may use less. These are maximums, not response-length targets.
