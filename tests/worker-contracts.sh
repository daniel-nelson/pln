#!/usr/bin/env bash
# tests/worker-contracts.sh — worker-owned research contracts stay complete,
# host-neutral, and outside the generated coordinator skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-worker-contracts.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$3"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3"; return 0; }

for name in context-envelope preflight-research interview-research plan-review \
  plan-review-merge item-implementation final-verification; do
  file="$REPO_DIR/src/workers/$name.md"
  [ -s "$file" ] || fail "missing or empty worker contract: $file"
  has "$file" 'WORKER_ONLY_SENTINEL_' "$file has no worker-only sentinel"
  for host_term in Claude Codex 'spawn_agent' 'wait_agent' 'resume_agent' \
    'agentType' 'Agent tool' 'Workflow('; do
    hasnt "$file" "$host_term" "$file contains host mechanics: $host_term"
  done
done

review="$REPO_DIR/src/workers/plan-review.md"
has "$review" 'Finding nothing is permitted' 'review contract forces manufactured findings'
has "$review" 'file:line' 'review contract lost citation checking'
has "$review" 'RESULT_FILE=' 'native reviewer no longer returns a result pointer'

merge="$REPO_DIR/src/workers/plan-review-merge.md"
has "$merge" 'Reject, repair, or flag' 'merge contract lost its classification rubric'
has "$merge" 'never repair over a user-made decision' 'merge contract lost user-decision protection'
has "$merge" '4096-byte budget' 'merge contract lost its bounded envelope'

implementation="$REPO_DIR/src/workers/item-implementation.md"
envelope="$REPO_DIR/src/workers/context-envelope.md"
has "$envelope" 'REQUESTED_PROFILE:' 'result envelopes do not attribute the requested profile'
has "$envelope" 'ACTUAL_PROFILE:' 'result envelopes do not attribute the actual profile'
has "$envelope" 'ACTUAL_MODEL:' 'result envelopes do not attribute the actual model'
has "$envelope" 'ACTUAL_EFFORT:' 'result envelopes do not attribute the actual effort'
has "$implementation" 'When it says `worker`' 'implementation contract lost worker commit ownership'
has "$implementation" 'When it says `coordinator`' 'implementation contract lost coordinator commit ownership'
has "$implementation" 'host assignment owns which value applies' \
  'implementation contract started inferring host mechanics'
has "$implementation" 'BLOCKED:' 'implementation contract lost blocker handling'

verification="$REPO_DIR/src/workers/final-verification.md"
has "$verification" 'full gauntlet' 'verification contract lost the full gauntlet'
has "$verification" 'Do not fix a failure inline' 'verification contract may hide a failed gate'

preflight="$REPO_DIR/src/workers/preflight-research.md"
has "$preflight" '8192-byte envelope budget' 'pre-flight contract lost its budget'
has "$preflight" 'Locate, but do not read or summarize, prior decision records' \
  'pre-flight contract reads prior decisions instead of locating them'
has "$preflight" 'current git branch and status' 'pre-flight contract lost git-state discovery'

interview="$REPO_DIR/src/workers/interview-research.md"
has "$interview" '## Item mode' 'interview contract lost item research mode'
has "$interview" '## Decision-record-query mode' 'interview contract lost record-query mode'
has "$interview" 'Check exactly the one proposed ask-lane question' \
  'record research is no longer query-scoped'
has "$interview" 'Do not read prior plans or architecture-decision records in this mode' \
  'item research may trawl prior decisions'

"$REPO_DIR/bin/pln-generate" --host claude --out-dir "$WORK/claude" >/dev/null
"$REPO_DIR/bin/pln-generate" --host codex --out-dir "$WORK/codex" >/dev/null
for host in claude codex; do
  has "$WORK/$host/phases/pln/outline.md" 'src/workers/preflight-research.md' "$host outline phase does not reference pre-flight contract"
  has "$WORK/$host/phases/pln/interview.md" 'src/workers/interview-research.md' "$host interview phase does not reference interview contract"
  has "$WORK/$host/phases/pln/review-approval.md" 'src/workers/plan-review.md' "$host review phase does not reference review contract"
  has "$WORK/$host/phases/pln/review-approval.md" 'src/workers/plan-review-merge.md' "$host review phase does not reference review merge contract"
  has "$WORK/$host/phases/pln/implementation.md" 'src/workers/item-implementation.md' "$host implementation phase does not reference implementation contract"
  has "$WORK/$host/phases/pln/finish-ship.md" 'src/workers/final-verification.md' "$host finish phase does not reference verification contract"
  for file in "$WORK/$host/SKILL.md" "$WORK/$host/phases/pln/"*.md; do
    hasnt "$file" 'WORKER_ONLY_SENTINEL_' "$file contains worker-only contract prose"
    hasnt "$file" 'Do not inventory strengths or praise the plan' "$file embeds reviewer-only detail"
    hasnt "$file" 'Run the new test before the fix' "$file embeds implementation-worker detail"
  done
done

brief_dir="$WORK/brief"
mkdir -p "$brief_dir"
printf 'plan body\n' > "$brief_dir/PLAN.md"
"$REPO_DIR/bin/pln-build-review-brief" \
  --contract "$review" --plan "$brief_dir/PLAN.md" --root /example/root \
  --commit deadbeef --out "$brief_dir/review.md"
has "$brief_dir/review.md" 'Repository root: /example/root' 'review helper lost repository metadata'
has "$brief_dir/review.md" 'Repository commit: deadbeef' 'review helper lost commit metadata'
has "$brief_dir/review.md" 'WORKER_ONLY_SENTINEL_PLAN_REVIEW_V1' 'review helper omitted its contract'
has "$brief_dir/review.md" 'plan body' 'review helper omitted the plan'

echo "OK"
