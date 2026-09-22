A fresh-context worker is a **native Codex subagent**. Use the collaboration surface exposed in the current session — on the current CLI that is `spawn_agent`, `wait_agent`, `send_input`, `resume_agent` and `close_agent`, and nothing else: no listing, follow-up, message or interrupt tool exists. Do not pin a feature generation or name a tool that is not exposed.

**Spawn.** Call `spawn_agent` with the complete brief as `message` and `fork_context: false`. Store the returned `agent_id` against the plan item or review cluster. A fresh child isolates conversational context while sharing the coordinator's filesystem and sandbox. The brief is the child's whole spec, so it names the plan, item/cluster, worker contract, mandated skills, commit owner, paths, and result budget.

**Wait and read.** `wait_agent` is a bounded mailbox wait, not the child's return value. Use long waits and repeat after quiet timeouts. A quiet `wait_agent` timeout is not evidence that the child is still running: a completion that landed between waits arrives as a `<subagent_notification>` in the mailbox, so read the mailbox, then either process the completed child or wait again. Accept only the expected non-empty pointer/envelope after final status. A failed agent or an empty final message is a failed run, never an empty finding set.

**A running child is never closed.** Only a final status — `completed` or `errored`, in `wait_agent`'s status map or the notification — ends a child's work. A quiet timeout, a `wait_agent` back before its `timeout_ms`, an unanswered nudge, an evidence file not yet written (the child writes it last) or minutes on the clock is not a stall; it is a child still working. `close_agent` releases a child whose final status is consumed (a finished child holds its concurrency slot until then); a stop the user asked for is persisted first, then closed. Neither is done to a child whose last observed status is `running`.

**Reconcile the native tree.** A child completion cannot start a new coordinator turn after you send the final response. Apply the shared Active-turn lifecycle at every wait and phase boundary: immediately before a proposed final response, `wait_agent` on every child the manifest still records as running and read the mailbox. If one is running, return to `wait_agent`; if one completed, consume and act on it. Do not convert a quiet timeout into a status-only final response.

**Explicit across-turn persistence.** When the user explicitly asks for persistence across turns toward a verifiable endpoint—for example, “I am going to sleep; work through completion and open the green PR”—and this Codex session exposes `get_goal`/`create_goal`, inspect the current goal and create one at the start of that unattended run when none is active. Its objective names the plan/run artifact, requested ship endpoint, and required proof; it has no invented token budget. A matching active goal is reused. An unrelated active goal or absent goal tools does not become a question or permission gate: the manifest and wait loop remain the fallback. The goal never replaces the parent-turn wait loop, expands authority, bypasses plan approval, or converts a genuine user-owned blocker into an answer. Mark it complete only after the requested endpoint is actually reached.

**Continue and steer.** A worker that returned `BLOCKED:` is idle. Start another turn on that same agent with `send_input`, carrying the user's answer and handoff path, then return to the wait loop; `resume_agent` first if it was closed. While an agent is still running, `send_input` supplies a course correction without starting a separate turn (`interrupt: true` redirects it at once). Persist an interruption before sending it, and integrate nothing unfinished.

**Concurrency and the shared tree.** Native agents are in-session workers; the nested-CLI OAuth token race does not constrain them. Parallelize only callers that have already proved independence and disjoint write leases. Otherwise keep the current sequential order. A read-only reviewer inherits the coordinator's sandbox and is held to reading by its brief. Native children share working files, so the coordinator validates leases and commits by explicit path; it never stages unrelated changes.

**Commit ownership.** Codex children do not own git checkpoints. They edit/verify, update their assigned evidence/result artifacts, and return; the coordinator validates the bounded result and commits only the finished item's or cluster's explicit paths.

**When native collaboration is unavailable — the fallback.** An older or disabled host may have no `spawn_agent`. Disclose the switch and call `{{SKILL_DIR}}/bin/pln-codex-agent` on the same brief. The helper owns stdin delivery, timeout, non-empty enforcement, API-key unsetting, event capture, thread-id extraction, and sandbox selection:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/item-3.brief.md" \
  --out   "$RUN/item-3.out" \
  --sandbox workspace-write \
  --cd "$(git rev-parse --show-toplevel)"
```

Only exit 0 plus `STATUS=ok` and a non-empty `RESULT_FILE` succeeds. Keep `THREAD_ID`; resume fallback blockers with `--resume "$THREAD_ID"`, a short answer brief, and a new `--out` path. If the thread is gone, start a fresh fallback worker on the handoff and existing diff. Never read `EVENTS_FILE` into coordinator context and never use `resume --last`. Nested CLI calls stay serial because *they*, unlike native agents, can race on shared OAuth state. The same guarded helpers are the subprocess boundary used by `pln-peer` for cross-provider work; native same-provider agents never bypass that helper's consent and authentication policy.
