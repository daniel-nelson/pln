Say in one sentence up front what is about to happen, naming the exact attributed roster and, as the concrete signal that drove it rather than as a tier name, how deep the review goes. A reviewer only reads, so it is held to reading by its brief (a native subagent inherits the coordinator's sandbox and cannot be given a read-only sandbox of its own — see Spawning a fresh-context agent). Spawn every independent roster slot with `spawn_agent` on a fresh (`fork_context: false`) context before entering the shared `wait_agent` mailbox loop; each on-disk brief names its role, exact fingerprint, findings schema, and distinct evidence output path. Reconcile statuses from `wait_agent`'s status map and the mailbox, and accept no empty or missing result. This is a read-only fan-out with disjoint artifacts; it does not inherit the nested-CLI login race.

**When the adversarial slot substitutes.** Spawn the same-model adversarial substitute the moment the peer's no-send or failure is known, not once the readers return. Learn of a failure early by checking the peer's shell call between short waits rather than inside one long wait: every failing peer observed so far returned within a minute. Only if that spawn is refused for capacity, or the session already states a slot count the running readers fill, spawn it into the first slot a finished reader frees. The stated count includes the coordinator, so at the default of four, three readers fill it and the substitute usually takes the first freed slot. Where a finished child keeps its slot until it is closed, close a finished reader to free it; never a running one. The substitution line may say once that `features.multi_agent_v2.max_concurrent_threads_per_session` in the user's own `~/.codex/config.toml` raises that stated count, letting the substitute run beside the readers — theirs to set; pln never writes it.

**A peer already out of quota is not called again in the same review.** When the peer returned `REASON=<peer>-usage-limit` in this `/pln-pr` run's first review or an earlier post-fix round, do not call it: spawn the substitute with the other readers in the first dispatch. The next `/pln-pr` run calls the peer again, since the limit resets.

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

After the roster returns, build the contract-first PR-merge prepared context from the raw paths and fixed completion metadata. Spawn the merge worker with that brief as its primary inventory rather than reconstructing a multi-pointer assignment. The merge worker verifies candidate, manifests, and artifacts before any reader can count.
