---
name: pln-pr-phase-blocker
---

# /pln-pr phase: blocker handling

Read this file in full before the first blocker action. The ledger must name the finding/cluster, self-contained question, handle or fallback result, partial commit/worktree state, and expected continuation. Missing or contradictory recovery state fails closed.

Ask at most one durable question. After the answer, write it against the finding, reconcile the exact tree and partial state, set `Phase: fix`, then read the fix phase in full before continuation. If the blocker instead invalidates scope/base/trust, record that fact and return conservatively to `scope-baseline`; never patch over it in this phase.


