Say in one sentence up front what is about to happen ("Reviewing the diff with `codex review` plus N fresh reviewers, one at a time") so the wall-clock cost is not a surprise, then spawn the lenses in order. A reviewer only reads, so it is held to reading by its brief (a native subagent inherits the orchestrator's sandbox and can't be given a read-only one of its own — see Spawning a fresh-context agent). Spawn each lens with `spawn_agent` on a fresh (`fork_turns: "none"`) context, carrying that lens's brief and the findings schema below; write each brief to its own file first, name the files after the lens, and wait through the `wait_agent` mailbox loop (using `list_agents` for status) before spawning the next.

Where the native multi-agent tools are unavailable, fall back to the nested-`codex exec` helper, read-only:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/lens-security.brief.md" \
  --out   "$RUN/lens-security.out" \
  --sandbox read-only \
  --timeout 1200 \
  --cd "$(git rev-parse --show-toplevel)"
```

**Reading a reviewer back.** Its findings are its final message — the child's returned message on the native path, `RESULT_FILE` on the fallback — and that is the only thing you read into your own context. It should hold a single `{"findings": [...]}` object. If the model wrapped it in a code fence or put a sentence in front of it anyway, take the outermost `{ ... }` and parse that rather than throwing the reviewer's work away. A result with no parseable object in it is a failed reviewer, not a clean one.

**Count what actually ran.** A reviewer that finished with a parseable findings array is a success even when the array is empty — it looked and found nothing. A reviewer that `errored`, or came back `completed` with an empty final message (the fallback reports this as `STATUS=empty`), did not run — and `empty` is the one that lies, since a finished agent can return nothing at all. Add stage 1 to the same count if its summary came back. If a reviewer fails, note it in one line and continue with the rest — partial coverage beats none — but carry the real count into the gate below. This is the one place where the spawn rules' "a failed spawn stops the loop" does not apply: the army is deliberately many small runs, and one of them dying is one reviewer down, not a dead review. The gate below is what turns *no* reviewer surviving into a stop.
