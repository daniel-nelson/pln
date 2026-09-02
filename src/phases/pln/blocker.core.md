---
name: pln-phase-blocker
---

# /pln phase: blocker handling

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first blocker action. Enter only after the worker's partial state, handoff, worktree, available handle/thread, and item status are durable in `run-manifest.tsv`. On restart, validate the manifest and reconcile its source HEAD, dirty snapshot, handoff, worktree, diff/commit, result, and item row before asking or resuming. A handle is an optimization, not required recovery state; missing or conflicting worktree/artifact state fails closed.

Persist the blocking question in `Open questions` before sending it. After the answer, write the decision and remove the open question, retain the recorded partial state, set `Phase: implementation`, then read the implementation phase in full before continuing the same worker or its documented fresh-worker fallback. Recompute readiness from the manifest; never jump to a remembered next item.

**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-queue add` — not by leaving it in prose for the close to remember.

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

**The hand-off, on hitting a threshold.** The subagent does not roll back. It leaves changes uncommitted in its assigned worktree and writes a handoff file to the plan dir, `<timestamp>-item-<N>-<slug>.md`, containing what it did, which files it touched, the dead ends, and the self-contained blocking question. It returns a message beginning `BLOCKED:` with the question and handoff. The coordinator records the handoff, worktree, available identity, and `blocked` status before any question or new dispatch.

**The orchestrator's response:**

<!-- pln:only claude -->
- **Interactive (default):** freeze new dispatch. Already-running isolated siblings may finish and checkpoint in their own worktrees, but do not integrate. Notify, surface one question, record the answer in `PLAN.md`, then `SendMessage` the answer and handoff to the same Agent ID. If that identity is gone, start a fresh Agent on the item, handoff, answer, and retained worktree. Validate and coordinator-checkpoint the completed item before readiness is recomputed.
- **Auto (see below):** retain the blocked worktree exactly where the manifest records it; do not stash or merge it. Mark dependency descendants `waiting`. Already-running siblings and later nodes proven independent of the blocker and every dirty path may finish in isolated worktrees and checkpoint, but nothing integrates across the blocker. At end-of-run blocker review, record answers and continue each retained Agent/worktree, or a fresh Agent when the identity is gone, then recompute readiness.
<!-- pln:endonly -->
<!-- pln:only codex -->
Everything the protocol does to the repository — stashing, restoring, committing — is the orchestrator's job, not the agent's. The agent's part is to stop, write the handoff file, and return.

- **Interactive (default):** freeze new dispatch. Already-running isolated siblings may finish and checkpoint in their own worktrees, but do not integrate. Notify, surface one question, and record the answer in `PLAN.md`. Start another turn on the idle blocked agent with `followup_task`, carrying the answer and handoff; if the identity is gone, spawn a fresh agent on the item, handoff, answer, and retained worktree. Validate and coordinator-checkpoint the completed item before readiness is recomputed.
- **Auto (see below):** retain the blocked worktree exactly where the manifest records it; do not stash or merge it. Mark dependency descendants `waiting`. Already-running siblings and later nodes proven independent of the blocker and every dirty path may finish in isolated worktrees and checkpoint, but nothing integrates across the blocker. At end-of-run blocker review, record answers and use `followup_task` on each retained identity, or a fresh agent when it is gone, then recompute readiness.

If the agent can't be continued, the fallback is a fresh agent pointed at the item, handoff, answer, retained worktree/diff, and last validated result. A lost identity costs reasoning but no work. A user interruption follows the same durability order: mark affected nodes `interrupted` with worktree/artifact pointers first, then steer or stop workers, and integrate nothing unfinished.

**A retained worktree is held exclusively, and that is what makes a node's own tree unavailable to everything else.** A `blocked` or `interrupted` node keeps the tree the manifest records for it until it reaches a terminal status, because that tree is where its uncommitted work sits. So the node stays dispatchable — `pln-scheduler recover` names the claim that resumes it — while no other node may be dispatched into that same tree. When the retained tree is the original one, that is the whole of it: every other original-worktree node waits, and only nodes proven independent of the blocker and of every dirty path may run, in isolated trees of their own. Reading the node's own dispatchability as the tree being free is how two workers end up writing one tree.
<!-- pln:endonly -->
