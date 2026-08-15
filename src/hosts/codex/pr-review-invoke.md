Say in one sentence up front what is about to happen, naming the risk tier and exact attributed roster. A reviewer only reads, so it is held to reading by its brief (a native subagent inherits the coordinator's sandbox and cannot be given a read-only sandbox of its own — see Spawning a fresh-context agent). Spawn every independent roster slot with `spawn_agent` on a fresh (`fork_turns: "none"`) context before entering the shared `wait_agent` mailbox loop; each on-disk brief names its role, exact fingerprint, findings schema, and distinct evidence output path. Use `list_agents` to reconcile statuses and accept no empty or missing result. This is a read-only fan-out with disjoint artifacts; it does not inherit the nested-CLI login race.

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
