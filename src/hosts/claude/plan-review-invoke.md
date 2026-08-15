Use one fresh non-fork `general-purpose` `Agent` call (see Spawning a fresh-context agent). Its compact assignment points at `<plan-dir>/evidence/plan-review.brief.md` and names `<plan-dir>/evidence/plan-review.agent.out` as the findings path. The final message must be only `RESULT_FILE=<that path>`; never ask it to paste findings back.

The call's result is the result pointer, the only thing that reaches this context. If fork mode runs it in the background, wait for its completion notification and apply the same non-empty check.

**Alongside the peer.** Where a peer ran too, start its shell call (step 4) in the background — `Bash` with `run_in_background: true` — and make this `Agent` call in the same turn without waiting on the peer. Read only the helper's fixed eight lines once both return; the merge worker reads its `--out` artifact. Where background shell is unavailable, sequence them.
