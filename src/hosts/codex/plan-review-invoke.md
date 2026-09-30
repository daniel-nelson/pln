A reviewer only reads, so its assembled brief holds it to reading (a native subagent inherits the coordinator's sandbox). Spawn one fresh agent per same-model roster slot. Each assignment names its role, points at that role's brief, and assigns a distinct findings path. Independent slots may run concurrently. Wait through the mailbox loop and probe status as Spawning a fresh-context agent says; accept only final `RESULT_FILE=<that path>` pointers.

**The broad reviewer before the roster.** On a first pass, spawn the classifier and the broad reviewer together, before any roster exists. When the classifier returns, free its slot where a finished child keeps one; then spawn the roster's other slots — never a second broad — and wait for the broad reviewer along with them before the merge check.

**Alongside the peer, and it works.** `spawn_agent` returns as soon as each child starts, so dispatch the R3 roster's peer call *before* entering the `wait_agent` mailbox loop, not after it: a peer sent out once the readers have been awaited costs the sum of both rather than the slower of the two, which is the whole reason the slot runs beside them. Read only its fixed metadata; the merge worker reads raw results.

Verified on a real Codex run, 2026-09-03: three same-model readers spawned at 31.49m, 31.58m and 31.65m, the peer's shell call went out at 31.78m as a background cell, the peer returned at 41.75m and the readers were awaited after it at 42.36m. The round cost the slower of the two rather than their sum. This fragment said nothing about whether the overlap worked until that run existed; it does now.

**A peer already out of quota is not called again in the same review.** When the peer returned `REASON=<peer>-usage-limit` in an earlier round of this plan review's bounded re-review, do not call it: the round runs without it. A later plan review, and the PR review, call the peer again, since the limit resets.

Where native multi-agent tools are unavailable, fall back to one read-only nested helper call per roster brief:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "<plan-dir>/evidence/plan-review.brief.md" \
  --out   "<plan-dir>/results/plan-review.agent.result" \
  --sandbox read-only \
  --cd "$(git rev-parse --show-toplevel)"
```

Add `--add-dir "<plan dir>"` when needed. Read only the captured final pointer, never `EVENTS_FILE`; the reviewer writes findings to its assigned evidence path.
