---
name: pln-pr-phase-blocker
---

# /pln-pr phase: blocker handling

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first blocker action. `REVIEW.md` plus `fix-manifest.tsv` must name the finding/cluster, self-contained question, available handle or fallback result, partial working-tree state, checkpoint state, and expected continuation. A handle may be lost; a handoff may not. Missing or contradictory recovery state fails closed.

Every answer, recovery fact, and cursor change is written into a complete next-generation candidate and published through `{{OUTPUT_ROOT}}/bin/pln-publish-review` with the current digest/generation. Never edit canonical `REVIEW.md`; a stale rejection requires rereading and reconciling the blocker state.

Freeze new dispatch; clusters run one at a time, so nothing else is running to checkpoint across the blocker. Ask at most one durable question. After the answer, write it against the finding, reconcile the exact tree, set `Phase: fix`, then read the fix phase in full before same-agent continuation or the documented fresh-worker recovery. If the blocker invalidates scope/base/trust, record that fact and return conservatively to `scope-baseline`. Auto mode is `{{PLN_CMD}}`-only.

<!-- pln:include followup-filing -->
