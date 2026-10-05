---
name: pln-pr-phase-blocker
---

# /pln-pr phase: blocker handling

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first blocker action. `REVIEW.md` plus `fix-manifest.tsv` must name the finding/cluster, self-contained question, available handle or fallback result, partial working-tree state, checkpoint state, and expected continuation. A handle may be lost; a handoff may not. Missing or contradictory recovery state fails closed.

Every answer, recovery fact, and cursor change is written into a complete next-generation candidate and published through `{{OUTPUT_ROOT}}/bin/pln-publish-review` with the current digest/generation. Never edit canonical `REVIEW.md`; a stale rejection requires rereading and reconciling the blocker state.

Freeze new dispatch; clusters run one at a time, so nothing else is running to checkpoint across the blocker. Ask at most one durable question. After the answer, write it against the finding, reconcile the exact tree, set `Phase: fix`, then read the fix phase in full before same-agent continuation, documented fresh-worker recovery, or first dispatch of a needs-decision cluster that had no worker yet. If the blocker invalidates scope/base/trust, record that fact and return conservatively to `scope-baseline`. Auto mode is `{{PLN_CMD}}`-only.

**A repair the run has already selected is decided, not waited on.** A production-reachable `worker-blocked` handoff for a consequential repair, or a `needs-decision`/`destructive` finding with an already selected repair, takes this path when the repair does not contravene an explicit owner constraint. Ask nothing and wait for nothing. Publish `Decision: run's choice` against the finding with the selected repair, the repair passed over and what each adds, and the exact candidate. Fire enabled notifications ({{NOTIFY_CALL}}) naming the choice, the alternative, and that a reply switches it. Then set `Phase: fix` and continue the idle worker, or its fresh recovery, with that recorded decision. A later reply that picks the other repair is steering: record it before the next action it can still change, and rebuild on it if the chosen repair has already landed.

Observed: an earlier release asked, reminded after five minutes and proceeded after five more. On Claude Code in auto mode the permission check refused the timer that would proceed past the unanswered question, and the run stopped with nothing built while its user was away, over a choice the user did not consider important and after being told to keep working. A choice the run makes and reports needs no timer.

An explicit owner constraint, a missing candidate, or a question with no selected repair is not decided this way: ask it through the ordinary answer and recovery path above and wait for the answer. The run's own choice never lifts an owner constraint.

<!-- pln:include followup-filing -->
