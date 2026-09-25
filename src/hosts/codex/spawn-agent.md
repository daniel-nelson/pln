A fresh-context worker is a **native Codex subagent**. Codex gives each session one of two multi-agent tool sets, chosen by its model, and the session's own tool list shows which: each column below is headed by a tool only its set has. The table maps each job to both; every other passage names only the job.

| Job | Set with `close_agent` | Set with `followup_task` |
|---|---|---|
| Spawn fresh | `spawn_agent`, brief as `message`, `fork_context: false`; keep `agent_id` | `spawn_agent`, brief as `message`, a `task_name`, `fork_turns: "none"`; keep the name |
| Probe status | `wait_agent` on targets: its status map | `list_agents` |
| Continue an idle or finished child | `send_input`; `resume_agent` first if closed | `followup_task` |
| Steer a running child | `send_input`; `interrupt: true` redirects at once | `send_message`; `interrupt_agent` redirects at once |
| Free a finished child's slot | `close_agent`, once its final status is consumed | nothing: a finished child holds no slot |
| Stop a child, when the user asked | `close_agent` | `interrupt_agent` |

Name only tools the session exposes, and never pin a feature generation.

**Spawn.** Store the child's identity against the plan item or review cluster. A fresh child isolates conversational context while sharing the coordinator's filesystem and sandbox. The brief is the child's whole spec, so it names the plan, item/cluster, worker contract, mandated skills, commit owner, paths, and result budget.

**Wait and read.** `wait_agent` is a bounded mailbox wait, not the child's return value. Use long waits and repeat after quiet timeouts. A quiet `wait_agent` timeout is not evidence that the child is still running: a completion that landed between waits arrives in the mailbox, so read the mailbox, then either process the completed child or wait again. Accept only the expected non-empty pointer/envelope after final status. A failed agent or an empty final message is a failed run, never an empty finding set.

**A child's write that the host's approval reviewer declined means its brief gave it a path outside its sandbox. It is not a question for the user.** Re-issue the assignment with evidence and result paths beneath the run's worker artifact directory. Never ask the user to re-authorize work the plan or ledger already records.

**A running child is never closed.** Only a final status — completed or errored — ends a child's work. A quiet timeout, a wait back before its timeout, an unanswered nudge, an evidence file not yet written (the child writes it last) or minutes on the clock is not a stall; it is a child still working. A stop the user asked for is persisted first, then made. Neither a stop nor freeing a slot is done to a child whose last observed status is running.

**Reconcile the native tree.** A child completion cannot start a new coordinator turn after you send the final response. Apply the shared Active-turn lifecycle at every wait and phase boundary: immediately before a proposed final response, probe every child the manifest still records as running and read the mailbox. If one is running, wait again; if one completed, consume and act on it. Only the outline phase's lifecycle exception, preflight and the checkpoint wave, may be left running. Do not convert a quiet timeout into a status-only final response.

**Continue and steer.** A worker that returned `BLOCKED:` is idle: continue it with the user's answer and handoff path, then return to the wait loop. Persist an interruption before steering or stopping a child, and integrate nothing unfinished.

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
