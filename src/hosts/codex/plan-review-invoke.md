A reviewer only reads, so it runs read-only (see Spawning a fresh-context agent), and it gets the same brief file the peer would have been handed:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/plan-review.brief.md" \
  --out   "$RUN/plan-review.agent.out" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when the plan directory is not under that working root, or the reviewer cannot open the `PLAN.md` its brief names. Give it its own `--out` path: the peer's `--out` from the step above may already hold a partial answer, and the helper truncates whatever it is given.

Read `$RUN/plan-review.agent.out`; that text is the reviewer's findings and the only thing that reaches your context. Never read `EVENTS_FILE` — it is the reviewer's whole reasoning trace, which is what spawning it was meant to keep out of here.
