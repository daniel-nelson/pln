Say in one sentence up front what is about to happen ("Reviewing the diff with `codex review` plus N fresh reviewers, one at a time") so the wall-clock cost is not a surprise, then spawn the lenses in order. A reviewer only reads, so it runs read-only:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/lens-security.brief.md" \
  --out   "$RUN/lens-security.out" \
  --sandbox read-only \
  --timeout 1200 \
  --cd "$(git rev-parse --show-toplevel)"
```

Write each lens's brief to its own file first (heredoc), name the files after the lens, and wait for each spawn to return before starting the next.

**Reading a reviewer back.** Its findings are its final message, in `RESULT_FILE` — that file is the only thing you read into your own context. It should hold a single `{"findings": [...]}` object. If the model wrapped it in a code fence or put a sentence in front of it anyway, take the outermost `{ ... }` and parse that rather than throwing the reviewer's work away. A result with no parseable object in it is a failed reviewer, not a clean one.

**Count what actually ran.** A spawn that exits 0 with a parseable findings array is a success even when the array is empty — it looked and found nothing. A helper exit of 4 (`empty`, `timeout`, `error`) is not, and `empty` is the one that lies: `codex exec` can exit 0 having written no result at all. Add stage 1 to the same count if its summary came back. If a reviewer fails, note it in one line and continue with the rest — partial coverage beats none — but carry the real count into the gate below. This is the one place where the spawn rules' "a failed spawn stops the loop" does not apply: the army is deliberately many small runs, and one of them dying is one reviewer down, not a dead review. The gate below is what turns *no* reviewer surviving into a stop.
