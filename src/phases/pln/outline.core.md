---
name: pln-phase-outline
---

# /pln phase: outline

Read this file in full before the first outline action. It owns pre-flight, plan allocation, skeleton creation, the editable outline checkpoint, and the transition into interview. It does not own any item-level interview question or implementation.

Create `PLAN.md` with `Phase: outline` in its own top-level `## Phase` section before showing the dashboard. If the user edits scope, update the skeleton and keep `Phase: outline`. After the user accepts the displayed outline—or after delegated mode displays it—finish all outline writes, set `Phase: interview`, then read the mapped interview phase in full before its first action.

## The workflow (sequential steps)

Steps 1–8 run in order, top to bottom. The skill has two distinct conversational phases separated by an explicit approval gate:

- **Interview phase** (Step 3) — questions only, no code changes, no commits. Walks every item end-to-end, captures decisions in the master plan.
- **Plan review** (Step 3.5) — a reader who never saw the interview argues with the finished plan before the user is asked to adopt it. Still no code changes; only `PLAN.md` is written to.
- **Master-plan approval gate** (Step 4) — show the complete master plan, get a single yes-to-the-whole. Self-adopted in delegated mode, where that yes was given in advance.
<!-- pln:only claude -->
- **Implementation phase** (Step 5) — a thin orchestrator walks items sequentially with one fresh, named background Agent per item and `PLAN.md` as the spec. No more discussion questions; a blocker pauses the loop and continues that same Agent through `SendMessage`.
<!-- pln:endonly -->
<!-- pln:only codex -->
- **Implementation phase** (Step 5) — a thin orchestrator walks the items one at a time, spawning a fresh-context agent per item with `PLAN.md` as the spec. No more discussion questions; the only interruptions are a blocker threshold, which pauses the loop and resumes the blocked item.
<!-- pln:endonly -->

Implementation never begins while items still have open per-item questions. If the user redirects mid-interview ("just go do item 1 now"), note gently that the rest of the interview comes first; the point of the two-phase split is to avoid the "answer Q1, implement, then ask Q2" antipattern.

Cross-cutting concerns (mid-item discovery, auto-mode behavior, spinoffs, continuous learning + memory) are described in the next section.

### Step 1. Pre-flight

Before producing the initial plan:

1. **Bootstrap from root instructions only.** Read `CLAUDE.md` and `AGENTS.md` at the session's project root. Do not follow repository links or inspect nested instructions yet. Auto-invoke any skill those root files mandate; their rules govern the worker assignment. The research worker, not this context, finds nested instructions, persistent TODOs, and repository detail.
2. **Allocate the local run directory before research.** Derive today's short lowercase slug now.
   - In a git worktree, use `./plans/<YYYY-MM-DD>-<slug>/`. Ensure `plans/` is present in the repository's `.git/info/exclude` (resolve it with `git rev-parse --git-path info/exclude`) before writing the directory. Never add this local artifact to `.gitignore`. Verify with `git check-ignore -v <plan-path>` and inspect `git status --porcelain`; the plan path must be ignored and the exclude operation must not add a tracked change. Preserve every pre-existing worktree change as user-owned.
   - Outside a git worktree, create an external run directory with `mktemp -d "${TMPDIR:-/tmp}/pln-<YYYY-MM-DD>-<slug>.XXXXXX"`. Do not create a local `plans/` directory. This external directory is the plan directory and its `PLAN.md` is the durable path for the run.
   Create `evidence/` and `results/` beneath the plan directory.
3. **Dispatch mandatory pre-flight research.** Preflight is judgment work because it synthesizes repository evidence into the plan's scope; never route it to evidence/economy. Spawn a fresh read-only `judgment`-profile worker with `{{SKILL_DIR}}/src/workers/preflight-research.md`, the project root, task, future `PLAN.md` path, source `HEAD`/non-git state, `{{SKILL_DIR}}/bin/pln-config`, any record location the user named, `<plan-dir>/evidence/preflight.md`, and `<plan-dir>/results/preflight.txt`. Give it the 8192-byte ceiling. Its final message must be only the result pointer; read that file through the context-firewall helper and append the route to `routing.tsv`.
4. Use the validated envelope to fill Pre-flight findings with mandated rules, persistent TODOs, relevant repository shape and current behavior, likely touchpoints, verification commands, decision-record locations, and git state. The worker only locates decision records; it never summarizes them. If verification remains ambiguous, ask the user once and retain the answer for this repository. When no record location exists, Step 3's record check is skipped without comment.

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

In delegated mode there is nothing to ask: show the dashboard and go straight into Step 3 (see Delegated mode). Auto mode does not bypass this checkpoint; it changes only Step 5 blocker handling (see Auto-mode behavior).
## Plan file conventions

- In a git worktree, the directory is `./plans/<YYYY-MM-DD>-<slug>/`, relative to the session CWD rather than the git root. Outside a git worktree, use the external temporary run directory allocated in Step 1; do not create a local `plans/` directory.
- Main plan file is always `PLAN.md`.
- Spinoff files use a meaningful slug, e.g., `item-7-first-date-restructure.md`.
- Handoff files (written by a subagent at a blocker) use `<timestamp>-item-<N>-<slug>.md` in the plan dir. They are transient scratch: not committed, and deleted by the resuming subagent once the item completes. The durable record (the decision, the dead ends) folds into `PLAN.md`; the handoff file only bridges one blocked subagent to its replacement.
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
- **Ship** — the Step 4 adopt choice: `PR after implementation` or `implement only`, plus `PR base: <branch>` when a stacking override (item 4) applies. Set once, at adoption, and read back by Step 8 rather than trusted from the conversation — a restarted or resumed session still knows what was decided.
- **Reversals** — one line per decision in this plan that overturns something already settled or already built: what it reverses, and where that was decided. `/pln-pr` reads it into the PR body, so a reversal reaches the branch's reviewer even when the user adopted the plan without reading it (see Delegated mode).
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
