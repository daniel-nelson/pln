Invoke the script through the Workflow tool; state it in one sentence ("Reviewing the diff with 7 fresh reviewers") and wait for its notification rather than polling. If an individual reviewer fails, continue with the rest — partial coverage beats none. But track how many reviewers actually completed: a completed reviewer that returned an empty findings array counts as a success (it looked and found nothing); a reviewer that errored, timed out, or never returned does not. Carry that count into the gate below.

**Optional Codex pass (opt-in, degrades cleanly).** Independent of the workflow: if `codex` is on PATH and authenticated, run one adversarial pass via Bash for cross-model coverage. Both the auth probe and the review must be time-boxed so a hung `codex` can never stall the flow — wrap the probe in `timeout` and give `codex exec` an explicit outer `timeout` as well as the Bash tool's own `timeout`:

```bash
if command -v codex >/dev/null 2>&1 && timeout 20 codex login status >/dev/null 2>&1; then
  _REPO_ROOT=$(git rev-parse --show-toplevel)
  timeout 300 codex exec "Review the changes on this branch against the base. Run: DIFF_BASE=\$(git merge-base origin/<base> HEAD) && git diff \"\$DIFF_BASE\". Find ways this code fails in production — edge cases, races, security holes, resource leaks, silent data corruption. Be adversarial. No compliments. End with one line: Recommendation: <action> because <one-line reason naming the most exploitable finding>." -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="high"' < /dev/null
fi
```

Run this Bash call with a tool-level timeout a little above the 300s inner one (e.g. 330000 ms). A non-zero exit from either `timeout` (probe stall = exit 124, or a hung `exec` killed at 300s) counts as **not available**: treat it exactly like an absent `codex`. If `codex` is absent, not authed, or timed out, skip with a one-line note ("Codex not available — Claude reviewers only. Install `@openai/codex` for cross-model coverage."). Fold any Codex findings into the merged set below.
