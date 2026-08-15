# Behavioral release evaluations

The checked-in fixtures are synthetic and contain no production or customer data. Ordinary repository tests run only `bin/pln-eval validate`, deterministic scoring, and fake CLI boundaries through `bash tests/evals.sh`; they never call Claude Code or Codex.

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
