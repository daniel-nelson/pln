A fresh-context worker is a **native Codex subagent**. Use the collaboration surface exposed in the current session: `spawn_agent`, `wait_agent`, `list_agents`, `followup_task`, `send_message`, and `interrupt_agent`. Do not pin a feature generation or invent aliases that are not exposed.

**Spawn.** Call `spawn_agent` with the complete brief as `message` and `fork_turns: "none"`. Store the returned agent ID/canonical task name against the plan item or review cluster. A fresh fork isolates conversational context while sharing the coordinator's filesystem and sandbox. The brief is the child's whole spec, so it names the plan, item/cluster, worker contract, mandated skills, commit owner, paths, and result budget.

**Wait and read.** `wait_agent` is a bounded mailbox wait, not the child's return value. Use long waits and repeat after quiet timeouts. A quiet `wait_agent` timeout is not evidence that the child is still running: immediately call `list_agents`, consume any completion/failure notification already in the mailbox, and then either process the completed child or wait again. Completion/failure notifications deliver the agent's final status and message to the coordinator. Accept only the expected non-empty pointer/envelope after final status. A failed agent or an empty final message is a failed run, never an empty finding set.

**Keep the parent turn alive.** A child completion cannot start a new coordinator turn after you send the final response. While any native child is running—or any accepted implementation/review/fix/CI work remains—commentary may report progress, but a final response is forbidden. Immediately before any proposed final response, call `list_agents` and reconcile every known child. If one is running, return to `wait_agent`; if one completed, consume and act on it. Never describe work as continuing autonomously and then end the parent turn.

**Explicit across-turn persistence.** When the user explicitly asks for persistence across turns toward a verifiable endpoint—for example, “I am going to sleep; work through completion and open the green PR”—and this Codex session exposes `get_goal`/`create_goal`, inspect the current goal and create one at the start of that unattended run when none is active. Its objective names the plan/run artifact, requested ship endpoint, and required proof; it has no invented token budget. A matching active goal is reused. An unrelated active goal or absent goal tools does not become a question or permission gate: the manifest and wait loop remain the fallback. The goal never replaces the parent-turn wait loop, expands authority, bypasses plan approval, or converts a genuine user-owned blocker into an answer. Mark it complete only after the requested endpoint is actually reached.

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
