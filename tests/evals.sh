#!/usr/bin/env bash
# Deterministic behavioral-eval contracts. Agent CLIs are fake; no network,
# credentials, installed skills, or developer ~/.pln state are used.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EVAL="$REPO_DIR/bin/pln-eval"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-eval-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
field() { sed -n "s/^$1=//p" "$2" | tail -n 1; }

[ -x "$EVAL" ] || fail "missing executable eval helper: $EVAL"

validation="$($EVAL validate)"
printf '%s\n' "$validation" | grep -q '^CASES=40$' || fail 'corpus does not contain 40 sanitized cases'
for line in CALIBRATION_ELIGIBLE=10 CALIBRATION_BOUNDARY=10 HOLDOUT_ELIGIBLE=10 HOLDOUT_BOUNDARY=10; do
  printf '%s\n' "$validation" | grep -q "^$line$" || fail "missing stratum: $line"
done
fixture="$(printf '%s\n' "$validation" | sed -n 's/^FIXTURE_SHA256=//p')"
[ "${#fixture}" -eq 64 ] || fail 'fixture hash is not SHA-256 sized'

# The calibration prompt contains calibration cases only. The untouched
# holdout cannot even be rendered until a fixture-bound freeze exists.
$EVAL prompt --profile economy --split calibration --out "$WORK/calibration.prompt"
grep -q '^ce01' "$WORK/calibration.prompt" || fail 'calibration prompt lost eligible cases'
grep -q '^cb10' "$WORK/calibration.prompt" || fail 'calibration prompt lost boundary cases'
grep -q '^he01' "$WORK/calibration.prompt" && fail 'calibration prompt leaked holdout cases'
if $EVAL prompt --profile economy --split holdout --out "$WORK/holdout.prompt" >/dev/null 2>&1; then
  fail 'holdout opened without a frozen calibration artifact'
fi

# Produce exact synthetic answers from the gold fixture. These are scorer
# fixtures, not model calls.
awk -F '\t' 'NR>1 && ($2=="*" || $2=="frontier") {print $1 "\t" $3 "\t" $4}' \
  "$REPO_DIR/evals/corpus/gold.tsv" > "$WORK/frontier.answers"
awk -F '\t' 'NR>1 && ($2=="*" || $2=="economy") {print $1 "\t" $3 "\t" $4}' \
  "$REPO_DIR/evals/corpus/gold.tsv" > "$WORK/economy.answers"

$EVAL score --profile frontier --split calibration --response "$WORK/frontier.answers" --out "$WORK/frontier-cal.score"
$EVAL score --profile economy --split calibration --response "$WORK/economy.answers" --out "$WORK/economy-cal.score"
[ "$(field STATUS "$WORK/frontier-cal.score")" = pass ] || fail 'perfect frontier calibration failed'
[ "$(field STATUS "$WORK/economy-cal.score")" = pass ] || fail 'perfect economy calibration failed'

sed 's/^cb\([0-9][0-9]*\)\tACTION\tESCALATE$/cb\1\tACTION=ESCALATE/' \
  "$WORK/economy.answers" > "$WORK/economy-two-column.answers"
$EVAL score --profile economy --split calibration --response "$WORK/economy-two-column.answers" \
  --out "$WORK/economy-two-column.score"
[ "$(field STATUS "$WORK/economy-two-column.score")" = pass ] \
  || fail 'strict scorer rejected the supported compact key=value TSV form'

cp "$WORK/frontier.answers" "$WORK/broken.answers"
sed 's/cb01\tACTION\tWAIT_FOR_SCOPE_CONFIRMATION/cb01\tACTION\tSTART_INTERVIEW/' \
  "$WORK/broken.answers" > "$WORK/broken.tmp"
mv "$WORK/broken.tmp" "$WORK/broken.answers"
rc=0
$EVAL score --profile frontier --split calibration --response "$WORK/broken.answers" --out "$WORK/broken.score" || rc=$?
[ "$rc" -eq 6 ] || fail 'a failed hard invariant did not exit 6'
[ "$(field STATUS "$WORK/broken.score")" = fail ] || fail 'a failed hard invariant was scored green'

cp "$WORK/economy.answers" "$WORK/judgment.answers"
printf 'cb01\tRECOMMENDATION\tSTART_INTERVIEW\n' >> "$WORK/judgment.answers"
rc=0
$EVAL score --profile economy --split calibration --response "$WORK/judgment.answers" --out "$WORK/judgment.score" || rc=$?
[ "$rc" -eq 6 ] || fail 'economy recommendation output did not fail the scorer'

# Three paired calibration samples establish measurement variance. These
# stable fixtures yield 50%% latency savings, zero observed variance, a frozen
# 10%% benefit threshold, and the 10-case holdout floor.
cat > "$WORK/frontier-cal.meta" <<EOF
ACTUAL_MODEL=selected:frontier;underlying=unreported
ACTUAL_EFFORT=high
LATENCY_SAMPLES_MS=200,210,190
EOF
cat > "$WORK/economy-cal.meta" <<EOF
ACTUAL_MODEL=selected:economy;underlying=unreported
ACTUAL_EFFORT=low
LATENCY_SAMPLES_MS=100,105,95
EOF
$EVAL freeze --host codex --frontier-score "$WORK/frontier-cal.score" \
  --economy-score "$WORK/economy-cal.score" --frontier-metadata "$WORK/frontier-cal.meta" \
  --economy-metadata "$WORK/economy-cal.meta" --out "$WORK/freeze.env"
[ "$(field STATUS "$WORK/freeze.env")" = frozen ] || fail 'calibration did not freeze'
[ "$(field REQUIRED_HOLDOUT_PER_CLASS "$WORK/freeze.env")" = 10 ] || fail 'holdout floor was not frozen at ten'
$EVAL prompt --profile economy --split holdout --freeze "$WORK/freeze.env" --out "$WORK/holdout.prompt"
grep -q '^he01' "$WORK/holdout.prompt" || fail 'fixture-bound freeze did not open holdout'
grep -q '^ce01' "$WORK/holdout.prompt" && fail 'holdout prompt leaked calibration cases'

$EVAL score --profile frontier --split holdout --response "$WORK/frontier.answers" --out "$WORK/frontier-hold.score"
$EVAL score --profile economy --split holdout --response "$WORK/economy.answers" --out "$WORK/economy-hold.score"
cp "$WORK/frontier-cal.meta" "$WORK/frontier-hold.meta"
cp "$WORK/economy-cal.meta" "$WORK/economy-hold.meta"
$EVAL decide --host codex --freeze "$WORK/freeze.env" --frontier-score "$WORK/frontier-hold.score" \
  --economy-score "$WORK/economy-hold.score" --frontier-metadata "$WORK/frontier-hold.meta" \
  --economy-metadata "$WORK/economy-hold.meta" --out "$WORK/decision.env"
[ "$(field STATUS "$WORK/decision.env")" = enabled ] || fail 'green, adequately sized holdout did not enable the route'

cp "$WORK/freeze.env" "$WORK/undersized-freeze.env"
sed 's/^REQUIRED_HOLDOUT_PER_CLASS=10$/REQUIRED_HOLDOUT_PER_CLASS=11/' "$WORK/undersized-freeze.env" > "$WORK/undersized.tmp"
mv "$WORK/undersized.tmp" "$WORK/undersized-freeze.env"
rc=0
$EVAL decide --host codex --freeze "$WORK/undersized-freeze.env" --frontier-score "$WORK/frontier-hold.score" \
  --economy-score "$WORK/economy-hold.score" --frontier-metadata "$WORK/frontier-hold.meta" \
  --economy-metadata "$WORK/economy-hold.meta" --out "$WORK/undersized.env" || rc=$?
[ "$rc" -ne 0 ] || fail 'undersized holdout enabled the route'
[ "$(field REASON "$WORK/undersized.env")" = undersized-holdout ] || fail 'undersized route was disabled for the wrong reason'

# Live execution is explicit and uses host-local model/effort controls. Fake
# CLIs prove the command boundary without touching a real account.
mkdir -p "$WORK/fake-bin"
cat > "$WORK/fake-bin/claude" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then echo 'fake-claude 1.0'; exit 0; fi
cat >/dev/null
cat "$FAKE_RESPONSE"
SH
cat > "$WORK/fake-bin/codex" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then echo 'fake-codex 1.0'; exit 0; fi
out=''
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then out="$2"; shift 2; else shift; fi
done
cat >/dev/null
cp "$FAKE_RESPONSE" "$out"
echo '{"type":"turn.completed","usage":{"total_tokens":321}}'
SH
chmod +x "$WORK/fake-bin/claude" "$WORK/fake-bin/codex"
PATH="$WORK/fake-bin:$PATH" FAKE_RESPONSE="$WORK/frontier.answers" \
  $EVAL run-live --host claude --profile frontier --split calibration --out-dir "$WORK/live-claude" --trials 1 >/dev/null
PATH="$WORK/fake-bin:$PATH" FAKE_RESPONSE="$WORK/economy.answers" \
  $EVAL run-live --host codex --profile economy --split calibration --out-dir "$WORK/live-codex" --trials 1 >/dev/null
grep -q '^ACTUAL_MODEL=selected:fable;underlying=unreported$' "$WORK/live-claude/metadata.env" \
  || fail 'Claude live metadata lost selected model attribution'
grep -q '^ACTUAL_MODEL=selected:gpt-5.6-luna;underlying=unreported$' "$WORK/live-codex/metadata.env" \
  || fail 'Codex live metadata lost selected model attribution'
grep -q '^REPORTED_TOKEN_SAMPLES=321$' "$WORK/live-codex/metadata.env" \
  || fail 'Codex live metadata lost reported tokens'

# Required scenario families remain present in the sanitized corpus.
for category in outline phases cursor routing scheduler blockers assurance-r1 assurance-r2 assurance-r3 exact-tree pr-resume pr-ci peer r3-recall review-precision; do
  awk -F '\t' -v category="$category" 'NR>1 && $4==category {found=1} END {exit !found}' \
    "$REPO_DIR/evals/corpus/behavior.tsv" || fail "corpus lost $category coverage"
done

echo 'eval tests: OK'
