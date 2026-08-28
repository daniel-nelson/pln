## Active-turn lifecycle

**Host-native activity is the progress surface.** Keep accepted automatic work attached to the current parent turn so the host can truthfully show it as running. Do not manufacture recurring chat heartbeats to replace that UI. A status update is commentary, never a terminal response.

A final response is allowed only when control genuinely returns to the user: one persisted question or blocker needs their answer and nothing else is still in flight (see Holding output until the work quiesces), the requested endpoint is verified complete, or the run has reached a deliberate or irreducible stop with no authorized work left to do. While any accepted work is running, ready, recoverable, or awaiting integration, keep this same turn active. That includes a native worker or worker group, a tracked background task or resumable command session, an in-flight peer subprocess, a CI watch, a completed result not yet consumed, a checkpoint not yet integrated, a dispatchable or recoverable manifest/ledger node, and a hand-off to another skill that durable state records as decided but not yet performed.

**Before any final response, run the terminal-state audit:**

1. Reconcile every native worker, worker-group, background-task, and command-session handle; a quiet wait or missing notification is not terminal evidence.
2. Consume every completed result and advance its durable manifest/ledger state before deciding what remains.
3. Run the phase's deterministic finish check when one exists, and inspect the durable cursor for ready, running, blocked, recoverable, or unintegrated work.

If anything nonterminal remains, wait, poll, recover, integrate, or dispatch it now in this turn. Never say work is continuing autonomously and then send a final response. Durable manifests and goals support recovery after a real interruption; they do not make voluntary detachment a valid scheduling strategy.

### Holding output until the work quiesces

**Nothing the user has to have read goes out while work is still running.** A message sent mid-flight scrolls away under everything that follows it, so a later message ends up re-referring to a finding or a question the user never saw — and the retelling is always the thinner one. That is how a question gets asked twice: once where it will be buried, and once in summary, after the user fails to answer the buried copy.

So when a worker, task, review, or peer call returns while others are still outstanding, consume its result, write it into the durable record, and say nothing.

**What is held is a set of topics, not a transcript.** Split each landing result at the seam that matters to the user: one unit per question it raises, carrying the evidence that question turns on. Never hold a running log to replay later. A message that recites three findings and then asks about one of them buries the other two exactly the way mid-flight output did, and the next question has to reach back into it.

When the work quiesces, send the first unit — its finding, its evidence, its question, in whichever of the message shapes fits. Wait for the answer. Then send the next unit, carrying its own evidence with it. A question message stands on its own or it is not finished: the user is not holding evidence from an earlier turn, whether that turn was thirty seconds ago or thirty minutes. One question at a time is unchanged; what changes is that each question waits for a quiet turn and arrives with its own grounds attached.

**A finding that raises no question does not earn a turn of its own.** It goes into the durable record and reaches the user where the run already surfaces such things — the approval gate, the walk through flagged entries, the closing message's sweep. Attaching it to an unrelated question's message is the same conflation from the other end.

**Reconcile the held units before the first goes out, and again after every answer.** A later result routinely changes an earlier one's premise: it can merge two units, answer one outright, or make it moot. What reaches the user is what is true when it is sent, not what each worker said as it landed.

A question already in front of the user is not overwritten either. Where one is open when the last of the work lands, keep holding: the unanswered question stays the only thing on the screen until they answer it.

Two things are exempt, because neither is something the user has to have read: the host's own activity surface, and a status line they can ignore without missing anything. Neither may carry a finding or a question.

The one thing that overrides the hold is running work the held result makes moot. Say so and cancel it, rather than letting it finish underneath a question its own answer would change.
