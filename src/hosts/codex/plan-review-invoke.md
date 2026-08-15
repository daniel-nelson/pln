A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn one fresh (`fork_turns: "none"`) agent per same-model roster slot. Each assignment names its broad, specialist, or adversarial role, points at that role's brief, and assigns a distinct findings path. Independent slots may run concurrently. Wait through `wait_agent`, consulting `list_agents` when status matters; accept only final `RESULT_FILE=<that path>` pointers.

**Alongside the peer.** `spawn_agent` returns as soon as each child starts, so an R3 peer call may run before the `wait_agent` mailbox loop. Read only its fixed metadata; the merge worker reads raw results. Sequential execution is also valid when the shell call cannot overlap.

Where native multi-agent tools are unavailable, fall back to one read-only nested helper call per roster brief:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
