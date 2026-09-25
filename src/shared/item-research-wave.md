**Research before prose.** Every active item is researched before the walk begins — not each item as the walk reaches it, which would put a wait in front of every question instead of one wait in front of all of them. For each item, classify the needed read through the three tiers. A known-stop exact coordination fact may be direct within the shared budget; a mechanically closed inventory or citation refresh uses `{{SKILL_DIR}}/src/workers/evidence-collection.md`; shaping an approach, tradeoff, scope, or question uses a fresh `judgment` worker with `{{SKILL_DIR}}/src/workers/interview-research.md` in item mode. Give workers the project root, `PLAN.md`, exact item scope, source state, applicable root mandates, evidence/result paths, routing attribution, and the 4096-byte ceiling. Record every route in `routing.tsv` and read only a validated envelope. The user sees one coherent response after research, never progress output or raw findings.

**Research every active item before the walk begins, and dispatch it concurrently.** The classification above is per item; the dispatch is not. Item research is read-only and each item's is independent of every other item's, so nothing orders them — and a run that researches one item at a time makes the user wait the sum of every item before the first question, rather than the slowest one. Dispatch the item workers together in waves, await the wave, then walk the items with their envelopes already in hand. Measured on a real four-item run: 6.1 + 7.4 + 13.9 minutes serially, where the wall clock could have been the longest of the three.

**A plan wider than one wave walks the wave it has.** Where the active items do not fit a single wave, the walk begins when the first wave lands, and the next wave is dispatched as the walk moves into it — the run does not wait for the last wave before asking the first question, which would put the whole delay back for exactly the plans that can least afford it. A wave still running for items the walk has not reached does not hold back a question about an item already researched: the hold above exists so that a message the user must read is not buried by later output, and a wave in flight produces no output at all — its results are consumed silently as they land, which is what that rule already says. What is never split is a single item: its own research is in hand before its question is asked.

**No follow-up worker is dispatched except on one of four triggers.** Each dispatches a follow-up worker for that item alone — a fresh `judgment` worker in item mode, over the earlier worker's artifact paths — before that item's next question:

1. The item's envelope, of either tier, carries evidence that changes the item's premise.
2. The envelope returns `ESCALATE: frontier`.
3. An answer that changes an item's approach dispatches a fresh item-mode worker for that item, because the envelope it has describes the approach the answer replaced, interleavings included.
4. A pre-flight merged after the item's envelope landed adds a mandated rule the item's research brief did not carry.

Otherwise the walk uses the envelope it has: a source the envelope already cites is not re-checked on the chance that it changed. A follow-up raised by the first two is dispatched after the wave that raised it, so none of these serializes the wave. And where an answer already given makes a dispatched item's research moot, say so and cancel that worker rather than letting it land under a question its own answer would change.

**Every dispatch is recorded before it runs, and writes to paths of its own.** At dispatch, append one row per item worker to `routing.tsv` with `{{SKILL_DIR}}/bin/pln-route-ledger`: `--scope item-<N>`, `--status dispatched`, `--artifacts` naming that dispatch's own `results/item-<N>.<seq>.txt` and `evidence/item-<N>.<seq>.md` beneath the root workers write to, and `--source-state` carrying the source state plus `item-sum <value>`. `<seq>` is one more than the highest sequence the item's rows already carry, starting at 1. The value is the checksum of the item's dashboard row and detail section as they stand at dispatch, from exactly this command run in the plan directory, so a later session computes the same one:

```bash
awk -v n=<N> '/^## /{st=($0=="## Status")} /^## |^### /{s=0} $0~"^### "n"\\. "{s=1} (st&&$0~"^"n"\\. ")||s' PLAN.md | cksum
```

An item's newest `dispatched` row is its only live dispatch. Every earlier row's result is superseded and never read, whatever lands there, so no results path ever has two writers: a worker that cannot be stopped finishes into its own path and nothing looks at it.

**Reuse is decided per item, from its newest `dispatched` row, before anything is dispatched for it.**

- **A dropped item** — its result is never read, whatever state its worker is in.
- **No row** — dispatch.
- **The recorded `item-sum` no longer matches** the item as it stands, because its row or section was edited after dispatch — dispatch afresh at the next sequence.
- **It matches, and a validated envelope is at its result path** — that envelope is the item's research. Dispatch nothing.
- **It matches, and its worker is a handle this session can reconcile** — running, or finished and not yet consumed — it is part of the wave in flight. Await it like any other.
- **It matches, with neither a validated envelope nor a reconcilable handle** — a restart or compaction lost the worker, and it is orphaned. Dispatch afresh at the next sequence; a late write by the old worker lands on its own path and is never read.
