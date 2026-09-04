A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn one fresh (`fork_turns: "none"`) agent per same-model roster slot. Each assignment names its broad, specialist, or adversarial role, points at that role's brief, and assigns a distinct findings path. Independent slots may run concurrently. Wait through `wait_agent`, consulting `list_agents` when status matters; accept only final `RESULT_FILE=<that path>` pointers.

**Alongside the peer, and it works.** `spawn_agent` returns as soon as each child starts, so dispatch an R3 peer call *before* entering the `wait_agent` mailbox loop, not after it: a peer sent out once the readers have been awaited costs the sum of both rather than the slower of the two, which is the whole reason the slot runs beside them. Read only its fixed metadata; the merge worker reads raw results.

Verified on a real Codex run, 2026-09-03: three same-model readers spawned at 31.49m, 31.58m and 31.65m, the peer's shell call went out at 31.78m as a background cell, the peer returned at 41.75m and the readers were awaited after it at 42.36m. The round cost the slower of the two rather than their sum. This fragment said nothing about whether the overlap worked until that run existed; it does now.

Where native multi-agent tools are unavailable, fall back to one read-only nested helper call per roster brief:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
