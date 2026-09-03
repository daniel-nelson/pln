A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn one fresh (`fork_turns: "none"`) agent per same-model roster slot. Each assignment names its broad, specialist, or adversarial role, points at that role's brief, and assigns a distinct findings path. Independent slots may run concurrently. Wait through `wait_agent`, consulting `list_agents` when status matters; accept only final `RESULT_FILE=<that path>` pointers.

**Alongside the peer.** `spawn_agent` returns as soon as each child starts, so dispatch an R3 peer call *before* entering the `wait_agent` mailbox loop, not after it: a peer sent out once the readers have been awaited costs the sum of both rather than the slower of the two, which is the whole reason the slot runs beside them. Read only its fixed metadata; the merge worker reads raw results. Where the shell call genuinely cannot overlap, run it sequentially and say which happened.

Where native multi-agent tools are unavailable, fall back to one read-only nested helper call per roster brief:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
