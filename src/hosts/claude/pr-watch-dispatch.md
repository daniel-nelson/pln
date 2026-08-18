**Watching without a blocking wait — the `Monitor` tool.** This host ships a background-monitor primitive purpose-built for exactly this: a poll loop that emits one line per state change and exits at a natural end, streamed back as notifications while the session's own turn stays free. Point it at a script that does the interval math and the `gh pr checks` (`glab` equivalent) polling above, and have it print exactly one line per event — a state change, a required check going red, or green — then exit once a terminal state is reached (`persistent: true`, since a slow CI run can outlast the tool's default timeout). If `Monitor` is somehow unavailable in this session's toolset, fall back to a `Bash` call with `run_in_background: true` running the same loop — still a native async primitive of this host, not a reimplementation of one.

Retain the native monitor/task handle and keep the same parent turn active until its terminal notification arrives. Background execution frees the coordinator to receive notifications; it does not authorize a status-only final response or defer pickup to a future user turn.

When the monitor's terminal line arrives:

- **Green** — undraft and record the duration as described above, then fire the completion notification.
- **Red** — build the finding, write it into `REVIEW.md`, then dispatch the one fix cluster as a fresh named background `Agent`, invoked and awaited exactly as `pr-fix-invoke` describes, including `SendMessage` blocker handling. Once it returns and its commit is pushed, start a fresh `Monitor` call for the next round — the loop is a new tool call each round, not one script trying to survive across fix commits.

Track the same-check streak and the `BLOCKED:` case across rounds in the orchestrator's own context (this session, not the monitor script) — that bookkeeping is what decides when to stop instead of starting another round.
