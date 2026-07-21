A fresh-context agent is a nested `codex exec` call: a new session, its own context, one result. Codex has no harness-run script to hold a loop, so the orchestrator runs the loop itself and spawns one call at a time.

```bash
_OUT="$(mktemp)"; _EVENTS="$(mktemp)"
env -u OPENAI_API_KEY timeout -k 10 3600 \
  codex exec "<the agent's whole brief>" \
    -C "$(git rev-parse --show-toplevel)" \
    -s workspace-write \
    --json -o "$_OUT" \
  < /dev/null > "$_EVENTS" 2>&1
```

Each part of that command prevents a failure that is otherwise silent:

1. **`< /dev/null` always.** Without it a non-TTY `codex exec` can wait forever on stdin.
2. **`timeout` always.** There is no built-in run timeout. Don't pass `--foreground`: the default puts the child in its own process group so the signal reaches the whole tree, not just the parent process.
3. **The result is the `-o` file, not the exit code.** An exec can exit 0 having written nothing. Treat an empty `$_OUT` as a failure and say so; never read it as "the agent found nothing to do".
4. **Redirect stdout and stderr to a file.** The JSONL event stream is the agent's reasoning trace; the whole point of spawning is to keep it out of the orchestrator's context. Read `$_OUT`, not `$_EVENTS`.
5. **Capture the thread id from the first event line** (`thread.started`) in `$_EVENTS` and keep it with the item. It is what makes a blocked item resumable. Never use `resume --last`, which races with any other Codex process.
6. **`env -u OPENAI_API_KEY`.** A stray key silently overrides the CLI's OAuth session and the call fails with a misleading `401`.
7. **`-s read-only`** instead of `workspace-write` for agents that only read (reviewers, verification runs that don't write artifacts).
8. **One call at a time.** Concurrent `codex` processes race on the shared OAuth token file, so spawns are serialized even where the work looks parallelizable.

**The spawned agent does not commit.** `.git` stays read-only even under `workspace-write`, so a nested agent physically cannot commit; `git commit` fails with `Unable to create '.git/index.lock'`. The agent writes files and returns; the orchestrator commits once the item is complete. The invariant that matters — no commit for a partial item — is unchanged; only who runs `git commit` moves.

**Resuming after a blocker:** `codex exec resume <thread-id> "<the answer, plus what to do with it>"`, with the same flags and the same checks. The resumed agent keeps everything it had already worked out, so finished work is not redone. If no thread id was captured (a run killed early enough leaves no rollout file) or resume fails, spawn a fresh agent instead and point it at the handoff file plus the uncommitted diff — that is what the blocked agent's handoff file exists for, so nothing is lost.
