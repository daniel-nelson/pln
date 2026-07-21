A fix agent writes, so it gets `workspace-write` — and `--add-dir` for the plan directory whenever `REVIEW.md` sits outside the git root, or its status updates silently fail:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/fix-1.brief.md" \
  --out   "$RUN/fix-1.out" \
  --sandbox workspace-write \
  --cd "$(git rev-parse --show-toplevel)"
```

Record the `THREAD_ID` of each cluster against that cluster — a blocked cluster resumes on it, and it is the only way to continue without redoing the work already in the tree.

When a cluster returns, check `git status` shows the files it said it changed, then commit them **by name** with the co-author trailer — never `--amend`, never `--no-verify`, never `git add -A`. One commit per cluster, message `fix: review findings — {cluster summary}`. The agent could not commit; `.git` is read-only to it. Write the commit hash against each of that cluster's findings in `REVIEW.md`, then start the next cluster.

If a cluster returns `BLOCKED:`, follow the same shape `/pln` uses: surface the one question as prose, record the answer in `REVIEW.md` against the finding, then resume that cluster's own agent (`--resume "$THREAD_ID"`, a short brief carrying the answer, a **new** `--out` path) rather than spawning a replacement. Nothing gets committed for a half-finished cluster. If the resume comes back `STATUS=error` the thread is gone, which is not a failed run: spawn a fresh agent pointed at `REVIEW.md`, the answer, and the uncommitted diff, and tell it to build on what is already in the tree.
