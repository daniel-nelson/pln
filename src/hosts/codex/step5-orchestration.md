Once the master plan is adopted, the main session becomes a **thin orchestrator**. It does not do item work itself. It walks the pending items in order, spawning one fresh-context agent per item and waiting for it to return before starting the next: later items build on earlier commits, so the working tree has to be in its post-item-N state before item N+1 starts. There is no parallelism here, and none is wanted.

The orchestrator's whole job is: spawn the item's agent, read its result, record the outcome in `PLAN.md`, commit the finished item, move on — and, only on a blocker, ask the user and resume that item. By never reading code or editing files, and by keeping every agent's reasoning trace in a file instead of its own context, the orchestrator stays light enough to carry the whole run, and every item still gets a blank slate.

Before starting, tell the user once: implementation is starting, it runs item by item without stopping, and the only interruption will be a blocker.

**The loop.** For each item, in order:

1. Read `PLAN.md`'s dashboard and build the pending-item list fresh from its status column (skip ⏸ deferred / 🚫 dropped / ✅ done). This list is the source of truth for what still needs to run, not a count the orchestrator remembers from earlier in the conversation — a re-invocation after an interruption (a crashed session, a restarted host) rebuilds it from the file instead of guessing where it left off, so an already-✅-done item never gets spawned again.
2. Mark the item 🟦 in progress in `PLAN.md`.
3. Spawn one fresh-context agent with that item's subagent brief (below) as its whole prompt, following every rule in Spawning a fresh-context agent — `< /dev/null`, a `timeout`, output to a file, thread id captured from the first event line. Keep the thread id with the item; a blocker needs it.
4. Read the result file. Empty means the call failed — say so and stop; it is not a silent success.
5. On a normal (non-`BLOCKED:`) result: verify the item's files changed as claimed, commit the completed item with the co-author trailer (the agent could not commit — `.git` is read-only to it), mark the item ✅ done with the commit hash in `PLAN.md`, and continue to the next item.
6. On a `BLOCKED:` result: follow the blocker protocol below. Nothing is committed for a partial item.

When the list is exhausted, move to Step 6.
