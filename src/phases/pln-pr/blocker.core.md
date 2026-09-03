---
name: pln-pr-phase-blocker
---

# /pln-pr phase: blocker handling

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first blocker action. `REVIEW.md` plus `fix-manifest.tsv` must name the finding/cluster, self-contained question, available handle or fallback result, retained worktree, partial checkpoint state, and expected continuation. A handle may be lost; a worktree/handoff may not. Missing or contradictory recovery state fails closed.

Freeze new dispatch; already-running isolated siblings may checkpoint but never integrate across the blocker. Ask at most one durable question. After the answer, write it against the finding, reconcile the exact tree and retained worktree, set `Phase: fix`, then read the fix phase in full before same-agent continuation or the documented fresh-worker recovery. If the blocker invalidates scope/base/trust, record that fact and return conservatively to `scope-baseline`. Auto mode is `{{PLN_CMD}}`-only.

**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-queue add` — not by leaving it in prose for the close to remember.
