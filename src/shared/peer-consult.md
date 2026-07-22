One helper picks the peer and runs it, so no step in either skill carries probe logic of its own:

```bash
"$PLN_BIN/pln-peer" \
  --brief "$RUN/peer.brief.md" \
  --out   "$RUN/peer.out" \
  --timeout 1800
```

Write the brief to a file first and point `--brief` at it. The prompt never goes on the command line, for the same reason a spawned agent's brief doesn't: it is a page of markdown full of backticks, quotes and `$`, and shell-escaping it by hand is how a call ends up running a truncated prompt.

**The brief has to stand alone.** A peer may be a plain prompt-in, text-out CLI with no access to the repository at all, so the material being reviewed goes *in* the brief — the plan text, the diff — and the paths are named as well, for a peer that can read files. A brief that only says "review the plan at ./plans/…/PLAN.md" gets a competent answer from one peer and an invented one from another. Where the material is too large to inline whole, inline the part that carries the question and name the rest.

The helper prints exactly five lines and nothing else, so reading it costs almost no context:

```
RUNG=2
PEER=codex
STATUS=ok
RESULT_FILE=/…/peer.out
LOG_FILE=/…/peer.out.log
```

The three rungs, in order. The helper walks them; nothing above it needs to know how:

1. **A command the user named in config** — `peer_command`, their whole invocation, so this rung covers a tool pln has never heard of. The contract is a pipe: the command reads its prompt on stdin and writes its answer to stdout. `"$PLN_BIN/pln-config" set peer_command "gemini -p"`.
2. **A known agent CLI on PATH that is not hosting this session** — under Claude it reaches for `codex`, under Codex for `claude`, and only when that CLI is authenticated too. Probes ship only for CLIs whose invocation pln has actually reproduced; a probe that finds a command and calls it wrong is worse than finding nothing, so everything else arrives through rung 1.
3. **Nobody** — `RUNG=3`, `PEER=none`, exit 3. What that means is the caller's call, and neither answer is an error: a step whose value is a *fresh context* spawns a same-model agent instead (see Spawning a fresh-context agent) and says so; a pass whose only value is a *different model* skips and says so.

Reading the result:

- **exit 0, `STATUS=ok`** — read `RESULT_FILE`. That text is the peer's whole answer and the only thing that should reach your context.
- **exit 3** — rung 3 above.
- **exit 4**, `STATUS=empty|timeout|error` — a peer was picked, ran, and failed. An empty answer is a failed peer, not a peer that found nothing; don't read `RESULT_FILE`. Fall back exactly as if the run had come back rung 3, and say in one line that the peer failed.
- **`LOG_FILE`** is the peer's stderr and event trace. Never read it into your context — it exists for a post-mortem on a failed run.

Say which rung ran, in a clause, wherever the result is reported: "reviewed by codex", "no peer available — reviewed by a fresh same-model agent". A reader weighs a finding differently depending on whose eyes were on it. `--which` reports the selection without running anything, for when that has to be known before the brief is sent.

Rungs 1 and 2 hand the brief to another vendor's CLI: the material leaves the machine, and the call can spend the user's quota there.
