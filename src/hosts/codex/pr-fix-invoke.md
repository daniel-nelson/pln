A fix agent writes, so it runs in the orchestrator's `workspace-write` sandbox, which native subagents inherit. Spawn one per cluster with `spawn_agent` on a fresh (`fork_turns: "none"`) context, one at a time, waiting through the `wait_agent` mailbox loop before starting the next (see Spawning a fresh-context agent). Keep the returned agent identity against the cluster — a blocked cluster gets another turn through `followup_task` on that identity.

Where the native multi-agent tools are unavailable, fall back to the nested-`codex exec` helper — `workspace-write`, plus `--add-dir` for the plan directory whenever `REVIEW.md` sits outside the git root, or its status updates silently fail — and record its `THREAD_ID` in place of the handle:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/fix-1.brief.md" \
  --out   "$RUN/fix-1.out" \
  --sandbox workspace-write \
  --cd "$(git rev-parse --show-toplevel)"
```

When a cluster finishes, check `git status` shows the files it said it changed, then commit them **by name** with the co-author trailer — never `--amend`, never `--no-verify`, never `git add -A`. One commit per cluster, message `fix: review findings — {cluster summary}`. The agent did not commit; that is the orchestrator's job. Write the commit hash against each of that cluster's findings in `REVIEW.md`, then start the next cluster.

If a cluster returns `BLOCKED:`, follow the same shape `/pln` uses: surface the one question as prose, record the answer in `REVIEW.md` against the finding, then start another turn on that idle cluster agent with `followup_task`, carrying the answer and handoff path (on the fallback, `--resume "$THREAD_ID"`, the same short brief, and a **new** `--out` path). Nothing gets committed for a half-finished cluster. If continuation genuinely fails — the fallback thread is gone (`STATUS=error`), or the native agent identity no longer exists — spawn a fresh agent pointed at `REVIEW.md`, the answer, and the uncommitted diff, and tell it to build on what is already in the tree.
