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

for name in context-envelope evidence-collection preflight-research interview-research assurance-classification plan-review \
  plan-review-merge pr-review-merge execution-schedule item-implementation final-verification; do
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
has "$review" 'durable responsibilities and owners across the complete plan' \
  'broad review lost whole-plan responsibility composition'
has "$review" 'added, reused, retained, consolidated, replaced, and retired' \
  'broad review lost qualitative surface-state mapping'
has "$review" 'current owners, closest analogues, and sibling items' \
  'broad review no longer compares parallel planned surfaces'

merge="$REPO_DIR/src/workers/plan-review-merge.md"
has "$merge" 'Reject, repair, or flag' 'merge contract lost its classification rubric'
has "$merge" 'never repair over a user-made decision' 'merge contract lost user-decision protection'
has "$merge" '4096-byte budget' 'merge contract lost its bounded envelope'
has "$merge" 'responsibility, owner, or path' \
  'merge contract no longer groups related structural findings'
has "$merge" 'combined repair set against the complete plan' \
  'merge contract no longer checks structural repairs as a whole'
has "$merge" 'strictly dominant internal correction' \
  'merge contract turns clear-winner internal repairs into user gates'
has "$merge" 'visible behavior, scope, cost, risk appetite, irreversible or external state, or work outside' \
  'merge contract lost the canonical material-fork boundary'

implementation="$REPO_DIR/src/workers/item-implementation.md"
scheduling="$REPO_DIR/src/workers/execution-schedule.md"
envelope="$REPO_DIR/src/workers/context-envelope.md"
has "$envelope" 'REQUESTED_PROFILE:' 'result envelopes do not attribute the requested profile'
has "$envelope" 'ACTUAL_PROFILE:' 'result envelopes do not attribute the actual profile'
has "$envelope" 'ACTUAL_MODEL:' 'result envelopes do not attribute the actual model'
has "$envelope" 'ACTUAL_EFFORT:' 'result envelopes do not attribute the actual effort'
has "$envelope" 'ESCALATE:' 'result envelopes do not carry evidence-to-frontier escalation'
has "$implementation" 'When it says `worker`' 'implementation contract lost worker commit ownership'
has "$implementation" 'When it says `coordinator`' 'implementation contract lost coordinator commit ownership'
has "$implementation" 'host assignment owns which value applies' \
  'implementation contract started inferring host mechanics'
has "$implementation" 'BLOCKED:' 'implementation contract lost blocker handling'
has "$implementation" 'Never edit `PLAN.md`, `REVIEW.md`, the run manifest' \
  'implementation worker may race coordinator ledgers'
has "$implementation" 'equally capable smaller route' \
  'implementation worker no longer prefers coherent reuse over parallel ownership'
has "$implementation" 'Surface balance:' \
  'implementation results lost their qualitative surface balance'
has "$implementation" 'non-binding reversible mechanics' \
  'implementation worker may treat reversible plan mechanics as immutable'
has "$scheduling" $'ITEM\tDEPS\tLEASES\tCOHORT\tCONTEXT\tDIRTY_STATE' \
  'scheduling contract lost its deterministic node schema'
has "$scheduling" 'no cohort exceeds three nodes' 'scheduling contract lost the cohort cap'
has "$scheduling" 'Unknown targets or uncertain independence use `UNKNOWN`' \
  'scheduling contract no longer serializes uncertainty'
has "$scheduling" 'Known consolidation, replacement, or retirement targets' \
  'scheduling leases omit known anti-bloat write targets'

verification="$REPO_DIR/src/workers/final-verification.md"
has "$verification" 'full gauntlet' 'verification contract lost the full gauntlet'
has "$verification" 'Recompute the fingerprint' 'verification contract lost exact-candidate invalidation'

assurance="$REPO_DIR/src/workers/assurance-classification.md"
has "$assurance" 'Classify meaning, not line count' 'assurance worker regressed to size-only risk'
has "$assurance" 'Unknown or conflicting risk' 'assurance worker no longer fails closed'
has "$assurance" 'SPECIALIST_AREAS=' 'assurance worker lost deterministic roster inputs'
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
has "$interview" 'current owner, closest analogues, and material producers, callers, and consumers' \
  'item research lost the existing-system ownership map'
has "$interview" 'reuse, extension, consolidation, replacement, and directly caused retirement routes' \
  'item research no longer compares additive work with smaller system-fit routes'
has "$interview" 'localized correction inside an established owner' \
  'item research applies the heavy system-fit comparison to local corrections'
has "$interview" 'specific acceptance criterion or invariant' \
  'item research permits unsupported claims of distinctness'

evidence="$REPO_DIR/src/workers/evidence-collection.md"
has "$evidence" 'mechanically closed' 'evidence worker is not limited to closed facts'
has "$evidence" 'ESCALATE: frontier' 'evidence worker lost immediate frontier escalation'
has "$evidence" 'must not recommend' 'evidence worker may leak judgment into its result'

pr_merge="$REPO_DIR/src/workers/pr-review-merge.md"
has "$pr_merge" 'raw artifact paths' 'PR merge worker no longer owns raw review artifacts'
has "$pr_merge" '`verified`, `unverified`, or `disproved`' 'PR merge worker retained self-scored confidence'
has "$pr_merge" '4096-byte budget' 'PR merge worker lost its bounded coordinator result'
has "$pr_merge" 'Findings without `structural_evidence` remain valid' \
  'PR merge worker broke legacy finding artifacts'
has "$pr_merge" 'role-tagged owners, analogues, and direct consumers' \
  'PR merge worker lost structural evidence validation'
has "$pr_merge" 'bin/pln-assurance repair-key --kind structural' \
  'PR merge worker lost deterministic structural repair identity'
has "$pr_merge" 'private reachability' \
  'PR merge worker can auto-route deletion without private reachability proof'

"$REPO_DIR/bin/pln-generate" --host claude --out-dir "$WORK/claude" >/dev/null
"$REPO_DIR/bin/pln-generate" --host codex --out-dir "$WORK/codex" >/dev/null
for host in claude codex; do
  has "$WORK/$host/phases/pln/outline.md" 'src/workers/preflight-research.md' "$host outline phase does not reference pre-flight contract"
  has "$WORK/$host/phases/pln/interview.md" 'src/workers/interview-research.md' "$host interview phase does not reference interview contract"
  has "$WORK/$host/phases/pln/review-approval.md" 'src/workers/plan-review.md' "$host review phase does not reference review contract"
  has "$WORK/$host/phases/pln/review-approval.md" 'src/workers/plan-review-merge.md' "$host review phase does not reference review merge contract"
  has "$WORK/$host/phases/pln/implementation.md" 'src/workers/item-implementation.md' "$host implementation phase does not reference implementation contract"
  has "$WORK/$host/phases/pln/implementation.md" 'src/workers/execution-schedule.md' "$host implementation phase does not reference scheduling contract"
  has "$WORK/$host/phases/pln/implementation.md" 'qualitative surface balance' \
    "$host coordinator no longer validates implementation surface balance"
  has "$WORK/$host/phases/pln/implementation.md" 'adopted system-fit outcome' \
    "$host coordinator no longer checks the bounded diff against adopted ownership"
  has "$WORK/$host/phases/pln/finish-ship.md" 'src/workers/final-verification.md' "$host finish phase does not reference verification contract"
  has "$WORK/$host/SKILL.md" 'at most two exact operations' "$host /pln router lost the direct lookup budget"
  has "$WORK/$host/SKILL.md" 'routing.tsv' "$host /pln router lost the local routing ledger"
  has "$WORK/$host/pln-pr/SKILL.md" 'at most two exact operations' "$host /pln-pr router lost the direct lookup budget"
  has "$WORK/$host/pln-pr/SKILL.md" 'routing.tsv' "$host /pln-pr router lost the local routing ledger"
  has "$WORK/$host/phases/pln/outline.md" 'Preflight is judgment work' "$host preflight no longer stays frontier"
  has "$WORK/$host/phases/pln/interview.md" 'candidate prior-record matches' "$host interview lost the prior-record evidence/judgment split"
  has "$WORK/$host/phases/pln/interview.md" 'strongest existing-owner route' \
    "$host interview no longer gates new durable concepts on system fit"
  has "$WORK/$host/phases/pln/interview.md" 'do not admit the new concept' \
    "$host interview does not block unsupported additive ownership"
  has "$WORK/$host/phases/pln/interview.md" 'even when plan review is disabled' \
    "$host system-fit gate incorrectly depends on plan review"
  has "$WORK/$host/phases/pln/interview.md" 'no direct retirement found' \
    "$host interview no longer records the directly caused retirement outcome"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'Possibly unbounded metadata' "$host PR scope phase lost file-first metadata collection"
  has "$WORK/$host/phases/pln-pr/review.md" 'src/workers/pr-review-merge.md' "$host PR review phase lost file-first merge ownership"
  has "$WORK/$host/phases/pln-pr/review.md" 'Never open a reviewer or peer result' "$host PR review reads raw findings into the coordinator"
  has "$WORK/$host/phases/pln-pr/review.md" 'current owners, closest analogues, and direct callers or consumers' \
    "$host broad PR review lost structural traversal"
  has "$WORK/$host/phases/pln-pr/review.md" 'structural_evidence?' \
    "$host PR finding schema lost additive structural evidence"
  has "$WORK/$host/phases/pln-pr/fix.md" 'src/workers/execution-schedule.md' "$host PR fix phase does not reference scheduling contract"
  has "$WORK/$host/phases/pln-pr/fix.md" 'repository-native discovery' \
    "$host PR fix phase can delete private surface without native discovery"
  has "$WORK/$host/phases/pln-pr/fix.md" 'rerun the structural reference check and consumer map' \
    "$host post-fix assurance lost structural closure"
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
