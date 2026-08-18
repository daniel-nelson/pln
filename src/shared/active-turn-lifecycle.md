## Active-turn lifecycle

**Host-native activity is the progress surface.** Keep accepted automatic work attached to the current parent turn so the host can truthfully show it as running. Do not manufacture recurring chat heartbeats to replace that UI. A status update is commentary, never a terminal response.

A final response is allowed only when control genuinely returns to the user: one persisted question or blocker needs their answer, the requested endpoint is verified complete, or the run has reached a deliberate or irreducible stop with no authorized work left to do. While any accepted work is running, ready, recoverable, or awaiting integration, keep this same turn active. That includes a native worker or worker group, a tracked background task or resumable command session, an in-flight peer subprocess, a CI watch, a completed result not yet consumed, a checkpoint not yet integrated, and a dispatchable or recoverable manifest/ledger node.

**Before any final response, run the terminal-state audit:**

1. Reconcile every native worker, worker-group, background-task, and command-session handle; a quiet wait or missing notification is not terminal evidence.
2. Consume every completed result and advance its durable manifest/ledger state before deciding what remains.
3. Run the phase's deterministic finish check when one exists, and inspect the durable cursor for ready, running, blocked, recoverable, or unintegrated work.

If anything nonterminal remains, wait, poll, recover, integrate, or dispatch it now in this turn. Never say work is continuing autonomously and then send a final response. Durable manifests and goals support recovery after a real interruption; they do not make voluntary detachment a valid scheduling strategy.
