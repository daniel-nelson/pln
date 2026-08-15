Say in one sentence up front what is about to happen ("Reviewing the diff with `codex review` plus N fresh reviewers, one at a time") so the wall-clock cost is not a surprise, then spawn the lenses in order. A reviewer only reads, so it is held to reading by its brief (a native subagent inherits the orchestrator's sandbox and can't be given a read-only one of its own — see Spawning a fresh-context agent). Spawn each lens with `spawn_agent` on a fresh (`fork_turns: "none"`) context; its on-disk brief names the findings schema and a distinct evidence output path. Wait through the `wait_agent` mailbox loop (using `list_agents` for status) before spawning the next.

Where the native multi-agent tools are unavailable, fall back to the nested-`codex exec` helper, read-only:

```bash
"{{SKILL_DIR}}/bin/pln-codex-agent" \
  --brief "$RUN/lens-security.brief.md" \
  --out   "$RUN/lens-security.result" \
  --sandbox read-only \
  --timeout 1200 \
  --cd "$(git rev-parse --show-toplevel)"
```

**Reading a reviewer back.** The final message must be only `RESULT_FILE=<assigned evidence path>`. Read that fixed pointer and file metadata, never the referenced findings. The fallback's `--out` is likewise a pointer result, not the raw review. A missing pointer or missing/empty artifact is a failed reviewer; schema validation belongs to the merge worker.

**Count what actually ran.** A reviewer whose pointer and non-empty artifact exist is provisionally successful; the merge worker decides whether the artifact is a valid empty or non-empty findings array. A reviewer that `errored`, returned an empty final message, or omitted its artifact did not run. Add stage 1 provisionally when its captured artifact is non-empty. If a reviewer fails, note it in one line and continue, but the merge worker's validated reader count controls the fail-closed gate.
