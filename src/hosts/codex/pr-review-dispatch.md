Otherwise run the army in two stages, both serial — one reviewer at a time keeps the wait a single-agent `wait_agent` poll and the tree quiet. Native subagents could in principle run at once here — they are in-session threads, not separate `codex` processes racing on the shared OAuth token — but a parallel review army has the orchestrator waiting on many children together, a wait pattern worth proving on this host before pln leans on it. Until then the army stays serial.

**Stage 1 — the native review pass.** `codex review` is built for exactly this job and runs as one process, so it is the cheapest broad coverage available here. It takes no `-C`, so run it from the repo root, and capture its output to a file:

```bash
env -u OPENAI_API_KEY -u CODEX_API_KEY timeout -k 10 1800 codex review --base "<base>" < /dev/null > "$RUN/codex-review.out" 2>&1
```

That redirect is not optional. It streams the whole diff, its own reasoning, and every command it runs to stdout, escape codes and all — thousands of lines on a middling branch. Read the review summary at the end (`tail -n 200 "$RUN/codex-review.out"`) and nothing else. Translate what it reports into the findings schema below, giving each item a `file:line` and the quoted code; anything it raises without a line reference is a suspicion and gates like one.

It is also the slowest thing in this flow — it can dig for many minutes on a large diff, which is why the ceiling above is generous. A missing `codex` binary, a non-zero exit (`124` is the ceiling), or a file that ends without a review summary all mean the same thing: stage 1 did not run. Say so in one line and carry on with stage 2, one reviewer down.

**Stage 2 — the lenses stage 1 underweights.** A general review pass already covers what lenses 1, 5 and 6 look for, and on this host every extra lens is wall-clock the user waits through. So run **2 (security & trust boundaries)**, **3 (data & persistence)** and **4 (testing & coverage)** from the list below, plus the **adversarial pass** — four spawns, in that order, one at a time. Skip a lens whose subject the diff does not contain (no migrations, no schema, no queries → skip 3); never skip 2 or the adversarial pass. If stage 1 did not run, add lens **1 (correctness & edge cases)** so the broad ground is still covered by something.

Each lens is one fresh-context agent (see Spawning a fresh-context agent) carrying the brief and the findings schema below. The full set of six lenses, of which this host runs the subset above:
