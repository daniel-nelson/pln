A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn one fresh (`fork_context: false`) agent per same-model roster slot. Each assignment names its broad, specialist, or adversarial role, points at that role's brief, and assigns a distinct findings path. Independent slots may run concurrently. Wait through `wait_agent`, whose status map is the only status probe; accept only final `RESULT_FILE=<that path>` pointers.

**Alongside the peer, and it works.** `spawn_agent` returns as soon as each child starts, so dispatch an R3 peer call *before* entering the `wait_agent` mailbox loop, not after it: a peer sent out once the readers have been awaited costs the sum of both rather than the slower of the two, which is the whole reason the slot runs beside them. Read only its fixed metadata; the merge worker reads raw results.

Verified on a real Codex run, 2026-09-03: three same-model readers spawned at 31.49m, 31.58m and 31.65m, the peer's shell call went out at 31.78m as a background cell, the peer returned at 41.75m and the readers were awaited after it at 42.36m. The round cost the slower of the two rather than their sum. This fragment said nothing about whether the overlap worked until that run existed; it does now.

**When the adversarial slot substitutes.** Spawn the same-model adversarial substitute the moment the peer's no-send or failure is known, not once the readers return. Learn of a failure early by checking the peer's shell call between short waits rather than inside one long wait: every failing peer observed so far returned within a minute. Only if that spawn is refused for capacity, or the session already states a slot count the running readers fill, spawn it into the first slot a finished reader frees. The stated count includes the coordinator, so at the default of four, three readers fill it and the substitute usually takes the first freed slot. Where a finished child keeps its slot until it is closed, close a finished reader to free it; never a running one. The substitution line may say once that `features.multi_agent_v2.max_concurrent_threads_per_session` in the user's own `~/.codex/config.toml` raises that stated count, letting the substitute run beside the readers — theirs to set; pln never writes it.

**A peer already out of quota is not called again in the same review.** When the peer returned `REASON=<peer>-usage-limit` in an earlier round of this plan review's bounded re-review, do not call it: spawn the substitute with the other readers in the first dispatch. A later plan review, and the PR review, call the peer again, since the limit resets.

Where native multi-agent tools are unavailable, fall back to one read-only nested helper call per roster brief:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
