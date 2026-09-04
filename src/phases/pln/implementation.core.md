---
name: pln-phase-implementation
---

# /pln phase: implementation

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first implementation action. Rebuild pending work from the durable dashboard and `<plan-dir>/run-manifest.tsv`, never memory. `Phase: implementation` permits scheduling, item dispatch, and coordinator checkpointing only after adoption is recorded.

Keep the cursor here across ordinary item boundaries. On a blocker, first write the handoff and item/dashboard state, then set `Phase: blocker` and load that file. When no runnable implementation or deferred item remains, finish all item outcomes, set `Phase: finish-ship`, and load that phase before verification or shipping.

**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-todo add` — not by leaving it in prose for the close to remember.

### Step 5. Implementation phase

Before any item dispatch, capture the source state and build the schedule once:

1. In git, record `HEAD` and run `{{SKILL_DIR}}/bin/pln-scheduler snapshot --repo <root> --out <plan-dir>/dirty-start.tsv`. Outside git, record `non-git` and a header-only dirty snapshot; non-git execution is always serial in the original directory.
2. **With one pending item, write its one-node artifact directly and skip this step** — there is no order to derive, no cohort boundary to place, and the lease is the item's own declared write set, so a fresh frontier worker answers a question with one possible answer while the user waits. Otherwise spawn a fresh `judgment`-profile/high-effort worker on `{{SKILL_DIR}}/src/workers/execution-schedule.md` in `implementation-items` mode. Give it the whole adopted plan, source state, dirty snapshot, `<plan-dir>/schedule-nodes.tsv`, evidence/result paths, and a 4096-byte envelope. This worker inherits the hosting model and owns dependency, cohort-boundary, dirty-overlap, and write-lease judgment. It decides order, what each worker may write, and where one worker keeps its context across consecutive items — never concurrency, which no longer exists here.
3. Validate its bounded envelope, then run `{{SKILL_DIR}}/bin/pln-scheduler build` on `schedule-nodes.tsv` to create `<plan-dir>/run-manifest.tsv`. A malformed graph gets one fresh scheduling retry, then falls back to a fresh sequential worker per item. Unknown dependencies or leases serialize; they never become guessed independence.

**The dashboard's `## To-do items` section names what this run takes, and every id in it is claimed here, before the first dispatch.** A plan adopted before that section existed carries no field to read; declare the items in this turn and claim them the same way. One `{{OUTPUT_ROOT}}/bin/pln-todo claim --id <id> --run <plan-dir name>` per item: the helper checks the collision and records the holder in the item's own record under one lock, so a second run in this tree reads the item as taken instead of taking it too. Write each attempt's result back beside its declared id as the attempt is made, not later: `claimed`, or refused with what the helper actually printed — the holder from `HELD_BY`, or, when the refusal names no holder, the collision the check reported. The helper records the holder under its lock and returns, so an id left with no result is an attempt whose outcome nobody knows; read the item's own record to settle it rather than recalling what happened. The claimed set is the only set this run may check off at the close. Leave a refused item in the to-do list rather than working it anyway.

The manifest is local coordinator-owned recovery state. It records source root/HEAD and dirty snapshot plus every node's dependencies, leases, cohort/context policy, serial position, execution, worktree, requested/actual profile/model/effort, handle, status, handoff, result, commit, and integration order. Execution is always `original` and the worktree is always the source tree; both columns are kept so a manifest written by an earlier release still verifies. `PLAN.md` remains the user-facing durable outcome record; workers edit neither file. On restart, run `pln-scheduler verify`, reconcile every manifest worktree/commit/result/handoff against the tree and dashboard, and use `pln-scheduler recover` for nonterminal nodes. A missing handle is recoverable from the item, handoff, and retained worktree; contradictory HEADs, duplicate ownership, missing partial state, or a manifest/tree disagreement fails closed.

`pln-scheduler ready` is the only dispatch list. **Run `{{OUTPUT_ROOT}}/bin/pln-scheduler ready` before composing any message in this phase**, and read its answer as the check it is: a non-empty result names a node that is dispatchable now, so the dispatch call goes first and the message comes after it. An empty result does not by itself end the turn — the terminal-state audit still decides that, since a node held back by a blocker prints nothing here. Nodes remain individual items. Reuse a worker only when the manifest marks the next contiguous direct-dependency node in the same cohort as `reuse`; after the current item has a validated result and an item-level commit/checkpoint, send a new one-item assignment through the host's native continuation surface. Never hand a worker two uncheckpointed items in one turn. **A cohort ends where the work stops being the same work**, and the schedule worker records why each one ends where it does; length follows from those boundaries rather than setting them. Every unmarked node, and every subsystem, risk, skill, repository, malformed-output, unexpected-write, conflict, corrected-premise, or context-exhaustion boundary, gets a fresh worker. Reusing a worker is worth doing wherever the boundaries allow it: the alternative is a fresh context that re-reads the plan, the root instructions and every mandated skill before it can start, which on one observed run was some three thousand lines per worker.

**Items run one at a time, in the working tree the coordinator was given.** There is no wave, no isolated lane, and no worktree for the coordinator to create. `pln-scheduler` emits one node per wave and `ready` names one item; a second name never appears to be dispatched beside the first.

This is a reversal, and the reason is worth carrying. Concurrency here was bought with a `git worktree add --detach` per isolated node, which is a bare checkout: no installed dependencies, no environment file, no database, no port block. Every worker then rebuilt that for itself, and none of it is anything git tracks — so no write lease could describe it and no dirty snapshot could protect it. One observed four-item run left thirty databases and 3.2 GB of worktrees on the user's machine, spent a whole scheduled item repairing dependency state another worker had broken, and then executed the three items serially anyway because the runner it had chosen could not safely overlap. It paid every cost of isolation and collected none of it.

Leases keep their whole job and gain weight: they bound what a worker may write in the user's own tree, and the coordinator validates each diff against them. Before every integration run `pln-scheduler check-dirty` with all leases already integrated or about to integrate, and verify the worker changed nothing outside its lease. Leases include generated outputs, lockfiles, configuration, migrations, tests, and shared effects — not just the most obvious source file.

**The environment is settled before the first dispatch, and no worker ever builds one.** Workers run in the environment they are handed and treat a missing one as a blocker (see `{{SKILL_DIR}}/src/workers/item-implementation.md`). If the project's own instructions say how a working environment is produced — a named setup script, a documented bootstrap — the coordinator follows them once, here, before any item work, because those instructions bind it. Absent that, the environment is the directory the run was launched in, exactly as the user left it. An item whose only product is reconstructed environment state is not an item: fail that node rather than checkpointing it, and say what was missing.

**Whoever moves the tree re-syncs it.** When an integrated item changes dependency declarations, the coordinator brings the environment back in step with the tree it just changed — an install that is not permitted to alter the lockfile — before releasing the next item. That is a coordinator action at integration, attributed to no item and appearing on no dashboard. A worker that finds the tree's lockfile ahead of what is installed says so and stops rather than fixing it.

<!-- pln:include step5-orchestration -->

Each one-item assignment points the worker at `{{SKILL_DIR}}/src/workers/item-implementation.md` and supplies `PLAN.md`, item number, project root, exact worktree and write lease, cohort context (`fresh` or a checkpointed predecessor to continue), mandated-learning note, `commit owner: coordinator`, handoff path, evidence path, result path, requested/actual judgment routing, and a 2048-byte envelope budget. Do not paste the contract into the brief. On success, validate its `RESULT_FILE` through `bin/pln-read-envelope --root <artifact-root> --max-bytes 2048 <result-file>` before checkpointing, where `<artifact-root>` is the plan directory when workers write beneath it and the run's artifact directory when the plan directory sits outside the repository. The root is what the envelope reader confines the result to, so it has to be the directory the worker could actually write. Missing, empty, malformed, out-of-root, oversized, or lease-violating results fail the node and force a fresh boundary; none is treated as success.

The coordinator alone updates `PLAN.md`, creates item commits/checkpoints by explicit leased path, advances manifest state, and integrates. Before checkpointing, require the result's qualitative surface balance to name added surface, reused/consolidated/replaced/retired surface, retained behavior with its repository-native pre/post comparison evidence, and evidence for retained duplication or compatibility (`none` is valid in each category; retained behavior is `not applicable` when no removal, replacement, or consolidation occurred). Validate that account, the worker's cited evidence, and the bounded item diff against the adopted system-fit outcome: new parallel ownership must be supported, directly caused consolidation/retirement must be inside the lease, and every simplifying mutation must carry the complete `Safety disposition` from `{{SKILL_DIR}}/src/workers/behavior-preservation.md` with `admit`, every conjunct `pass`, and non-empty rerunnable evidence, then rerun the same admitted behavior suite on the actual pre-change and post-change sources under equivalent conditions. A missing or malformed disposition, or missing, flaky, incomparable, implementation-coupled, or uncertain evidence, retains the surface or blocks; unrelated cleanup or numeric deletion/size targets fail validation. The plan's full repository gauntlet remains the final regression floor after item checkpoints. A missing or contradicted account fails the node and forces a fresh correction boundary; if correction would cross a blocker threshold, enter the blocker phase instead of checkpointing.

**An out-of-scope discovery in a validated result is the coordinator's to file, and it is filed at that item's checkpoint.** Work the worker found and could not do inside its item — a fix in a surface no item owns, an upstream change, anything that would need an item of its own — goes into the to-do list with `{{OUTPUT_ROOT}}/bin/pln-todo add`, with `--source` naming this run and the item it surfaced in. Do it before releasing dependents, not at the close: a discovery that waits is a discovery held in the result file alone, and the result files go when the plan directory does. Workers never write the to-do list themselves, for the same reason they write neither `PLAN.md` nor the manifest — one writer, so a cohort's successive workers cannot file the same discovery twice under two ids. Filing it is not adopting it: it never becomes work this run does.

**Marking a claimed to-do item is the coordinator's at that same checkpoint**, and it follows what landed rather than what was planned: `pln-todo mark --state "[x]"` only when every part of the item landed, `--state "[-]"` otherwise, with what remains readable as sub-items in its detail file. Sub-items the item work turned up go in with `--add-sub-item` and need no permission, including ones the run discovered were needed and then did. An item this run never claimed is not marked here whatever the work revealed about it.

Nodes checkpoint and integrate in the manifest's topological/item order, which under linear execution is the order they ran. A checkpoint is committed by explicit leased path. Never integrate partial work, stage with `git add -A`, or allow two workers to own git in one working tree. After every item integration, update that item's PLAN detail/dashboard and manifest before continuing a cohort handle or releasing dependents. **That last write closes the item boundary, not the turn:** once the commit, checkpoint, integration, dashboard edit and to-do list call have all returned, the next thing in the turn is the next dispatch call, and prose about it comes after that call. A status sentence composed in its place ends the turn instead, leaving the run idle at a node that was ready to go.

The orchestrator breaks silence to the user only when a subagent returns `BLOCKED:` (interactive default), or when the user interrupts. If the user asks a new design question mid-implementation, treat it as a blocker: pause, decide, update the plan, then continue the blocked worker through the host's native follow-up surface. Don't quietly improvise or skip ahead to a new worker.
### Auto-mode behavior

Auto mode applies only to **Step 5 (implementation phase)**. It does not stop immediately for a blocker: leave the blocked item's partial work in place, record the handoff/status in the manifest, mark its dependents `waiting`, and continue with the next item whose dependencies are satisfied and whose lease does not touch the blocked item's. Nothing later in integration order crosses the blocker. Resolve blockers at the end, recompute readiness from the manifest, and continue. Never label a dependency wait as deferred work.

It does NOT bypass:

- The Step 2 skeleton gate ("Continue?").
- The Step 3 interview phase: every per-item question must still be asked and answered.
- The Step 4 master-plan approval gate: explicit adoption is always required before implementation begins.
- The four blocker thresholds: a subagent still stops and hands off on any of them. Auto mode only changes whether the orchestrator surfaces the blocker now or defers it.

Delegated mode is the only thing that bypasses the first and third of those, and it does so because the user adopted the plan in advance (see Delegated mode). The two modes compose without cancelling each other: a run in both still stops for delegated mode's pre-implementation short list, and auto mode still defers blocker questions to the end-of-run review rather than surfacing them live.

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
