# pln — improvements surfaced while running a real plan (2026-07-02)

## Context

During a `/pln` session in the Dream ORM repo, the implementation phase spawned each
item's subagent through the **Agent** tool, not the **Workflow** tool. The user asked
why. Investigation showed the honest answer is a distribution bug, not missing skill
content.

## Root cause: the running copy was stale, and the updater can't see that

Version inventory at time of investigation:

| Location | VERSION | Role |
| --- | --- | --- |
| `github.com/daniel-nelson/pln` `main` | 1.7.0 | source of truth |
| `~/.agents/skills/pln` | 1.7.0 | what `/pln-update` checked → "up-to-date" |
| `~/.claude/skills/pln` | **1.5.1** | **what Claude Code actually loaded this session** |
| `~/.codex/skills/pln` | absent | — |

The Workflow-spawn directive was added in **1.7.0** (`2da2f39`, "Spawn
implementation-phase items via Workflow for live visibility"). The loaded copy was
1.5.1, which predates it by two releases (1.6.0, 1.6.1, 1.7.0) and still reads:

> 3. Spawn a subagent (general-purpose agent type) with the brief below.

So the agent followed its instructions faithfully — they just weren't the current
ones. `/pln-update` reported "up-to-date" because 1.5.1's own change added
`~/.agents/` to the *front* of the search path; the updater resolved that directory
(already 1.7.0) and never looked at `~/.claude/skills/pln`, which is the directory
Claude Code loads from.

## Improvements (ranked)

### 1. `/pln-update` must reconcile *every* install dir, not the first match

The bug that hid the staleness: the updater stops at a priority-ordered first hit.
Because `~/.agents/` sorts first and happened to be current, the check passed while a
second, host-critical copy (`~/.claude/skills/pln`) stayed two versions behind.

- Enumerate all known install dirs (`~/.claude/skills/pln`, `~/.agents/skills/pln`,
  `~/.codex/skills/pln`, …) and update **each** to the remote version.
- Report per-directory results, e.g. `~/.claude 1.5.1 → 1.7.0 ✓ · ~/.agents 1.7.0 =`.
  A single scalar "up-to-date" is what masked the split.

### 2. The update-check preamble should compare the dir the *current host* loads

The in-skill `UPGRADE_AVAILABLE` preamble check is the last line of defense: if it had
compared the copy this host loads (`~/.claude/skills/pln`, 1.5.1) against remote
(1.7.0), it would have fired `UPGRADE_AVAILABLE 1.5.1 1.7.0` at the top of this
session and the run would have used Workflow. Instead it resolved the same
priority-ordered first dir and stayed silent. Anchor the preamble's comparison to the
directory the skill is being *read from* for this invocation, not a global first match.

### 3. Self-identify version + load path at invocation

Have the preamble echo the loaded copy's `VERSION` and absolute path (e.g.
`pln 1.5.1 — ~/.claude/skills/pln`). A stale load then shows up in the transcript
immediately, instead of being inferable only after the user notices wrong behavior.

---

The remaining notes refine the 1.7.0 change itself, so they hold even once the stale
copy is fixed.

### 4. Scope the Workflow wrapper honestly — visibility, not parallelism

1.7.0 wraps each item in a single-agent Workflow script (one `agent()` call). That buys
live `/workflows` visibility with no orchestrator-context cost, which is the stated
goal. It does **not** exploit Workflow's parallel fan-out or multi-stage pipelines —
and it shouldn't, because pln's items are inherently sequential (item N+1 builds on item
N's commit). Worth stating in the skill so a future contributor doesn't "upgrade" the
single-agent wrapper into a pipeline expecting a speedup that the sequencing constraint
forbids.

### 5. Record *why* it stays one-agent-per-item: the interactive blocker protocol — **resolved differently in 1.12.0**

A multi-item Workflow *script* cannot run pln's interactive blocker hand-off. That
protocol has the orchestrator surface a `BLOCKED:` question to the user one at a time
and resume a fresh subagent with the answer — a running Workflow script can't pause for
user input mid-run and resume inline. The one-agent-per-item wrapper sidesteps this
(each item is its own run; the orchestrator stays in the loop between items). This is a
load-bearing reason, not an incidental choice; documenting it prevents a collision if
someone later tries to fold the whole item list into one script.

**Update:** the premise "can't fold the whole item list into one script" turned out to
be only half true. A script genuinely can't pause in place mid-run — but it *can* stop
(return early) and be resumed later via `resumeFromRunId` with different `args`, and the
completed prefix of `agent()` calls replays from cache while the run continues past the
return point. Confirmed empirically (see item 6). So 1.12.0 does fold the whole item
list into one script for *both* modes; the reason from #5 became the shape of the
solution (stop-and-resume) rather than a reason to keep two mechanisms.

### 6. Auto mode is where a real Workflow *pipeline* would pay off — **resolved in 1.12.0, broader than originally scoped**

In auto mode, blockers are deferred (stashed, surfaced at end review) rather than asked
interactively — so the constraint in #5 disappears. That is the one mode where the whole
item list could run as a single deterministic Workflow pipeline, gaining resumability
(the `resumeFromRunId` cache) and one progress tree for the run. Consider branching:
single-agent-per-item for interactive mode, one pipeline for auto mode.

**Confirmed and implemented, unified across both modes instead of branching.** Ran a
live empirical test: a two-step Workflow script invoked with `args: {stopEarly: true}`
returned after step 1 only; re-invoking the same `scriptPath` with `resumeFromRunId` and
`args: {stopEarly: false}` produced both steps' results, and `journal.jsonl` showed no
new `started` event for step 1 in the resumed run — only step 2 was spawned live, step 1
replayed from cache. That's the mechanism interactive mode needs too (item 5's revised
conclusion), so instead of branching Step 5 into two shapes, 1.12.0 uses one script per
run for both modes: interactive mode stops the script on a blocker and resumes it with
the user's answer folded into `args`; auto mode just never stops. One real gotcha
surfaced during the test and is now documented as a failure mode: `args` arrives inside
a Workflow script as a JSON string, not a parsed object, regardless of how it's passed
to the tool — scripts that branch on it need `JSON.parse(args)` first.

### 7. Sequence off `PLAN.md` status, not notification arrival order — **resolved in 1.12.0**

1.7.0 waits for item N's task-notification before spawning N+1. Since a notification
re-invokes the orchestrator, key "what runs next" off the durable `PLAN.md` status
(next ⬜ pending item) rather than an in-memory cursor, so a re-invocation can't
double-spawn an item.

**Update:** with the whole run now inside one script, sequencing between items is no
longer the orchestrator's concern at all — it's just the script's own `await` order,
and `resumeFromRunId` already durably tracks which `agent()` calls completed. What
remained of this concern is the orchestrator's own re-invocation (not the Workflow
run's): if the orchestrator session itself restarts and no longer holds a runId, it must
build the pending-item list by reading `PLAN.md`'s status column fresh, not from
anything it remembers, so it doesn't re-spawn an already-✅-done item. 1.12.0's Step 5
does this explicitly as the first action in "Building the run."
