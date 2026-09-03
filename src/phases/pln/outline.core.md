---
name: pln-phase-outline
---

# /pln phase: outline

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first outline action. It owns pre-flight, plan allocation, skeleton creation, the editable outline checkpoint, and the transition into interview. It does not own any item-level interview question or implementation.

Create `PLAN.md` with `Phase: outline` in its own top-level `## Phase` section before showing the dashboard. If the user edits scope, update the skeleton and keep `Phase: outline`. In normal and auto modes, missing confirmation leaves `Phase: outline`: do not infer confirmation from auto mode or start the interview, review, scheduling, or implementation. After the user accepts the displayed outline—or after delegated mode displays it—finish all outline writes, set `Phase: interview`, then read the mapped interview phase in full before its first action.

## The workflow (sequential steps)

Steps 1–8 run in order, top to bottom. The skill has two distinct conversational phases separated by an explicit approval gate:

- **Interview phase** (Step 3) — questions only, no code changes, no commits. Walks every item end-to-end, captures decisions in the master plan.
- **Plan review** (Step 3.5) — a reader who never saw the interview argues with the finished plan before the user is asked to adopt it. Still no code changes; only `PLAN.md` is written to.
- **Master-plan approval gate** (Step 4) — show the complete master plan, get a single yes-to-the-whole. Self-adopted in delegated mode, where that yes was given in advance.
<!-- pln:only claude -->
- **Implementation phase** (Step 5) — a fresh frontier scheduler builds item dependencies, short checkpointed cohorts, and isolated disjoint waves. A thin coordinator owns ledgers and integration; blockers continue through durable Agent/worktree state.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Implementation phase** (Step 5) — a fresh frontier scheduler builds item dependencies, short checkpointed cohorts, and isolated disjoint waves. A thin coordinator owns ledgers and integration; blockers continue through durable agent/worktree state.
<!-- pln:endonly -->

Implementation never begins while items still have open per-item questions. If the user redirects mid-interview ("just go do item 1 now"), note gently that the rest of the interview comes first; the point of the two-phase split is to avoid the "answer Q1, implement, then ask Q2" antipattern.

Cross-cutting concerns (mid-item discovery, auto-mode behavior, spinoffs, continuous learning + memory) are described in the next section.

### Step 1. Pre-flight

Before producing the initial plan:

1. **Bootstrap from root instructions only.** Read `CLAUDE.md` and `AGENTS.md` at the session's project root. Do not follow repository links or inspect nested instructions yet. Auto-invoke any skill those root files mandate; their rules govern the worker assignment. The research worker, not this context, finds nested instructions, persistent TODOs, and repository detail.
2. **Allocate the local run directory before research.** Derive today's short lowercase slug now.
   - **A location the project's own instructions name wins over both defaults below.** Step 1 has just read this project's `CLAUDE.md`/`AGENTS.md`; when they say where plan documents live — "plan docs live outside the repo at `~/Documents/<project>-plans/`" and the like — that is the answer, and the run directory is `<that path>/<YYYY-MM-DD>-<slug>/`. Expand a leading `~`, create the directory if it does not exist, and say in one line where the plan went. Adopt it only when it is a real directory (or can be made one) that is not the repository top level or an ancestor of it; a tracker, a URL, or a file is not a plan location, and neither is a path that cannot be written — in any of those cases say what was found and fall through to the defaults. This leg exists because the defaults below cannot express it: a project that keeps plans outside the repository deliberately, so that a worktree pruned or a branch deleted does not take an interview with it, otherwise reads as "not `./plans/`" and lands in the temporary directory, which is the one place the work is least safe. The follow-up queue already resolves this way, which is why a project can end up with its queue in the named location and its plan in `/tmp`.
   - In a git worktree, and with no such location named, use `./plans/<YYYY-MM-DD>-<slug>/`. Ensure `plans/` is present in the repository's `.git/info/exclude` (resolve it with `git rev-parse --git-path info/exclude`) before writing the directory. Never add this local artifact to `.gitignore`. Verify with `git check-ignore -v <plan-path>` and inspect `git status --porcelain`; the plan path must be ignored and the exclude operation must not add a tracked change. Preserve every pre-existing worktree change as user-owned.
   - Outside a git worktree, and with no such location named, create an external run directory with `mktemp -d "${TMPDIR:-/tmp}/pln-<YYYY-MM-DD>-<slug>.XXXXXX"`. Do not create a local `plans/` directory. This external directory is the plan directory and its `PLAN.md` is the durable path for the run. This is the last resort rather than the general "outside the repository" answer: it is cleared by the operating system, so a run that lands here says so in the same turn that creates it, naming the path.
   Create `evidence/` and `results/` beneath the plan directory.
3. **Settle where the follow-up queue lives, while the user is still here.** Run `{{OUTPUT_ROOT}}/bin/pln-queue init`. The helper owns the whole resolution — the project's own `pln/`, the shared git directory, a path the project's instructions declare, then create-and-ask — and reports `QUEUE_ROOT`, `RESOLVED_BY`, `CREATED`, `LOCATION_QUESTION`, `MIGRATION_OFFERED`, `DECLARED_TODO`, and a `NOTE=` line for every candidate it passed over. Read what it reports rather than repeating the search by hand, and relay each `NOTE=`: a `pln` that is a symlink, a submodule mountpoint, or someone else's directory is not adopted, and a fall-through nobody mentions is how a project ends up with two queues.
   - **`LOCATION_QUESTION=answered`** — an earlier run already answered it. Ask nothing.
   - **`RESOLVED_BY=instructions`** — the project's own instructions are the answer, so there is no location question. Record it once with `pln-queue init --answered`, and make the migration offer below.
   - **`RESOLVED_BY=created`, and the project's own instructions name a filesystem path in ordinary prose** — that is the instruction-file leg, and it is the one leg the helper cannot finish alone: it recognizes only the exact `pln-queue: <path>` declaration, while this step's bootstrap has already read this project's `CLAUDE.md`/`AGENTS.md`. A named directory is the root; a named file makes the directory containing it the root, and that file is never touched. Adopt it as below and make the migration offer, rather than asking. It is not adopted — and the question is asked instead, saying what was found — when it is the repository top level or an ancestor of it, when it is not a real directory, or when it holds something other than a queue. A tracker, and a location named only in the global instructions file, are not filesystem paths and never become a root: the global one is per-machine, and adopting it would give every repository on the machine one shared queue.
   - **Otherwise the question is owed, and this is the turn to ask it**, in a message of its own. Three answers, each with what it costs in one clause, because the differences are not guessable. Outside a git worktree only the third exists — there is no branch to commit to and no shared git directory, so the queue is created in the working directory or at a path they give and no question of tracking arises:
     - **(a) Committed in the repository** — `pln/` at the project root, tracked. It travels with a clone and reaches every worktree through the branch, and it appears in your diffs.
     - **(b) In the shared git directory** — `$(git rev-parse --path-format=absolute --git-common-dir)/pln/`. Every worktree of this repository reaches the same queue, and it is never committed and never in a diff; it does not survive a fresh clone.
     - **(c) Outside the repository** — a path they give. It survives worktrees and fresh clones and is easy to open; it does not travel with the repository, so teammates never see it. Say in the same turn that pln cannot find that path again by itself: it is found only once the user adds a `pln-queue: <path>` line to the project's `CLAUDE.md`/`AGENTS.md`, pln does not write that line, and until it exists the next run creates a second queue at the project root while the follow-ups already filed sit invisible.
   - **Applying an answer, or an adopted named location, leaves the queue at that root and nothing behind at any other.** For `pln/` at the project root, record it where it already sits: `pln-queue init --answered`. For every other root, `pln-queue init --root <path> --answered`, then move across anything already filed at the project root and remove what is left there — the project-root leg sits above every other, so a leftover shadows the answer on every later run.
   - **Verify (a), and only (a).** `git check-ignore -v <queue-root>` must match nothing; a rule the project already carries would make a committed queue silently an ignored one, which is the combination worktrees break. Say so plainly rather than proceeding if it matches. The probe does not apply to (b) or (c) — it exits non-zero for a path inside `.git` and fatals for one outside the repository, so under those answers it reports nothing and the question does not arise.
   - **When nothing can be created or written at whichever leg resolved it** — a regular file or a symlink named `pln`, a read-only or unwritable checkout, an unmounted path — the helper refuses with exit 3 and says what it found. Relay that, ask the question, and apply the answer at a root that works. When none does, say so plainly and carry every follow-up inline in the closing message instead. This is the failure path rather than a question, and an uncaught one is total silent loss of the work the queue exists to keep.
   - **When the root came from the project's own instructions**, by either route above, and they named a *file*, offer once, in a message of its own, to migrate what is in that file into the queue. The helper's `NOTE=` names that file when it resolved the root itself; under the other route you already read it. That is judgment work rather than parsing — what is one item, and what has gone stale — so it runs as ordinary agent work against the format below, with nothing to parse it and no subcommand that reads it. The file is read and never written: not rewritten in place, not appended to, not moved, whatever the answer and whatever gets migrated out of it. Either answer is recorded with `pln-queue init --migration-offered`; a declined offer is not re-asked. Skip the offer when `MIGRATION_OFFERED` already carries a date, and when the instructions named a directory, where there is nothing to migrate.
   - **`DECLARED_TODO` names a path and the queue resolved somewhere else** — the project's own `pln/` or the shared git directory won, as they always do, and the instruction leg was never reached. The declaration is still an answer to a different question: make the same migration offer, on the same terms, for the file it names. Nothing moves the queue — a location answered once is not re-asked, and the offer is about lifting what is in that file into the queue where it already sits. Without this, a project that answered "the shared git directory" could never be offered a to-do file it declared afterwards, because the earlier leg resolves on every later call.
4. **Dispatch mandatory pre-flight research.** Preflight is judgment work because it synthesizes repository evidence into the plan's scope; never route it to evidence/economy. Spawn a fresh read-only `judgment`-profile worker with `{{SKILL_DIR}}/src/workers/preflight-research.md`, the project root, task, future `PLAN.md` path, source `HEAD`/non-git state, `{{SKILL_DIR}}/bin/pln-config`, any record location the user named, `<plan-dir>/evidence/preflight.md`, and `<plan-dir>/results/preflight.txt`. Give it the 8192-byte ceiling. Its final message must be only the result pointer; read that file through the context-firewall helper and append the route to `routing.tsv`.
5. Use the validated envelope to fill Pre-flight findings with mandated rules, persistent TODOs, relevant repository shape and current behavior, likely touchpoints, verification commands, decision-record locations, and git state. The worker only locates decision records; it never summarizes them. If verification remains ambiguous, ask the user once and retain the answer for this repository. When no record location exists, Step 3's record check is skipped without comment.

The coordinator does not inspect manifests, memories, documentation trees, git history, nested instruction files, or source code in this step. If pre-flight evidence is incomplete, send a narrow follow-up worker across the same firewall instead of exploring inline.

### Step 2. Write the initial plan skeleton

Write `PLAN.md` at the run path allocated in Step 1: `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` in a git worktree, or the external temporary run directory otherwise.

This is a skeleton: items are one-line summaries on the dashboard, detail sections are stubs. Open per-item questions go into the dashboard's **Open questions** section so they're visible from the top. The interview phase (Step 3) is what fills in the detail sections.

Plan layout — top-of-file dashboard followed by per-item detail sections:

```markdown
# <Task title> — <YYYY-MM-DD>

## Phase

- outline

## Status

1. <one-line summary> — ⬜ pending
2. <one-line summary> — 🟦 in progress
3. <one-line summary> — ⏸ deferred → ./item-3-<slug>.md
4. <one-line summary> — ✅ done (commit <hash>)
5. <one-line summary> — 🚫 dropped

Status legend: ⬜ pending · 🟦 in progress · ✅ done · ⏸ deferred · 🚫 dropped

## Pre-flight findings

- Mandated rules: <e.g., "required skill invoked per CLAUDE.md">
- Persistent TODOs to surface: <e.g., "tenant-scoping reminder">
- Verification commands: `pnpm build:spec`, `pnpm lint`, `pnpm uspec`, `pnpm fspec`

## Open questions

- (none yet)

## Plan review

- (not yet run)

## Queue items

- (not yet declared)

## Ship

- (not yet decided)

## Reversals

- (none)

## Verification

- (not yet run)

## Spinoffs

- (none yet)

## Cross-item notes

- (none yet)

---

## Item details

### 1. <item title>

**Status:** pending

(Brief — fuller detail emerges during the per-item loop.)

### 2. <item title>

**Status:** pending

…
```

**One row shape, for all five states**: the number first, as the ordered list's own marker, then the summary, then the status at the end of the line. The number is the address every later step uses — the Step 4 gate's reply-by-number, a subagent's brief, a cross-item note — so it is a Markdown list number a client can reference rather than text nested inside a bullet.

Rows are never removed and numbers are never reused. An item that is dropped or deferred keeps its row and its number, with its status trailing; deleting it would shift every number after it and stale every reference already written down or already spoken.

Items in the dashboard are one-line summaries. Detail sections are stub-brief at this point; they fill in during the interview and the per-item loop with Decisions, Commit, Open questions, Discoveries, Dead ends, Artifacts as the work unfolds.

This checkpoint is the user's scope-editing surface: a chapter-outline view for understanding the whole shape and removing, adding, renaming, or reordering items while those changes are still cheap, before entering item-level discussion. It is distinct from Step 4's approval of the fully resolved plan before implementation.

After writing the skeleton, **stop**. In normal mode, show the user the complete dashboard (not the whole file), ask no item-level interview question in that turn, and perform no implementation. Prompt: "Plan written to `<path>`. Ready to start the interview?" Only an affirmative answer to the current outline begins the interview phase (Step 3). If the user changes the outline instead, update the skeleton before the interview starts, re-show the complete dashboard, and ask again.

In delegated mode there is nothing to ask: show the dashboard and go straight into Step 3 (see Delegated mode). Auto mode is not advance authorization: it grants neither this checkpoint confirmation nor master-plan adoption, and changes only Step 5 blocker handling after adoption (see Auto-mode behavior).
## Plan file conventions

- Where the project's instructions name a plans location, the directory is `<that path>/<YYYY-MM-DD>-<slug>/`. Otherwise, in a git worktree it is `./plans/<YYYY-MM-DD>-<slug>/`, relative to the session CWD rather than the git root; outside one, the external temporary run directory allocated in Step 1, and no local `plans/` directory.
- Main plan file is always `PLAN.md`.
- Spinoff files use a meaningful slug, e.g., `item-7-first-date-restructure.md`.
- Handoff files (written by a subagent at a blocker) use `<timestamp>-item-<N>-<slug>.md` in the plan dir. They are transient scratch: not committed, and deleted by the resuming subagent once the item completes. The durable record (the decision, the dead ends) folds into `PLAN.md`; the handoff file only bridges one blocked subagent to its replacement.
- `run-manifest.tsv`, `schedule-nodes.tsv`, and `dirty-start.tsv` are local coordinator-owned execution state. Together with `PLAN.md`, retained worktrees, results, and handoffs, they must recover the run without a surviving agent handle.
<!-- pln:only codex -->
- The orchestrator appends two things to a handoff file when it reads a `BLOCKED:` result: the blocked agent's handle (its thread id on the fallback), and — in auto mode — the label of the stash holding the partial work. The agent can write neither; it doesn't know its own handle, and touching `.git` is the orchestrator's job. Without them, an orchestrator that is restarted or compacted before the user answers has no way to continue the agent or find the work.
<!-- pln:endonly -->
- Verification output is **not** persisted; pass/fail summary in the dashboard is enough.

## Tracker contents in `PLAN.md`

Top-of-file dashboard carries:

- **Status** — one numbered row per item: the number, the summary, then the status icon at the end of the line and (if done) the commit hash. Rows are never removed and numbers never reused, so an item's number is permanent (see Step 2).
- **Pre-flight findings** — mandated rules, persistent TODOs, verification commands discovered.
- **Open questions** — questions asked but not yet answered (deferred sub-questions live here so nothing is lost).
- **Plan review** — one line per Step 3.5 round: which items it read, who read them, and what it turned up. The round the user is looking at is the last line, and the count is however many lines there are, so a re-showing gate and a resumed session both know how far the review got without reconstructing it from the conversation.
- **Queue items** — the follow-up-queue ids this run takes, or `none taken`. Written at adoption, so the run has to answer whether it takes any; amended at claim time with each id's claim result, and amended again at the close with each claimed id's outcome. It is the run's own record of what it took, and it never replaces the holder `pln-queue claim` writes into the item's own record, which is what `claim` and `check` read.
- **Ship** — the Step 4 adopt choice: `draft PR after implementation`, `PR after implementation`, or `implement only`, plus `PR base: <branch>` when a stacking override (item 4) applies and `Review: full|broad|none` under either PR-bearing value. Set once, at adoption, and read back by Step 8 rather than trusted from the conversation — a restarted or resumed session still knows what was decided.
- **Reversals** — one line per decision in this plan that overturns something already settled or already built: what it reverses, and where that was decided. `{{PLN_PR_CMD}}` reads it into the PR body, so a reversal reaches the branch's reviewer even when the user adopted the plan without reading it (see Delegated mode).
- **Verification** — pass/fail per command at task end.
- **Spinoffs** — links to any spinoff plan files.
- **Cross-item notes** — one line per fact more than one item turns on: a discovery a completed item makes that a later item needs (a constant to reuse, a field that changed, a trap not to repeat), and an interaction between items (a precedence order, a substitution several items make). An interaction is recorded here, not described inside each item — a subagent reads its own item and the dashboard, so two half-descriptions in two sections never get reconciled by anyone. Only what another item would get wrong without it, not every cross-reference: this is part of the dashboard every subagent already reads in full regardless of plan size, and it stays cheap only while it stays bounded.

Per-item detail sections carry:

- Status.
- Intent, constraints, and acceptance criteria — what "done" means, not how each line gets written.
- Decisions — each a *what* + *why*, tagged with its authority or its reversibility, and flagged if low-confidence (the flag is what puts it on the Step 4 gate's "worth a look" line). Recorded as overridable-when-reversible context, never as imperative steps. The ones the user made are marked as theirs — originated where they raised the substance, selected where they picked from options the agent wrote — and written in their words. See "How a decision is recorded" in Step 3.
- Commit hash if any.
- **Review findings** — what the plan-review merge worker corrected in this section, and what it flagged for the user instead.
- Discoveries (mid-item findings worth recording).
- **Dead ends / don't repeat** — approaches tried that failed, and why. A re-run after a blocker, or a later item, reads these so it doesn't retry a known dead end.
- **Artifacts** — files created or changed, with locations.
- Open questions.

Each item section must be self-contained: a blank-context subagent reading only the dashboard plus that one section must have everything it needs to execute the item. This is the same self-containment discipline applied to interview questions, now applied to item sections, because a subagent is exactly that blank-context reader.

<!-- pln:include queue-format -->
