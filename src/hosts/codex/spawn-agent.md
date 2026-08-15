A fresh-context worker is a **native Codex subagent**. Use the collaboration surface exposed in the current session: `spawn_agent`, `wait_agent`, `list_agents`, `followup_task`, `send_message`, and `interrupt_agent`. Do not pin a feature generation or invent aliases that are not exposed.

**Spawn.** Call `spawn_agent` with the complete brief as `message` and `fork_turns: "none"`. Store the returned agent ID/canonical task name against the plan item or review cluster. A fresh fork isolates conversational context while sharing the coordinator's filesystem and sandbox. The brief is the child's whole spec, so it names the plan, item/cluster, worker contract, mandated skills, commit owner, paths, and result budget.

**Wait and read.** `wait_agent` is a bounded mailbox wait, not the child's return value. Use long waits and repeat after quiet timeouts; check `list_agents` when status matters. Completion/failure notifications deliver the agent's final status and message to the coordinator. Accept only the expected non-empty pointer/envelope after final status. A failed agent or an empty final message is a failed run, never an empty finding set.

**Continue and steer.** A worker that returned `BLOCKED:` is idle. Start another turn on that same agent with `followup_task`, carrying the user's answer and handoff path, then return to the wait loop. While an agent is still running, `send_message` supplies a course correction without starting a separate turn. Use `interrupt_agent` only for an actual stop/steer request; persist the interruption first and integrate nothing unfinished. These are distinct contracts: do not substitute a historical resume or close tool name.

**Concurrency and the shared tree.** Native agents are in-session workers; the nested-CLI OAuth token race does not constrain them. Parallelize only callers that have already proved independence and disjoint write leases. Otherwise keep the current sequential order. A read-only reviewer inherits the coordinator's sandbox and is held to reading by its brief. Native children share working files, so the coordinator validates leases and commits by explicit path; it never stages unrelated changes.

**Commit ownership.** Codex children do not own git checkpoints. They edit/verify, update their assigned evidence/result artifacts, and return; the coordinator validates the bounded result and commits only the finished item's or cluster's explicit paths. There is no close step on the current collaboration surface.

**When native collaboration is unavailable — the fallback.** An older or disabled host may have no `spawn_agent`. Disclose the switch and call `{{SKILL_DIR}}/bin/pln-codex-agent` on the same brief. The helper owns stdin delivery, timeout, non-empty enforcement, API-key unsetting, event capture, thread-id extraction, and sandbox selection:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/item-3.brief.md" \
  --out   "$RUN/item-3.out" \
  --sandbox workspace-write \
  --cd "$(git rev-parse --show-toplevel)"
```

Only exit 0 plus `STATUS=ok` and a non-empty `RESULT_FILE` succeeds. Keep `THREAD_ID`; resume fallback blockers with `--resume "$THREAD_ID"`, a short answer brief, and a new `--out` path. If the thread is gone, start a fresh fallback worker on the handoff and existing diff. Never read `EVENTS_FILE` into coordinator context and never use `resume --last`. Nested CLI calls stay serial because *they*, unlike native agents, can race on shared OAuth state. The same guarded helpers are the subprocess boundary used by `pln-peer` for cross-provider work; native same-provider agents never bypass that helper's consent and authentication policy.
