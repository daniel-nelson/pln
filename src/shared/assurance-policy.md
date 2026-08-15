## Assurance policy

Review depth follows semantic risk, never shortness. Before plan review, PR review, or a review pass on a new CI candidate, dispatch one fresh `judgment` worker under `src/workers/assurance-classification.md`. Give it the plan or file-first diff maps, protected decisions, and source fingerprint. It returns semantic signals, the highest applicable specialist areas, substantive file/line counts, citations, and uncertainty. Validate the tier and pre-fix roster with `bin/pln-assurance`; unknown or conflicting risk is R3. The provisional `>10` substantive files or `>500` non-generated lines rule may raise routine work to R2, but no count lowers semantic risk.

- **R1 routine:** one fresh broad judgment reviewer. Run targeted tests and narrowly verify any fix.
- **R2 elevated:** dependencies, builds, configuration, generators, public contracts, missing direct coverage, multiple subsystems, or the provisional size threshold. Run the broad reviewer plus at most two applicable specialist lenses, then a fresh post-fix verifier.
- **R3 critical:** authentication/trust, secrets, privacy, production data, money, external effects, destructive migrations, concurrency/transactions, IaC, CI security, compatibility, AI/eval safety, unresolved critical conflict, or unknown risk. Run at most four pre-fix readers: one broad, up to two readers for the highest applicable risk areas, and one adversarial slot. A permitted cross-model peer fills that adversarial slot; otherwise one fresh same-model adversarial reviewer substitutes and the loss of model-family independence is attributed. A full red-team pass after nontrivial fixes is a separate post-fix stage, outside the four-reader cap.

Every reviewer is a fresh `judgment` worker that inherits the hosting model. An unidentified model is attributed as unreported rather than rejected or guessed. Missing, empty, malformed, timed-out, or wrong-tree work is failed coverage, not a clean result. Preserve protected user decisions, untrusted-command confirmation, file-first raw outputs, bounded merge envelopes, and truthful reader/model/failure attribution at every tier.

Review findings do not carry confidence scores or ask a model to certify itself. A reviewer supplies an exact `file:line` quotation plus a runnable reproduction or named test when one exists. The judgment merge worker checks the exact candidate and records each finding as `verified`, `unverified`, or `disproved`; only verified findings enter automatic fix work. Unverified findings remain visible for judgment, and disproved findings stay in the durable appendix so they are not rediscovered as open bugs.

The review surfaces have independent opt-outs. `plan_review=false` and a per-run plan-review instruction affect only `/pln`'s pre-adoption review. `/pln-pr` review is skipped only by an explicit instruction for that PR run; do not carry the plan preference across. Each opt-out is authoritative even at R3. When an applicable R3 review is skipped, warn clearly that critical assurance was skipped and do not describe the universal floor as having run.

A repository may explicitly declare a self-hosting exception for the workflow that implements its own reviewer. Treat that declaration as an explicit review skip only for that repository, follow its named substitute assurance (for this project: the complete offline gauntlet plus manual installation), and use its direct ship path. Do not generalize the exception to other projects or silently claim the skipped source review.

### Exact candidate identity

Gauntlet evidence belongs to one exact candidate: the current non-ignored tree, the ordered command set, and the relevant environment. Write commands and a normalized environment description (runtime/tool versions and required non-secret conditions; never secret values) to artifacts, then run:

```bash
bin/pln-assurance fingerprint --root <repo> \
  --commands <commands-file> --environment <environment-file>
```

Persist all four hashes with the result. Reuse `/pln` verification in `/pln-pr` only when `TREE_SHA256`, `COMMAND_SHA256`, and `ENVIRONMENT_SHA256` all match. Any review fix, version/changelog edit, CI code fix, command change, or relevant environment change creates a new candidate and invalidates the prior green result. Compute the fingerprint immediately before and after the gauntlet; a changed tree fails verification rather than blessing an untested state.
