# Behavioral release evaluations

The checked-in fixtures are synthetic and contain no production or customer data. Ordinary repository tests run only `bin/pln-eval validate`, deterministic scoring, and fake CLI boundaries through `bash tests/evals.sh`; they never call Claude Code or Codex.

The sealed 1.32 qualification corpus retains the historical `classified-only` token. It is evidence from an opened holdout, not current configuration guidance, and must not be rewritten when terminology changes. Current runtime/config tests use `approved-only`.

Real-model runs are explicit:

```bash
bin/pln-eval run-live --host claude --profile frontier --split calibration --trials 3 --out-dir <artifact-dir>
bin/pln-eval run-live --host claude --profile economy  --split calibration --trials 3 --out-dir <artifact-dir>
bin/pln-eval freeze --host claude \
  --frontier-score <frontier>/score.env --economy-score <economy>/score.env \
  --frontier-metadata <frontier>/metadata.env --economy-metadata <economy>/metadata.env \
  --out <freeze.env>
```

Repeat for Codex. The freeze binds the corpus hash, fixed correctness/safety floors, observed paired-latency variance, a practical-benefit threshold above that noise, and the required holdout size. Only then may either holdout prompt be rendered or run:

```bash
bin/pln-eval run-live --host claude --profile frontier --split holdout \
  --freeze <freeze.env> --out-dir <artifact-dir>
bin/pln-eval run-live --host claude --profile economy --split holdout \
  --freeze <freeze.env> --out-dir <artifact-dir>
bin/pln-eval decide --host claude --freeze <freeze.env> \
  --frontier-score <frontier-holdout>/score.env --economy-score <economy-holdout>/score.env \
  --frontier-metadata <frontier-holdout>/metadata.env --economy-metadata <economy-holdout>/metadata.env \
  --out <decision.env>
```

`decide` is mechanical: any hard-floor failure, benefit below the frozen threshold, or host × class holdout smaller than the calculated requirement exits nonzero and records `STATUS=disabled`. Do not tune against an opened holdout. Each live run records selected/actual attribution, CLI and skill versions, repository and fixture hashes, latency samples, reported tokens/cost when the CLI exposes them, fallbacks, and artifact paths. Keep these nondeterministic outputs outside the committed corpus (the local plan's `evidence/` directory is the normal location).

## Frontier invariant regressions after an opened holdout

Never edit, tune, or reuse an opened holdout to clear a failed hard invariant. Fix the runtime contract, create a new sanitized suite and gold file, and seal their hashes together with the exact runtime contract before the first model call. The v3 outline/adoption regression does that through:

```bash
bin/pln-eval seal-frontier-regression --host claude --out <seal.env>
bin/pln-eval run-frontier-regression --host claude --seal <seal.env> \
  --trials 3 --timeout-seconds 180 --out-dir <artifact-dir>
```

The prompt cannot render without the host-specific seal. A changed case, gold answer, output protocol, always-loaded contract, or outline phase invalidates that seal, and the runner requires 100% hard-case accuracy on every trial. This replacement suite proves only the named frontier invariant; it does not requalify an economy route or substitute for an undersized host/class comparison.
