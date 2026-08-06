A reviewer only reads, so it is held to reading by its brief (see Spawning a fresh-context agent — a native subagent inherits the orchestrator's sandbox and can't be given a read-only one of its own). Spawn it with `spawn_agent` on a fresh (`fork_turns: "none"`) context, handing it the same brief file the peer would have been given — point the message at `$RUN/plan-review.brief.md` and tell it to read that file in full and follow it. Wait in the `wait_agent` loop until it reports a final status, then read its final message: that text is the reviewer's findings and the only thing that reaches your context.

**Alongside the peer.** The seam is the wait, and it is already there: `spawn_agent` returns as soon as the child starts, so the peer's shell call (step 4) goes between the spawn and the `wait_agent` loop, and its five lines are read once the child reaches a final status. That costs the slower reader rather than the sum of the two, and it is an ordering of calls this fragment already makes rather than new machinery — but it has not been reproduced on this host, so if the shell call has to complete before the loop can start, that sequential order is fine: the review is the same, it just costs both.

Where the native multi-agent tools are unavailable, fall back to the nested-`codex exec` helper, read-only, on the same brief file:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/plan-review.brief.md" \
  --out   "$RUN/plan-review.agent.out" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when the plan directory is not under that working root, or the reviewer cannot open the `PLAN.md` its brief names. Give it its own `--out` path, and read `$RUN/plan-review.agent.out`; never read `EVENTS_FILE`, the reviewer's whole reasoning trace, which is what spawning it was meant to keep out of here.
