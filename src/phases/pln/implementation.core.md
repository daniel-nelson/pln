---
name: pln-phase-implementation
---

# /pln phase: implementation

Read this file in full before the first implementation action. Rebuild pending work from the durable dashboard rather than memory. `Phase: implementation` permits item dispatch and coordinator checkpointing only after adoption is recorded.

Keep the cursor here across ordinary item boundaries. On a blocker, first write the handoff and item/dashboard state, then set `Phase: blocker` and load that file. When no runnable implementation or deferred item remains, finish all item outcomes, set `Phase: finish-ship`, and load that phase before verification or shipping.

### Step 5. Implementation phase

<!-- pln:include step5-orchestration -->

Each item assignment points the fresh worker at `{{SKILL_DIR}}/src/workers/item-implementation.md` and supplies `PLAN.md`, item number, project root, mandated-learning note, host commit owner, handoff path, evidence path, result path, and a 2048-byte envelope budget. Do not paste the contract into the brief. On success, validate its `RESULT_FILE` through `bin/pln-read-envelope --root <plan-dir> --max-bytes 2048 <result-file>` before recording or committing the item. Missing, empty, malformed, out-of-root, or oversized results fail the item. A `BLOCKED:` response follows the blocker protocol and is never treated as success.

The orchestrator breaks silence to the user only when a subagent returns `BLOCKED:` (interactive default), or when the user interrupts. If the user asks a new design question mid-implementation, treat it as a blocker: pause, decide, update the plan, then continue the blocked worker through the host's native follow-up surface. Don't quietly improvise or skip ahead to a new worker.
### Auto-mode behavior

Auto mode applies only to **Step 5 (implementation phase)**. The orchestrator already runs items end-to-end without stopping between them; what auto mode adds is that it does not even stop for blockers — a `BLOCKED:` return is deferred (partial work stashed, item marked ⏸ blocked) and surfaced at the end-of-run review instead of interrupting the user.

It does NOT bypass:

- The Step 2 skeleton gate ("Continue?").
- The Step 3 interview phase: every per-item question must still be asked and answered.
- The Step 4 master-plan approval gate: explicit adoption is always required before implementation begins.
- The four blocker thresholds: a subagent still stops and hands off on any of them. Auto mode only changes whether the orchestrator surfaces the blocker now or defers it.

Delegated mode is the only thing that bypasses the first and third of those, and it does so because the user adopted the plan in advance (see Delegated mode). The two modes compose without cancelling each other: a run in both still stops for delegated mode's pre-implementation short list, and auto mode still defers a blocker to the end-of-run review rather than surfacing it live.

### Spinoffs

Spawn a spinoff plan file when an item meets any of:

- Implementation ripples beyond the current task's stated scope (front-end audit, IaC changes, coordination with another system).
- The item is more naturally tackled by a fresh agent with full context rather than continuing inline.
- The item depends on infrastructure or external work that isn't ready yet.
- The item produces a meaningfully different commit-set / PR than the rest of the task.

Spinoff file path: `./plans/<YYYY-MM-DD>-<slug>/<item-slug>.md` (sibling to `PLAN.md`).

Spinoff file structure (in order):

1. Why this exists — what triggered the spinoff, what's broken/missing today.
2. Target shape / end state — what "done" looks like.
3. Pre-flight audit step ("Step 0") — explicit "examine X before changing code" if the item touches surfaces a fresh agent might not know about (front-end consumers, IaC, etc.).
4. Implementation steps — numbered.
5. Verification — the repo-specific gauntlet for this work.
6. Reminders — cross-cutting TODOs the agent should surface (e.g., persistent-TODO reminders from `CLAUDE.md`).

A subagent does not create a spinoff itself. When it judges an item warrants one, it hands off (`BLOCKED:`) recommending the spinoff with its reasoning; the orchestrator writes the spinoff file and updates `PLAN.md`. After writing the spinoff, update the parent `PLAN.md`: mark the item ⏸ deferred and add a link in the Spinoffs section.

