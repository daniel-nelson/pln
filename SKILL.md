---
name: pln
description: Personal multi-item planning workflow. Two distinct phases — first an interview that resolves every per-item question into a complete master plan, then (only after the master plan is approved as a whole) an implementation phase that walks the items one at a time. No interleaving: implementation never begins while questions are still open. Plans live at `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` relative to the session CWD. Trigger explicitly via `/pln <task>`, or auto-engage when the user says things like "make a plan", "let's tackle this in steps", "work through these", or pastes a numbered list of items to address. Universal — works in any repo. NEVER use the AskUserQuestion tool.
---

# pln — personal planning workflow

You are running the user's personal planning skill. Read every section of this file before starting, then execute. The user has tuned this workflow over many sessions; treat the rules as load-bearing.

## When to engage

Engage automatically when the user:

- Types `/pln <task>` (explicit invocation).
- Says "make a plan", "let's tackle this in steps", "work through these", "go through these one at a time", or similar.
- Pastes a numbered or bulleted list of items they want addressed.

If the user gives a single small task, do **not** engage — just do the work. The skill is for multi-item or multi-step workflows.

## Hard constraints (no exceptions)

- **Never use the `AskUserQuestion` tool.** The user has lost answers to it before — accidentally hitting Escape (above the backtick) cancels the entire question and registers all queued answers as "user declined to answer." All questions go through plain assistant text output. The user types answers as plain chat messages.
- **Ask exactly one question per turn.** Never bundle sub-questions. If a topic has natural sub-parts, ask the first, wait, ask the next.
- **Initial plan is always written before any work begins.** No matter how small the task, the user sees the proposed plan first.
- **Interview before implementation, always.** All per-item questions are resolved in the interview phase (Step 3) and folded into the master plan. Implementation (Step 5) does not begin until the *entire* master plan has been shown and approved. Never propose-then-implement an item in isolation while later items still have open questions — that is the failure mode this rule exists to prevent.
- **Per-item commits use the `Co-Authored-By: Claude <model-id> <noreply@anthropic.com>` trailer.** Never `--amend`, never `--no-verify`. If a hook fails: fix the issue, re-stage, create a new commit.

## Style

All rules in this section apply to every message the skill produces.

### Inline code

Wrap file names and shell commands in backticks. e.g., `CLAUDE.md`, `package.json`, `pnpm build:spec`, `cargo test`. Never bare.

### Sequences (proposed processes / ordered steps)

Numbered with `1.`, single sentence each, no bold. Use this style whenever you're showing the user a process you intend to follow — not when you want them to choose.

```
The skill discovers verification commands by:

1. Read `CLAUDE.md` / `AGENTS.md` for a completion rule.
2. Inspect `package.json` / `Cargo.toml` / `pyproject.toml` scripts and pick conventional names like `build`, `lint`, `test`.
3. If still ambiguous, ask the user once and save the answer to memory keyed by repo.
```

### Discrete option choices

Lowercase letter + close-paren + single space + bolded label + em-dash + short description. Use this style whenever the user must pick one of N alternatives.

```
When does verification run?

a) **Lightweight per-item, full at end** — type-check / lint after each item, specs only at task completion.
b) **Full only at end** — no per-item checks, single gauntlet at task end.
c) **Full only at end + on-demand mid-stream** — same as (b) plus user can request "run the gauntlet now" any time.
```

### Recommended option marker

When one option is the assistant's recommendation, prefix its bolded label with `[recommended] ` (square brackets, single trailing space, **inside** the bold span). Square brackets — angle brackets get treated as HTML by Claude Code's renderer and disappear, leaving an orphan space and breaking column alignment.

```
a) **[recommended] Full only at end** — no per-item checks, single gauntlet at task end.
b) **Lightweight per-item, full at end** — type-check / lint after each item, specs only at task completion.
```

Exactly one space after `a)`, `b)`, `c)`. The `[recommended] ` prefix lives inside the bold span — never break alignment by varying the post-paren whitespace.

### Binary "adopt as written / change?" questions

Plain prose, no letters. e.g., "Adopt this as written, or change it?"

### Bullets vs. numbers — visual distinction

- **Hyphen bullets** = "here's a flat list" (definitions, criteria, conditions). Not for choices.
- **`1.` numbered** = "here's a sequence I propose" (ordered process).
- **`a) **Bold** —`** = "pick one of these" (options).

The visual distinction must be obvious at a glance. Don't mix styles within a single list.

### Echoing recorded decisions

Before asking the next question, echo back what was just recorded in **one short line**. Lets the user catch a misrecorded answer immediately. Examples:

- *"Q5 recorded: mix-conditional question style; never AskUserQuestion."*
- *"Q12b recorded: lightweight per-item plus full gauntlet at end."*

## Defer / drop / think-offline signals

Three intents the user can express in any phrasing:

- **defer** — come back later this session. The skill circles back automatically at the end of the per-item loop, before final verification.
- **drop** — don't ask again, not relevant.
- **think-offline** — the user will go consider it and come back in a future session.

Common vocabulary: `defer`, `skip for now`, `come back to this`, `parking it`, `drop`, `not relevant`, `n/a`, `think about it`, `let me sit with it`, `offline`. Don't literal-match — infer the intent from natural phrasing.

## The workflow (sequential steps)

Steps 1–7 run in order, top to bottom. The skill has **two distinct conversational phases** separated by an explicit approval gate:

- **Interview phase** (Step 3) — questions only, no code changes, no commits. Walks every item end-to-end, captures decisions in the master plan.
- **Master-plan approval gate** (Step 4) — show the complete master plan, get a single yes-to-the-whole.
- **Implementation phase** (Step 5) — silent execution, one item at a time. No more discussion questions; only mid-item-discovery interruptions per the threshold rules.

Implementation NEVER begins while items still have open per-item questions. If the user redirects mid-interview ("just go do item 1 now"), gently note that the rest of the interview comes first — the whole point of the two-phase split is to avoid the "answer Q1, implement, then ask Q2" antipattern.

Cross-cutting concerns (mid-item discovery, auto-mode behavior, spinoffs, continuous learning + memory) are described in the next section.

### Step 1. Pre-flight

Before producing the initial plan, do all of:

1. Read `CLAUDE.md` and `AGENTS.md` at the project root and any nested ones the task touches. Surface any mandated rules (e.g., "invoke psychic-skill first") and persistent TODOs (e.g., a Matchmaker-scoping reminder) at the top of the eventual `PLAN.md`.
2. Auto-invoke any skill the project explicitly mandates (e.g., `psychic-skill` for Dream/Psychic projects). Document the auto-invocation in the plan.
3. Read relevant memories from `~/.claude/projects/<project>/memory/` to inform the initial plan.
4. Detect Dream/Psychic context — `@rvoh/dream` or `@rvoh/psychic` in `package.json`, presence of a `psy` CLI, or `CLAUDE.md` requiring `psychic-skill`. Cache this — it gates the learning-capture cross-cutting concern below.
5. Discover verification commands:
   1. Read `CLAUDE.md` / `AGENTS.md` for a completion rule or "before pushing" section.
   2. If silent there, inspect `package.json` / `Cargo.toml` / `pyproject.toml` scripts and pick conventional names like `build`, `lint`, `test`, `spec`.
   3. If still ambiguous, ask the user once and save the answer to memory keyed by repo.

### Step 2. Write the initial plan skeleton

Create `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` (relative to the session CWD, not necessarily the git root). Slug derived from the task — short, hyphenated, lowercase. Use today's date.

This is a *skeleton* — items are one-line summaries on the dashboard, detail sections are stubs. Open per-item questions go into the dashboard's **Open questions** section so they're visible from the top. The interview phase (Step 3) is what fills in the detail sections.

Plan layout — top-of-file dashboard followed by per-item detail sections:

```markdown
# <Task title> — <YYYY-MM-DD>

## Status

- [ ] 1. <one-line summary> — pending
- [ ] 2. <one-line summary> — pending
- ⏸ 3. <one-line summary> — deferred → ./item-3-<slug>.md
- [x] 4. <one-line summary> — done (commit <hash>)
- 🚫 5. <one-line summary> — dropped

Status legend: ⬜ pending · 🟦 in progress · ✅ done · ⏸ deferred · 🚫 dropped

## Pre-flight findings

- Mandated rules: <e.g., "psychic-skill invoked per CLAUDE.md">
- Persistent TODOs to surface: <e.g., "Matchmaker-scoping reminder">
- Verification commands: `pnpm build:spec`, `pnpm lint`, `pnpm uspec`, `pnpm fspec`

## Open questions

- (none yet)

## Verification

- (not yet run)

## Spinoffs

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

Items in the dashboard are one-line summaries. Detail sections are stub-brief at this point — they fill in during the per-item loop with Decision, Commit, Open questions, Discoveries, Discussion as the conversation unfolds.

After writing the skeleton, **stop**. Show the user the dashboard (not the whole file) and prompt: "Plan written to `<path>`. Continue?" If the user answers in the affirmative, begin the interview phase (Step 3).

### Step 3. Interview phase

This is a **questions-only** phase. No file edits to the project, no migrations, no commits, no code changes. Only `PLAN.md` is written to (to record decisions as they come in).

Walk every item, in order, gathering whatever the implementer would need to know to do the work cold. For each item:

1. Read enough surrounding code to propose a concrete approach (file paths, generator commands, model/serializer changes, controller surface, front-end consumers, spec updates). Reading is fine; editing is not.
2. State the proposed approach in 1–6 short bullets. Surface the genuine choices as a) / b) / c) options per the Style section.
3. Ask **one** discrete question at a time. Wait for the answer. Echo the recorded answer in one short line. Move to the next question.
4. Update the item's detail section in `PLAN.md` after each answered question — the file becomes the durable record so nothing is lost if context compacts.
5. When all questions on the item are answered, write the item's detail section in final form (Decision, exact steps, files touched, generator commands, verification).
6. Move to the next item. Repeat until every item has a written final-form detail section *or* is marked ⏸ deferred / 🚫 dropped.

Cross-item interactions are normal during the interview. If answering item N's question forces a change to item M's detail (already written), update M in place and tell the user one short line: "Item M revised to match: <one-line summary>."

When the interview is done, every item's section reads like a brief implementation spec. There should be no "we'll figure this out when we get there" left.

### Step 4. Master-plan approval gate

Show the user the **complete master plan** as a single artifact:

- Print the dashboard (status list).
- Print each item's detail section, in order.
- End with one binary prompt: "Adopt this master plan as written, or change it?"

This is the only place implementation-blocking approval lives. Possible responses:

- *Adopt as written* — proceed to Step 5.
- *Change X* — make the change in `PLAN.md`, re-show the affected section(s), re-prompt the same binary question. Loop until the user adopts.

Do not enter Step 5 without an explicit adoption signal.

### Step 5. Implementation phase

Items execute one at a time, **without further design discussion**. The master plan is the spec. For each item, in order:

1. Update item status to 🟦 in progress.
2. State the action in one short sentence ("Implementing item N: <one-line>").
3. Execute the steps recorded in the item's detail section.
4. Run lightweight per-item verification (type-check + lint, no specs). If it fails: fix, re-stage, new commit (never amend).
5. If the item produced code, commit with the co-author trailer. If the item was decision-only or doc-only, no commit — the plan file already records it.
6. Update the item section: actual commit hash, any discoveries, status ✅ done (or ⏸ deferred / 🚫 dropped).
7. Move to the next item.

The implementation phase is mostly silent. The only times to break silence:

- A mid-item-discovery threshold fires (see Cross-cutting concerns) — pause, surface, get a decision, then continue. Update the master plan to reflect the decision before resuming.
- An item's recorded step is wrong (e.g., a generator command doesn't exist) — pause, propose the corrected step, get a one-line confirmation, update the plan, continue.
- The user interrupts.

If the user asks a *new* design question mid-implementation, treat it the same way — pause, decide, update the plan, resume. Don't quietly improvise.

### Step 6. Deferred-item revisit

After the last item completes, before final verification: walk back through any items marked ⏸ deferred (and any deferred sub-questions). For each, ask the user: "Revisit now, push to a future session, or drop?"

### Step 7. End-of-task verification + wrap-up

1. Run the full verification gauntlet once. Update the dashboard's Verification section with pass/fail per command. Full stdout/stderr stays in the terminal — do not persist to a file.
2. If anything fails: it's now a new item. Don't paper over. Either fix-and-rerun, or spawn a spinoff if the failure is out-of-scope.
3. Final message to the user: one or two sentences. What changed and what's next. Reference `PLAN.md`'s path.

## Cross-cutting concerns

These apply throughout the per-item loop — they are not sequential steps.

### Mid-item discovery

Pause and surface to the user when any of:

- The discovery requires a change **outside** the item's stated scope (different file, different layer, different system).
- The discovery means the original plan **won't work as written** and a real choice has to be made.
- The discovery has **irreversible consequences** (data migration, schema change, anything that touches shared infra).
- The discovery reveals an assumption was wrong that **other items also depend on**.

Otherwise, fix inline silently or with a one-line note in the item's section. No interruption.

### Auto-mode behavior

Auto mode applies only to **Step 5 (implementation phase)**. It lets the implementer run items end-to-end without stopping between items.

It does NOT bypass:

- The Step 2 skeleton gate ("Continue?").
- The Step 3 interview phase — every per-item question must still be asked and answered.
- The Step 4 master-plan approval gate — explicit adoption is always required before implementation begins.
- The four mid-item-discovery thresholds — those still pause execution.

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

After writing the spinoff, update the parent `PLAN.md`: mark the item ⏸ deferred and add a link in the Spinoffs section.

### Continuous learning + memory capture

While running the per-item loop:

- **Memory:** the moment something surfaces that fits an auto-memory category (user role, feedback, project fact, reference), write a new memory immediately to `~/.claude/projects/<project>/memory/` per the standard memory rules. Don't batch for end-of-task.
- **Dream/Psychic learnings (conditional):** if pre-flight detected Dream/Psychic, the moment a learning surfaces that's not in `/psychic-skill`, append it to `<project-root>/WHAT_I_LEARNED_ABOUT_PSYCHIC_<YYYY-MM-DD>.md`. The filename is **fixed** — not parameterized by topic. Content scope is **narrow**: only learnings about Dream ORM and the Psychic web framework that are missing from `/psychic-skill`. The user is co-author of Dream/Psychic and uses this file to feed back to the skill maintainer. Outside Dream/Psychic projects, skip this entirely.

## Plan file conventions

- Directory: `./plans/<YYYY-MM-DD>-<slug>/`. Path is relative to the session CWD (where Claude was launched), not the git root.
- Main plan file is always `PLAN.md`.
- Spinoff files use a meaningful slug, e.g., `item-7-first-date-restructure.md`.
- Verification output is **not** persisted — pass/fail summary in the dashboard is enough.

## Tracker contents in `PLAN.md`

Top-of-file dashboard carries:

- **Status** — per-item one-line entries with status icon, summary, and (if done) commit hash.
- **Pre-flight findings** — mandated rules, persistent TODOs, verification commands discovered.
- **Open questions** — questions asked but not yet answered (deferred sub-questions live here so nothing is lost).
- **Verification** — pass/fail per command at task end.
- **Spinoffs** — links to any spinoff plan files.

Per-item detail sections carry:

- Status.
- Decision (one or two sentences of *what* + *why*).
- Commit hash if any.
- Discoveries (mid-item findings worth recording).
- Open questions.

## Failure modes to watch for

- **Interleaving interview and implementation** — the failure mode this skill exists to prevent. If you catch yourself about to start implementing item N while item N+1 still has open questions, stop. The interview phase runs to completion *before* any implementation begins. The exception, and only the exception, is mid-item discovery during Step 5: surface, decide, update the plan, resume.
- **Asking item-2 questions while implementing item-1** — same antipattern, different shape. If you're inside Step 5 and you find yourself about to ask a design question that wasn't in the master plan, stop. That question belonged in Step 3. Pause execution, surface it as a master-plan amendment, get the user's decision, update the plan, then resume.
- **Bundling sub-questions** — if you catch yourself writing "...also..." or "Two sub-questions..." in a question, stop. Ask the first; wait; ask the next.
- **Missing the `[recommended]` marker** — when there's a clear recommendation, mark it. The user explicitly relies on this signal.
- **Forgetting to echo** — every recorded answer gets a one-line echo before the next question. The user catches misrecordings this way.
- **Plowing through auto mode** — auto mode is not license to skip the per-item gate or the four mid-item-discovery thresholds. Pause for any of the four conditions.
- **Inventing a verification gauntlet** — if you didn't read `CLAUDE.md` / `AGENTS.md` and find the actual commands, ask the user. Don't run guessed commands.
- **Forgetting the `WHAT_I_LEARNED_ABOUT_PSYCHIC_*.md` step in Dream/Psychic projects** — pre-flight should have detected the context; if so, the file write is built into the workflow.
- **Persisting verification output to a file** — don't. Dashboard summary only.
- **Using `<recommended>` (angle brackets) instead of `[recommended]` (square brackets)** — angle brackets get eaten by the renderer.
