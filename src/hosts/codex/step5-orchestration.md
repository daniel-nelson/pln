Once the master plan is adopted, the main session becomes a **thin orchestrator**. It does not do item work itself. It walks the pending items in order, spawning one fresh-context agent per item and waiting for it to finish before starting the next: later items build on earlier commits, so the working tree has to be in its post-item-N state before item N+1 starts. There is no parallelism here, and none is wanted.

The orchestrator's whole job is: spawn the item's agent, wait for it, read its result, record the outcome in `PLAN.md`, commit the finished item, move on — and, only on a blocker, ask the user and resume that item. Spawning is done with Codex's native multi-agent tools (see Spawning a fresh-context agent), so the child's reasoning stays in its own context and only its final message reaches yours; by never reading code or editing files, the orchestrator stays light enough to carry the whole run, and every item still gets a blank slate.

**Set up the run once**, before the first item. Briefs are scratch, and they go outside the repository so they can never end up in a commit:

```bash
RUN="${TMPDIR:-/tmp}/pln-<plan-slug>"; mkdir -p "$RUN"; echo "$RUN"
```

Then tell the user, in one short message: implementation is starting, it runs item by item without stopping, and the only interruption will be a blocker — naming whichever mechanism is actually spawning the items:
- **On the native path:** they can watch any item live in Codex's own agent view — the native subagents show their activity there, and reading it costs the orchestrator's context nothing.
- **On the nested-`codex exec` fallback:** say why (the native multi-agent tools were unavailable — switched off, or too old a Codex to have them), and that the watch target is instead `tail -f "$RUN/item-<N>.out.events"`, the nested agent's event stream, not Codex's own agent view.

**The loop.** For each item, in order:

1. Read `PLAN.md`'s dashboard and build the pending-item list fresh from the status at the end of each row (skip ⏸ deferred / 🚫 dropped / ✅ done). This list is the source of truth for what still needs to run, not a count the orchestrator remembers from earlier in the conversation — a re-invocation after an interruption (a crashed session, a restarted host) rebuilds it from the file instead of guessing where it left off, so an already-✅-done item never gets spawned again.
2. Mark the item 🟦 in progress in `PLAN.md`, replacing the status at the end of its dashboard row. The row and its number stay as they are.
3. Write that item's subagent brief (below) to `$RUN/item-<N>.brief.md`. A heredoc is the way to write it without fighting the shell over quoting, and the file is also what you edit and re-send if the item has to be respawned.
4. Spawn the agent on that brief, following every rule in Spawning a fresh-context agent: `spawn_agent` with the brief's contents as its message and a fresh (`fork_turns: "none"`) context, in `workspace-write`. Keep the handle it returns against the item — a blocker resumes that handle, and it is the only way to continue an item without redoing its work. (Where the native tools are unavailable, the same section's fallback spawns the agent through `pln-codex-agent` instead; record the `THREAD_ID` in place of the handle.)
5. Wait on the child in the `wait_agent` loop until it reports a final status. A final status of `errored`, or a `completed` with an empty final message, means the run failed; report which and stop the loop. An empty result is never "the agent found nothing to do".
6. Otherwise read the child's final message. That text is the agent's result, and the only thing that reaches your context.
7. On a normal (non-`BLOCKED:`) result: check `git status` shows the files the agent said it changed, then commit them **by name** — never `git add -A`, which would sweep in unrelated work — with the co-author trailer. The agent did not commit; that is the orchestrator's job. Mark the item ✅ done with the commit hash in `PLAN.md`, `close_agent` the finished child, and continue. An item that legitimately changed nothing (a decision-only or doc-only item) is marked done with no hash.
8. On a `BLOCKED:` result: follow the blocker protocol below, starting by writing the item's handle into the handoff file the agent named. Nothing is committed for a partial item.

When the list is exhausted, move to Step 6.
