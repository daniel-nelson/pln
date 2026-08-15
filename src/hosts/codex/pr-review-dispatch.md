Otherwise run the army in two stages, both serial. This is a review-coverage choice, not an OAuth limitation: native agents can run concurrently and `wait_agent` is a shared mailbox, but this flow consumes one result at a time. The OAuth token race applies only to fallback CLI processes, which also remain serial.

**Stage 1 — the native review pass.** `codex review` is built for exactly this job and runs as one process, so it is the cheapest broad coverage available here. It takes no `-C`, so run it from the repo root, and capture its output to a file:

```bash
env -u OPENAI_API_KEY -u CODEX_API_KEY timeout -k 10 1800 codex review --base "<base>" < /dev/null > "$RUN/codex-review.out" 2>&1
```

That redirect is not optional. It streams the whole diff, its own reasoning, and every command it runs to stdout, escape codes and all — thousands of lines on a middling branch. Never read or tail it in coordinator context. Pass its path, exit status, and source fingerprint to the judgment merge worker, which extracts and verifies any findings.

It is also the slowest thing in this flow — it can dig for many minutes on a large diff, which is why the ceiling above is generous. A missing `codex` binary, a non-zero exit (`124` is the ceiling), or an empty artifact means stage 1 did not run. A non-empty artifact is provisional until the merge worker validates that it contains a review result. Carry on with stage 2 when it fails.

**Stage 2 — the lenses stage 1 underweights.** A general review pass already covers what lenses 1, 5 and 6 look for, and on this host every extra lens is wall-clock the user waits through. So run **2 (security & trust boundaries)**, **3 (data & persistence)** and **4 (testing & coverage)** from the list below, plus the **adversarial pass** — four spawns, in that order, one at a time. Skip a lens whose subject the diff does not contain (no migrations, no schema, no queries → skip 3); never skip 2 or the adversarial pass. If stage 1 did not run, add lens **1 (correctness & edge cases)** so the broad ground is still covered by something.

Each lens is one fresh-context agent (see Spawning a fresh-context agent) carrying the brief and the findings schema below. The full set of six lenses, of which this host runs the subset above:
