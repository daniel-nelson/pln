A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn it with `spawn_agent` on a fresh (`fork_turns: "none"`) context. Point its compact assignment at `<plan-dir>/evidence/plan-review.brief.md` and assign `<plan-dir>/evidence/plan-review.agent.out` for its findings. Wait through `wait_agent`, consulting `list_agents` when status matters; accept only the final notification `RESULT_FILE=<that path>`, never findings pasted into the final message.

**Alongside the peer.** The seam is the wait, and it is already there: `spawn_agent` returns as soon as the child starts, so the peer's shell call (step 4) goes between the spawn and the `wait_agent` loop, and its five lines are read once the child reaches a final status. That costs the slower reader rather than the sum of the two, and it is an ordering of calls this fragment already makes rather than new machinery — but it has not been reproduced on this host, so if the shell call has to complete before the loop can start, that sequential order is fine: the review is the same, it just costs both.

Where the native multi-agent tools are unavailable, fall back to the nested-`codex exec` helper, read-only, on the same brief file:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
