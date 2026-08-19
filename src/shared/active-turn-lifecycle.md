## Active-turn lifecycle

**Host-native activity is the progress surface.** Keep accepted automatic work attached to the current parent turn so the host can truthfully show it as running. Do not manufacture recurring chat heartbeats to replace that UI. A status update is commentary, never a terminal response.

A final response is allowed only when control genuinely returns to the user: one persisted question or blocker needs their answer and nothing else is still in flight (see Holding output until the work quiesces), the requested endpoint is verified complete, or the run has reached a deliberate or irreducible stop with no authorized work left to do. While any accepted work is running, ready, recoverable, or awaiting integration, keep this same turn active. That includes a native worker or worker group, a tracked background task or resumable command session, an in-flight peer subprocess, a CI watch, a completed result not yet consumed, a checkpoint not yet integrated, and a dispatchable or recoverable manifest/ledger node.

**Before any final response, run the terminal-state audit:**

1. Reconcile every native worker, worker-group, background-task, and command-session handle; a quiet wait or missing notification is not terminal evidence.
2. Consume every completed result and advance its durable manifest/ledger state before deciding what remains.
3. Run the phase's deterministic finish check when one exists, and inspect the durable cursor for ready, running, blocked, recoverable, or unintegrated work.

If anything nonterminal remains, wait, poll, recover, integrate, or dispatch it now in this turn. Never say work is continuing autonomously and then send a final response. Durable manifests and goals support recovery after a real interruption; they do not make voluntary detachment a valid scheduling strategy.

### Holding output until the work quiesces

**Nothing the user has to have read goes out while work is still running.** A message sent mid-flight scrolls away under everything that follows it, so a later message ends up re-referring to a finding or a question the user never saw — and the retelling is always the thinner one. That is how a question gets asked twice: once where it will be buried, and once in summary, after the user fails to answer the buried copy.

So when a worker, task, review, or peer call returns while others are still outstanding, consume its result, write it into the durable record, and say nothing. Hold its findings and its question. When the last one lands, send one message carrying everything held — the accumulated findings, then the single question that needs answering. One question at a time is unchanged; what changes is that the question waits for a quiet turn instead of competing with output the user is expected to have read on the way past.

A question already in front of the user is not overwritten either. Where one is open when the last of the work lands, keep holding: the unanswered question stays the only thing on the screen until they answer it.

Two things are exempt, because neither is something the user has to have read: the host's own activity surface, and a status line they can ignore without missing anything. Neither may carry a finding or a question.

The one thing that overrides the hold is running work the held result makes moot. Say so and cancel it, rather than letting it finish underneath a question its own answer would change.
