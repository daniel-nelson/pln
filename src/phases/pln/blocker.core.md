---
name: pln-phase-blocker
---

# /pln phase: blocker handling

Read this file in full before the first blocker action. Enter only after the worker's partial state, handoff, handle/thread, and item status are durable. On restart, reconcile the handoff, worktree/stash state, uncommitted diff, and item row before asking or resuming. Missing or conflicting recovery state fails closed; never guess which partial work is authoritative.

Persist the blocking question in `Open questions` before sending it. After the answer, write the decision and remove the open question, restore or retain the recorded partial state as applicable, set `Phase: implementation`, then read the implementation phase in full before continuing the same worker or its documented fresh-worker fallback.

## Cross-cutting concerns

These apply throughout the per-item loop; they are not sequential steps.

### Mid-item discovery — the blocker protocol

A subagent can't ask the user anything; it runs in isolation and returns one final message. So the four discovery thresholds become a stop-and-hand-off protocol rather than a pause-and-ask.

A subagent stops and hands off when any of:

- The discovery requires a change **outside** the item's stated scope (different file, different layer, different system).
- The discovery means the original plan **won't work as written** and a real choice has to be made.
- The discovery has **irreversible consequences** (data migration, schema change, anything that touches shared infra).
- The discovery reveals an assumption was wrong that **other items also depend on**.

Recommending a spinoff (see Spinoffs) is one kind of hand-off. Otherwise, the subagent fixes inline — silently, or with a one-line note in the item's Discoveries. No hand-off.

**The hand-off, on hitting a threshold.** The subagent does not roll back. It leaves its changes uncommitted in the working tree and writes a handoff file to the plan dir, `<timestamp>-item-<N>-<slug>.md`, containing what it did, which files it touched, the dead ends, and the self-contained blocking question (same self-containment discipline as interview questions — answerable without the subagent's context). It returns a message beginning `BLOCKED:` with the question and the handoff filename.

**The orchestrator's response:**

<!-- pln:only claude -->
- **Interactive (default):** the loop stops at the blocked item. Append the stable Agent ID and name to the handoff immediately; without them a compaction or restart loses the cheapest continuation path. If notifications are on, fire them first, naming the item and one-line question. Surface that one question, record the answer in `PLAN.md`, then `SendMessage` the answer and handoff path to the same Agent ID. A completed named Agent auto-resumes in the background with its prior context. Wait for the next completion notification, validate the result, and continue only after its worker-owned commit exists. If the native identity is genuinely gone, start a fresh Agent on the handoff, answer, and uncommitted diff.
- **Auto (see below):** after recording the Agent identity, the orchestrator stashes the partial work under a unique label, writes the label to the handoff, marks the item ⏸ blocked, and moves only to a non-dependent item. At the end-of-run review, restore each labeled stash and `SendMessage` that Agent with the recorded answer. A blocked Agent never owns the stash transition; the coordinator needs that durable recovery metadata.
<!-- pln:endonly -->
<!-- pln:only codex -->
Everything the protocol does to the repository — stashing, restoring, committing — is the orchestrator's job, not the agent's. The agent's part is to stop, write the handoff file, and return.

- **Interactive (default):** the loop stops at the blocked item. The orchestrator's first act is to append the item's agent ID/canonical task name to the handoff (`Agent: <identity>`; on the fallback, `Thread: <THREAD_ID>`). Then notify if configured, surface the one question, and record the answer in `PLAN.md`. Start another turn on that idle blocked agent with `followup_task`, carrying the answer and handoff path, then return to the `wait_agent` loop. The same agent reads the existing diff, finishes, updates `PLAN.md`, and deletes the handoff; the orchestrator validates and commits it before advancing.
- **Auto (see below):** the loop doesn't stop. After recording the handle, the orchestrator stashes the partial work itself — `git stash push -u -m "pln <plan-slug> item <N>"` — and writes that same label into the handoff file, leaving a clean tree for the next item. Record the label, not `stash@{0}`: every later blocked item pushes another stash and shifts the index, so the ref is resolved back out of `git stash list` by its label at restore time. The item is marked ⏸ blocked and the orchestrator moves on to the next non-dependent item. A blocked item that a later item depends on already trips the "assumption other items depend on" threshold, so dependent items defer rather than building on a half-done base. All blocked items surface together at the end-of-run review (Step 6); for each, the orchestrator gets the answer, pops that item's stash back into the tree, and then resumes its agent exactly as interactive mode does.

If the agent can't be continued — no identity was kept, or `followup_task` cannot find it — the fallback is a fresh agent pointed at the handoff file, answer, and uncommitted diff. A lost agent costs the first attempt's reasoning and none of its work.
<!-- pln:endonly -->

