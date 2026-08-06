One helper picks the peer and runs it, so no step in either skill carries probe logic of its own:

```bash
"$PLN_BIN/pln-peer" \
  --brief "$RUN/peer.brief.md" \
  --out   "$RUN/peer.out" \
  --timeout 1800
```

Write the brief to a file first and point `--brief` at it. The prompt never goes on the command line, for the same reason a spawned agent's brief doesn't: it is a page of markdown full of backticks, quotes and `$`, and shell-escaping it by hand is how a call ends up running a truncated prompt.

**The brief has to stand alone.** A peer may be a plain prompt-in, text-out CLI with no access to the repository at all, so the material being reviewed goes *in* the brief — the plan text, the diff — and the paths are named as well, for a peer that can read files. A brief that only says "review the plan at ./plans/…/PLAN.md" gets a competent answer from one peer and an invented one from another. Where the material is too large to inline whole, inline the part that carries the question and name the rest.

**Naming the paths only helps while the tree still matches the material.** Asking a peer to check the brief's claims against the files it names holds while those files are still the state the material was written against, so send the commit the material was taken from alongside the paths. A peer reading a repository that has moved past that commit is reading someone else's edits and will report them as errors in the material.

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
3. **Nobody** — `RUNG=3`, `PEER=none`, exit 3. What that means is the caller's call, and neither answer is an error: a step whose value is a *fresh context* has a same-model agent do that reading (see Spawning a fresh-context agent) and says so — where that agent runs alongside a peer anyway, rung 3 leaves it as the only reader rather than adding one; a pass whose only value is a *different model* skips and says so.

**The one-time consent.** Rungs 1 and 2 hand the material to a CLI from another vendor, so pln asks the user once per machine, before the first send, and never again. The helper enforces that itself and cannot ask: with no answer recorded it sends nothing, exits 5, and names the peer it would have used.

```
RUNG=1
PEER=gemini
STATUS=consent
```

That is your cue to ask, as a binary question naming that peer and what this call would actually send it — a plan, a diff. What the answer decides is broader than the one call: one key, `peer_consent`, covers every pln skill and every repository on this machine, so the question is about peer use, not about this review.

```
The plan review is ready to go to `gemini`, a different model on this machine, and pln has never asked whether that's allowed.

Send it there?

Yes and the plan text goes to `gemini` now, and pln consults a peer from then on — later reviews, other repos, `/pln-pr`'s cross-model pass — without asking again. The material leaves this machine and the call can spend your quota with that vendor. No and nothing is ever sent: the review runs on a fresh agent of this same model instead, which still gets a blank-slate reading of the plan. Either answer is remembered in `~/.pln/config.yaml`, and `pln-config set peer_consent true` or `false` changes it later.
```

On yes, `"$PLN_BIN/pln-config" set peer_consent true` and run the same command again. On no, `"$PLN_BIN/pln-config" set peer_consent false` and carry on as if the run had come back rung 3. Never ask when the helper did not exit 5 — exit 3 means nothing would leave the machine anyway, and a question that changes nothing is worse than no question.

Reading the result:

- **exit 0, `STATUS=ok`** — read `RESULT_FILE`. That text is the peer's whole answer and the only thing that should reach your context.
- **exit 0, `STATUS=ready`** — a `--which` call, nothing sent: a peer is selected and consent is recorded. It is not rung 3's `none`, which is the no-peer case; the two statuses are distinct so a selection cannot be read as an empty ladder and the pass skipped for no reason.
- **exit 5, `STATUS=consent`** — nothing was sent. Ask the one-time question above, record the answer, and either re-run or fall back.
- **exit 3** — rung 3 above. `STATUS=declined` is the same fallback with a different cause: the user has peer consult switched off, so say that rather than "no peer available", which would read as a broken install.
- **exit 4**, `STATUS=empty|timeout|error` — a peer was picked, ran, and failed. An empty answer is a failed peer, not a peer that found nothing; don't read `RESULT_FILE`. Fall back exactly as if the run had come back rung 3, and say in one line that the peer failed.
- **`LOG_FILE`** is the peer's stderr and event trace. Never read it into your context — it exists for a post-mortem on a failed run.

Say which rung ran, in a clause, wherever the result is reported: "reviewed by codex", "no peer available — reviewed by a fresh same-model agent". Where the caller runs both readers, name both. A reader weighs a finding differently depending on whose eyes were on it. `--which` reports the selection without running anything, for when that has to be known before the brief is assembled; it takes neither `--brief` nor `--out`, and it is gated the same way, so it answers `consent` too.
