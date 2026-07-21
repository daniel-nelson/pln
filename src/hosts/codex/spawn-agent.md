A fresh-context agent is a nested `codex exec` call: a new session, its own context, one result. Codex has no harness-run script to hold a loop, so the orchestrator runs the loop itself and spawns one call at a time.

Every spawn goes through pln's own helper, which owns the guards that spawn needs:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/item-3.brief.md" \
  --out   "$RUN/item-3.out" \
  --sandbox workspace-write \
  --cd "$(git rev-parse --show-toplevel)"
```

Write the brief to a file first and point `--brief` at it. The prompt never goes on the command line: a brief is a page of markdown full of backticks, quotes and `$`, and shell-escaping it by hand is how a spawn ends up running a truncated prompt.

The helper prints exactly four lines and nothing else, so reading its output costs the orchestrator almost no context:

```
STATUS=ok
THREAD_ID=019f851c-7561-75e3-ae3e-650a9c8cb1e9
RESULT_FILE=/…/item-3.out
EVENTS_FILE=/…/item-3.out.events
```

How to read that:

- **`STATUS=ok` and exit 0** — the agent ran and wrote a result. Read `RESULT_FILE`; that text is the agent's final message and the only thing that reaches your context.
- **Any other status** (`empty`, `timeout`, `error`) exits 4 and means the run failed. Say so and stop the loop; do not treat it as an item that had nothing to do. `empty` is the one to watch: `codex exec` can exit 0 having written nothing, so a spawn that "succeeded" with no output is a failure wearing a success's clothes.
- **`THREAD_ID`** is what makes a blocked item resumable. Keep it with the item.
- **`EVENTS_FILE`** is the agent's full reasoning trace. Never read it into your context — it exists for a post-mortem when a run fails.

Options worth knowing:

- `--sandbox read-only` for agents that only read (reviewers, a verification run that writes no artifacts). `workspace-write` is the default and is what item work needs.
- `--add-dir <dir>` when the agent must write somewhere outside the working root — a plan directory that isn't under the git top level, for instance.
- `--timeout <secs>` (default 3600) is a ceiling on a *hung* run, not a work budget; raise it for an item you expect to take a long time. There is no built-in timeout, so something has to bound it. On a machine with neither `timeout` nor `gtimeout` the helper says so on stderr and runs unbounded — watch that run rather than walking away from it.
- `--resume <thread-id>` continues an existing thread instead of starting a new one.

**One call at a time.** Concurrent `codex` processes race on the shared OAuth token file, so spawns are serialized even where the work looks parallelizable.

**The spawned agent does not commit.** `.git` stays read-only even under `workspace-write`, so a nested agent physically cannot commit; `git commit` fails with `Unable to create '.git/index.lock'`. The agent writes files and returns; the orchestrator commits once the item is complete. The invariant that matters — no commit for a partial item — is unchanged; only who runs `git commit` moves.

**Resuming after a blocker:** run the helper again with `--resume "$THREAD_ID"` and a brief carrying the answer and what to do with it. The resumed agent keeps everything it had already worked out, so finished work is not redone. A resumed thread also keeps the sandbox and working root it started with — `--sandbox`, `--cd` and `--add-dir` are ignored on resume, so there is nothing to re-specify. If no thread id was captured (a run killed early enough leaves no rollout file) or the resume fails, spawn a fresh agent instead and point it at the handoff file plus the uncommitted diff — that is what the blocked agent's handoff file exists for, so nothing is lost.

If `{{SKILL_DIR}}` never resolved (the preamble printed `none`), the helper isn't installed. Fall back to the call it makes, keeping every guard: `env -u OPENAI_API_KEY timeout -k 10 3600 codex exec -C <root> -s workspace-write --json -o "$OUT" - < brief.md > "$EVENTS" 2>&1`, then read the thread id with `grep -m1 -o '"thread_id":"[^"]*"' "$EVENTS" | cut -d'"' -f4`, and treat an empty `$OUT` as a failure.
