Once the master plan is adopted, the main session becomes a **thin orchestrator**. It does not do item work itself. It walks the pending items in order, spawning one fresh-context agent per item and waiting for it to return before starting the next: later items build on earlier commits, so the working tree has to be in its post-item-N state before item N+1 starts. There is no parallelism here, and none is wanted.

The orchestrator's whole job is: spawn the item's agent, read its result, record the outcome in `PLAN.md`, commit the finished item, move on — and, only on a blocker, ask the user and resume that item. By never reading code or editing files, and by keeping every agent's reasoning trace in a file instead of its own context, the orchestrator stays light enough to carry the whole run, and every item still gets a blank slate.

**Set up the run once**, before the first item. Briefs and transcripts are scratch, and they go outside the repository so they can never end up in a commit:

```bash
RUN="${TMPDIR:-/tmp}/pln-<plan-slug>"; mkdir -p "$RUN"; echo "$RUN"
```

Then tell the user, in one short message: implementation is starting, it runs item by item without stopping, the only interruption will be a blocker, and they can watch any item live with `tail -f "$RUN/item-<N>.out.events"` — that file is the agent's own event stream, and reading it costs the orchestrator's context nothing.

**The loop.** For each item, in order:

1. Read `PLAN.md`'s dashboard and build the pending-item list fresh from its status column (skip ⏸ deferred / 🚫 dropped / ✅ done). This list is the source of truth for what still needs to run, not a count the orchestrator remembers from earlier in the conversation — a re-invocation after an interruption (a crashed session, a restarted host) rebuilds it from the file instead of guessing where it left off, so an already-✅-done item never gets spawned again.
2. Mark the item 🟦 in progress in `PLAN.md`.
3. Write that item's subagent brief (below) to `$RUN/item-<N>.brief.md`. A heredoc is the way to write it without fighting the shell over quoting, and the file is also what you edit and re-send if the item has to be respawned.
4. Spawn the agent, following every rule in Spawning a fresh-context agent:

   ```bash
   "{{SKILL_DIR}}/bin/pln-codex-agent" \
     --brief "$RUN/item-<N>.brief.md" \
     --out   "$RUN/item-<N>.out" \
     --cd "$(git rev-parse --show-toplevel)"
   ```

   Add `--add-dir "<plan dir>"` when the plan directory is not under that working root, or the agent cannot write its own `PLAN.md` update. Record the `THREAD_ID` it prints against the item; a blocker resumes that thread, and it is the only way to continue an item without redoing its work.
5. If the helper exited non-zero, the run failed — timed out, errored, or wrote nothing. Report which, name `EVENTS_FILE` so the user can look, and stop the loop. An empty result is never "the agent found nothing to do".
6. Otherwise read `$RUN/item-<N>.out`. That text is the agent's final message.
7. On a normal (non-`BLOCKED:`) result: check `git status` shows the files the agent said it changed, then commit them **by name** — never `git add -A`, which would sweep in unrelated work — with the co-author trailer. The agent could not commit; `.git` is read-only to it. Mark the item ✅ done with the commit hash in `PLAN.md` and continue. An item that legitimately changed nothing (a decision-only or doc-only item) is marked done with no hash.
8. On a `BLOCKED:` result: follow the blocker protocol below, starting by writing the item's thread id into the handoff file the agent named. Nothing is committed for a partial item.

When the list is exhausted, move to Step 6.
