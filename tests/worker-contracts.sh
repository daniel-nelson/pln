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
  plan-review-merge pr-review-merge execution-schedule item-implementation final-verification \
  simplification-map simplification-synthesis behavior-preservation; do
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
has "$envelope" 'Measure and trim before you finalize' \
  'envelope contract lost its measure-and-trim step'
has "$envelope" 'wc -c' 'envelope contract no longer names how to measure the result'
# The envelope shape has one owner, and it is the contract above. The reader
# that refuses a malformed envelope carries the field names as a list, so this
# pins that list to the contract: a field added, renamed or dropped there and
# nowhere else is the drift the reader was built to stop, reproduced inside it.
contract_fields="$(awk '
  state == 0 && /^```text$/ { state = 1; next }
  state == 1 && /^```$/ { state = 2; next }
  state == 1 && /^[A-Z][A-Z_]*:/ { sub(/:.*/, ""); print }
' "$envelope" | sort)"
[ -n "$contract_fields" ] || fail "no envelope fields found in $envelope"
reader_fields="$(awk -F"'" '/^REQUIRED_FIELDS=/ { print $2; exit }' \
  "$REPO_DIR/bin/pln-read-envelope" | tr ' ' '\n' | grep -v '^$' | sort)"
[ -n "$reader_fields" ] || fail "bin/pln-read-envelope declares no required fields"
[ "$contract_fields" = "$reader_fields" ] || fail \
  "bin/pln-read-envelope's required fields disagree with $envelope"
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
has "$implementation" 'Retained behavior:' \
  'implementation surface balance no longer names retained-behavior evidence'
has "$implementation" 'behavior-preservation.md' \
  'implementation stopped using the shared behavior-preservation owner'
has "$implementation" 'non-binding reversible mechanics' \
  'implementation worker may treat reversible plan mechanics as immutable'
has "$scheduling" $'ITEM\tDEPS\tLEASES\tCOHORT\tCONTEXT\tDIRTY_STATE' \
  'scheduling contract lost its deterministic node schema'
# A cohort ends at a semantic boundary, not a count. The old rule capped every
# cohort at three nodes with no stated reason, in a list where every other
# boundary — subsystem, risk, skill, repository, corrected premise — is about
# what the work is. The number is now a backstop against a pathological plan,
# and says so.
has "$scheduling" 'A cohort ends where the work stops being the same work, not at a count' \
  'scheduling contract no longer bounds cohorts by the work rather than a number'
has "$scheduling" 'not the criterion' \
  'scheduling contract presents its numeric backstop as the criterion'
hasnt "$scheduling" 'no cohort exceeds three nodes' \
  'scheduling contract still caps cohorts at an unexplained three'
# Linear execution: the schedule decides order, writes and context reuse only.
has "$scheduling" 'Execution is linear' \
  'scheduling contract no longer says execution is linear'
has "$scheduling" 'nothing you record decides concurrency' \
  'scheduling contract still implies its output selects concurrent work'
has "$scheduling" 'Unknown targets or uncertain independence use `UNKNOWN`' \
  'scheduling contract no longer serializes uncertainty'
has "$scheduling" 'Known consolidation, replacement, or retirement targets' \
  'scheduling leases omit known anti-bloat write targets'

verification="$REPO_DIR/src/workers/final-verification.md"
has "$verification" 'full gauntlet' 'verification contract lost the full gauntlet'
has "$verification" 'Recompute the fingerprint' 'verification contract lost exact-candidate invalidation'

# A cross-model peer is another vendor's model following your instruction as
# best it reads it. The brief already says "no code fence"; the first Codex run
# with a working peer still discarded a complete adversarial review because the
# payload arrived fenced, losing model-family independence to three backticks.
merge_contract="$REPO_DIR/src/workers/pr-review-merge.md"
has "$merge_contract" 'A single enclosing Markdown code fence is transport, not content' \
  'the merge contract still fails a reader over an enclosing code fence'
has "$merge_contract" 'reject what is still unparseable' \
  'stripping a fence was allowed to soften the rest of validation'

# A refused command is not a verification result, and for several releases this
# contract said so and denied it in the same breath: a command that could not
# run here was said to destroy the attempt. It does not. A refusal says nothing
# about the tree, so the recorded set simply holds a command with no result —
# incomplete, not failed and not destroyed. The surviving half was pinned below
# all along; the clause that caused the defect was pinned by nothing, so it is
# now banned by name.
hasnt "$verification" 'destroys the attempt' \
  'final-verification contract again spends the attempt on an environment refusal'
has "$verification" 'A refused command leaves the gauntlet incomplete — not failed, and not destroyed.' \
  'final-verification contract lost the incomplete-not-failed-not-destroyed outcome'
has "$verification" 'An environment refusal is not a verification result' \
  'final-verification contract reports environment denials as failed verification'
# The worker records and stops, and is granted no rerun on purpose: the
# privilege boundary runs between coordinator and child, so a rerun permission
# written here is one its holder could never exercise. Where an incomplete
# gauntlet gets resolved is stated, not left implied.
has "$verification" 'Mark the aggregate environment-blocked, name every refused command beside the exact refusal, and stop there' \
  'final-verification worker no longer records every refusal and stops'
has "$verification" 'clearing a refusal is not work you can do' \
  'final-verification worker was handed a rerun it has no access to perform'
has "$verification" 'decided where that access lives' \
  'final-verification contract no longer defers an incomplete gauntlet to the access holder'
has "$verification" 'the aggregate result — environment-blocked where anything was refused' \
  'final-verification results no longer report a refusal in the aggregate'
# One run spent four attempts learning its commands' requirements from inside
# the fingerprinted run: a worker has no terminal, and network, filesystem and
# browser access are settled at a first invocation or not at all. Both pins
# below still sit on that pre-flight guard, which was rewritten around them
# rather than moved — "you have no terminal" survived verbatim. The guard now
# also says where it stops: whether the coordinator holds access the worker was
# not given is a fact about who runs a command, discoverable from no
# documentation, and the guard hands that case to the rule above instead of
# blaming the worker for missing it.
has "$verification" 'Establish that the gauntlet can run before you run it' \
  'final-verification contract learns its requirements from a burned attempt'
has "$verification" 'you have no terminal' \
  'final-verification contract does not say the run is non-interactive'
has "$verification" 'It cannot settle access' \
  'pre-flight guard again claims a privilege boundary it cannot see'
has "$verification" 'not a pre-flight obligation and a refusal of that kind was not yours to foresee' \
  'pre-flight guard again blames the worker for a refusal it could not have foreseen'
has "$verification" 'the refused-command rule below is where it is handled' \
  'pre-flight guard no longer names the rule that owns a refusal'
# No toolchain is named: a project states the unattended form of its own
# commands, and pln does not learn one package manager or one browser.
for banned in 'CI=true' pnpm Puppeteer Firefox npm yarn; do
  hasnt "$verification" "$banned" \
    "final-verification contract hardcodes $banned instead of reading the project's instructions"
done

# The qualified pass belongs to the shared assurance policy, not to /pln-pr
# alone. Three skills include that fragment, and a local exception in one of
# them to a rule the fragment states is exactly the drift being guarded here:
# the reuse rule and the rerun outcome have to be written by the same owner.
policy="$REPO_DIR/src/shared/assurance-policy.md"
has "$policy" 'the outcome is recorded as a **qualified pass**' \
  'assurance policy lost the qualified-pass outcome for a rerun refused command'
has "$policy" 'not the reuse of a green this rule governs' \
  'assurance policy no longer separates a qualified pass from reusing a green under a matching seal'


assurance="$REPO_DIR/src/workers/assurance-classification.md"
has "$assurance" 'Classify meaning, not line count' 'assurance worker regressed to size-only risk'
has "$assurance" 'Unknown or conflicting risk' 'assurance worker no longer fails closed'
has "$assurance" 'SPECIALIST_AREAS=' 'assurance worker lost deterministic roster inputs'
has "$verification" 'Do not fix a failure inline' 'verification contract may hide a failed gate'

simplify_map="$REPO_DIR/src/workers/simplification-map.md"
simplify_synthesis="$REPO_DIR/src/workers/simplification-synthesis.md"
behavior_preservation="$REPO_DIR/src/workers/behavior-preservation.md"
behavior_owner_count="$(grep -RFl -- '# Shared behavior-preservation contract' "$REPO_DIR/src" | wc -l | tr -d ' ')"
[ "$behavior_owner_count" = 1 ] || fail "behavior preservation must have exactly one shared policy owner"
has "$simplify_map" 'concepts, responsibilities, and owners' \
  'simplification mapping lost concept/ownership discovery'
has "$simplify_map" 'duplicated policy' 'simplification mapping lost duplicate-policy discovery'
has "$simplify_map" 'compatibility paths' 'simplification mapping lost compatibility discovery'
has "$simplify_map" 'Do not propose edits, implement, delete, commit, or touch coordinator ledgers' \
  'simplification mapper crossed into synthesis, implementation, or coordination ownership'
has "$simplify_synthesis" 'nothing worth changing' \
  'simplification synthesis forces churn in a coherent system'
has "$simplify_synthesis" 'consumer closure' \
  'simplification synthesis permits deletion without bounded consumers'
has "$simplify_synthesis" 'Concept reduction outranks line reduction' \
  'simplification synthesis regressed to a line-deletion target'
has "$simplify_synthesis" 'Do not edit product files, plans, review ledgers, or git state' \
  'simplification synthesis crossed into implementation or coordination ownership'
has "$simplify_synthesis" 'behavior-preservation.md' \
  'simplification synthesis stopped using the shared behavior-preservation owner'

# One shared owner protects both simplification and structural repair from
# mistaking source reachability for preserved behavior.
has "$behavior_preservation" 'removal, replacement, or consolidation' \
  'behavior preservation no longer covers every simplifying mutation'
has "$behavior_preservation" 'direct and indirect consumers' \
  'behavior preservation lost indirect-consumer coverage'
has "$behavior_preservation" 'externally observable behavior' \
  'behavior preservation lost observable-boundary coverage'
has "$behavior_preservation" 'Private reachability, an absence of references' \
  'private or reference evidence can masquerade as behavioral proof'
has "$behavior_preservation" 'post-change tests alone' \
  'post-only tests can masquerade as behavioral proof'
has "$behavior_preservation" 'recorded pre-change source' \
  'behavior preservation lost its baseline characterization'
has "$behavior_preservation" 'Existing behavior-oriented tests are the primary safety net' \
  'behavior preservation no longer prefers existing behavior specs'
has "$behavior_preservation" 'implementation-detail tests do not establish the behavioral boundary' \
  'implementation-coupled tests can masquerade as behavior coverage'
has "$behavior_preservation" 'recorded pre-change tree' \
  'behavior preservation no longer runs the safety net on the exact baseline tree'
has "$behavior_preservation" 'fails meaningfully when the protected behavior is deliberately broken' \
  'new characterization need not prove that it detects broken behavior'
has "$behavior_preservation" 'same admitted behavior suite' \
  'behavior preservation lost equivalent pre/post suite execution'
has "$behavior_preservation" 'full repository gauntlet remains the final regression floor' \
  'behavior preservation displaced the final repository gauntlet'
has "$behavior_preservation" 'compare the post-change result' \
  'behavior preservation lost its pre/post comparison'
has "$behavior_preservation" 'Public, compatibility, persisted/stateful, or uncertain' \
  'compatibility or state uncertainty no longer retains the surface or blocks'
has "$behavior_preservation" '`no change`' \
  'behavior preservation forces churn when no safe candidate exists'
has "$behavior_preservation" 'Safety disposition:' \
  'behavior preservation lost its explicit safety-disposition record'
has "$behavior_preservation" 'Baseline suite/outcome:' \
  'behavior preservation disposition lost the exact baseline conjunct'
has "$behavior_preservation" 'Fault detection:' \
  'behavior preservation disposition lost meaningful new-test fault detection'
has "$behavior_preservation" 'Consumer closure:' \
  'behavior preservation disposition lost direct/indirect/dynamic closure'
has "$behavior_preservation" 'Observable/state effects:' \
  'behavior preservation disposition lost externally observable and state effects'
has "$behavior_preservation" 'Public/compatibility classification:' \
  'behavior preservation disposition lost public/compatibility classification'
has "$behavior_preservation" 'Comparable pre/post route:' \
  'behavior preservation disposition lost the comparable pre/post route'
has "$behavior_preservation" 'Consequential/destructive uncertainty:' \
  'behavior preservation disposition lost consequential/destructive uncertainty'
has "$behavior_preservation" 'The default is `retain`' \
  'behavior preservation no longer defaults to retention'
has "$behavior_preservation" 'Only `admit` when every required conjunct is `pass`' \
  'behavior preservation can admit an incomplete safety proof'
has "$behavior_preservation" 'missing, malformed, `unknown`, or `fail`' \
  'behavior preservation does not fail closed on malformed or missing proof'
has "$behavior_preservation" 'Structural clues cannot override' \
  'structural clues can override the safety veto'
has "$simplify_synthesis" 'exact runnable baseline commands or scenarios and their recorded outcomes' \
  'simplification synthesis admits candidates without executable baseline evidence'
has "$simplify_synthesis" '`capture during implementation` is not evidence' \
  'simplification synthesis may defer its admission gate into implementation'
has "$simplify_synthesis" 'one complete `Safety disposition` record per candidate' \
  'simplification synthesis does not return a complete disposition per candidate'
has "$simplify_synthesis" '`retain` candidate' \
  'simplification synthesis drops retained candidates instead of reporting their veto'
has "$implementation" 'rerun the same admitted behavior suite' \
  'implementation no longer validates equivalent pre/post behavior evidence'

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
has "$pr_merge" 'behavior-preservation.md' \
  'PR merge stopped using the shared behavior-preservation owner'
has "$pr_merge" 'exact runnable baseline commands or scenarios and recorded outcomes' \
  'PR merge can admit structural repair without executable baseline evidence'
has "$pr_merge" 'one complete `Safety disposition` record' \
  'PR merge does not normalize structural repairs to the shared disposition'
has "$pr_merge" 'missing or malformed disposition is `retain`' \
  'PR merge does not default malformed structural proof to retention'

# A reproduction that constructs the offending state itself proves the state is
# possible, never that anything ships it. One run filed a critical emergency-stop
# bypass whose only two constructors were two lines in the spec file the finding
# cited as its own proof, then spent a blocker, a user decision, and a repair
# workstream on it. The merge worker is where the claim gets checked, so the
# demotion has to live here and not only in the reviewer brief.
has "$pr_merge" 'never take the claim' \
  'PR merge accepts a reader reachability claim without confirming it'
has "$pr_merge" 'is `informational` whatever the reader marked it' \
  'PR merge lets an unreachable finding keep a critical severity'
has "$pr_merge" 'never routed `needs-decision`, and never raises a blocker' \
  'PR merge can still spend a user decision on a test-only finding'

# Even a reachable finding can carry a cathedral. The same run's proposed repair
# for two dead fields on a persisted type was to validate every envelope against
# its durable journal payload, and the question that reached the user offered
# that design as its only option. 1.76.0 made a /pln interview name the simpler
# route it passed over; this is the review's copy of that field.
has "$pr_merge" 'Persist each finding'"'"'s `smaller_fix` verbatim' \
  'PR merge drops the smaller repair a reader passed over'

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
  has "$WORK/$host/phases/pln/implementation.md" 'retained behavior' \
    "$host coordinator no longer validates retained-behavior evidence"
  has "$WORK/$host/phases/pln/implementation.md" 'adopted system-fit outcome' \
    "$host coordinator no longer checks the bounded diff against adopted ownership"
  has "$WORK/$host/phases/pln/implementation.md" 'same admitted behavior suite' \
    "$host implementation checkpoint lost equivalent pre/post behavior validation"
  has "$WORK/$host/phases/pln/finish-ship.md" 'src/workers/final-verification.md' "$host finish phase does not reference verification contract"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'src/workers/simplification-map.md' \
    "$host simplification phase does not reference its mapping contract"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'src/workers/simplification-synthesis.md' \
    "$host simplification phase does not reference its synthesis contract"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'src/workers/behavior-preservation.md' \
    "$host simplification phase stopped using the shared behavior-preservation owner"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'exact runnable baseline commands or scenarios and recorded outcomes' \
    "$host simplification phase admits candidates without baseline execution evidence"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" '`capture during implementation`' \
    "$host simplification phase may postpone behavior admission evidence"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'Treat an omitted or malformed disposition as `retain`' \
    "$host simplification coordinator does not default-retain malformed proof"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'Only an `admit` record with every required conjunct marked `pass`' \
    "$host simplification coordinator does not recognize complete admission proof"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" 'convert it to retained evidence' \
    "$host simplification coordinator does not demote incomplete admission"
  has "$WORK/$host/phases/pln-simplify/map-synthesize.md" '`nothing worth changing`' \
    "$host simplification coordinator lost the no-change outcome"
  has "$WORK/$host/phases/pln-simplify/verify-record.md" 'src/workers/final-verification.md' \
    "$host simplification recording does not reuse final verification"
  has "$WORK/$host/phases/pln-pr/review.md" 'reached_by: string' \
    "$host review phase no longer requires reachability on every finding"
  has "$WORK/$host/phases/pln-pr/review.md" 'or the literal `test-only`' \
    "$host reviewer brief lost the test-only reachability answer"
  has "$WORK/$host/phases/pln-pr/fix.md" '`reached_by: test-only` is never one of these questions' \
    "$host fix phase can route an unreachable finding to a user decision"
  has "$WORK/$host/phases/pln-pr/review.md" 'smaller_fix: string' \
    "$host review phase no longer asks for the smaller repair passed over"
  has "$WORK/$host/phases/pln-pr/review.md" 'the literal `none found`' \
    "$host reviewer brief lost the no-smaller-repair answer"
  has "$WORK/$host/phases/pln-pr/fix.md" 'carries the finding'"'"'s `smaller_fix` beside its proposed fix' \
    "$host decision question can present one design as the only option"
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
  has "$WORK/$host/phases/pln-pr/review.md" 'src/workers/behavior-preservation.md' \
    "$host PR review stopped using the shared behavior-preservation owner"
  has "$WORK/$host/phases/pln-pr/review.md" 'exact baseline commands/scenarios and recorded outcomes' \
    "$host PR review can admit repair without executable baseline evidence"
  has "$WORK/$host/phases/pln-pr/review.md" 'implementation-detail tests' \
    "$host PR review can substitute implementation-coupled coverage"
  has "$WORK/$host/phases/pln-pr/review.md" 'Safety disposition' \
    "$host PR merge does not persist the shared safety disposition"
  has "$WORK/$host/phases/pln-pr/fix.md" 'src/workers/execution-schedule.md' "$host PR fix phase does not reference scheduling contract"
  has "$WORK/$host/phases/pln-pr/fix.md" 'repository-native discovery' \
    "$host PR fix phase can delete private surface without native discovery"
  has "$WORK/$host/phases/pln-pr/fix.md" 'src/workers/behavior-preservation.md' \
    "$host PR fix phase stopped using the shared behavior-preservation owner"
  has "$WORK/$host/phases/pln-pr/fix.md" 'same admitted behavior suite' \
    "$host PR fix phase lost equivalent pre/post behavior execution"
  has "$WORK/$host/phases/pln-pr/fix.md" 'full repository gauntlet remains the final regression floor' \
    "$host PR fix phase displaced the final gauntlet"
  has "$WORK/$host/phases/pln-pr/fix.md" 'missing or malformed record is `retain`' \
    "$host PR repair does not fail closed on a missing disposition"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Only a complete `admit` record' \
    "$host PR repair does not require complete admission proof"
  has "$WORK/$host/phases/pln-pr/fix.md" 'rerun the structural reference check and consumer map' \
    "$host post-fix assurance lost structural closure"
  # Step 7 carries its own copy of the refusal rule and has to: bin/pln-generate
  # resolves pln:include only in src/**/*.core.md, so a phase file and
  # src/workers/final-verification.md cannot share one fragment. Two copies of
  # one rule drift, and a single presence check per file would prove only that
  # each contains one literal this script names. So the substance is asserted
  # condition by condition, here and on the worker copy above.
  ship_watch="$WORK/$host/phases/pln-pr/ship-watch.md"
  step7="$WORK/$host-step7.md"
  awk '/^### Step 7\./ { s = 1 } /^### Step 8\./ { s = 0 } s' "$ship_watch" > "$step7"
  [ -s "$step7" ] || fail "$host ship-watch phase has no Step 7 section"
  has "$step7" 'A refused command leaves the gauntlet incomplete — not failed, and not destroyed.' \
    "$host Step 7 lost the incomplete-not-failed-not-destroyed outcome the worker contract also states"
  has "$step7" 'not a verification result' \
    "$host Step 7 no longer says an environment refusal is not a verification result"
  has "$step7" 'mark it refused rather than failed, and run the remaining commands' \
    "$host Step 7 brief turns a refusal into a failure or stops the run on one"
  hasnt "$ship_watch" 'destroys the attempt' \
    "$host Step 7 again spends the attempt on an environment refusal"
  # The rerun is the coordinator's, and each condition on it is separately
  # load-bearing. Drop the completeness precondition and a never-executed
  # command passes; drop the branch-caused exclusion and a branch that adds an
  # unvendored dependency ships green, because the rerun is granted the network
  # the branch itself now needs.
  has "$step7" 'never read back into coordinator context' \
    "$host Step 7 rerun reads the raw gauntlet log into coordinator context"
  has "$step7" 'which command was refused, the exact refusal, and what access the rerun was granted' \
    "$host Step 7 rerun no longer records all three facts"
  has "$step7" 'A command that never executed makes the gauntlet incomplete, and an incomplete gauntlet is not a pass' \
    "$host Step 7 lost the completeness precondition on combining a rerun with the recorded run"
  has "$step7" "Where the branch's own diff touches the refused command" \
    "$host Step 7 lets a rerun repair a refusal the branch itself caused"
  has "$step7" 'the refusal *is* a verification result and the rerun does not repair it' \
    "$host Step 7 states the branch-caused exclusion without its consequence"
  has "$step7" 'What still forces a whole repeat is the tree changing or the command set changing; a refusal does neither' \
    "$host Step 7 no longer says what still forces the whole gauntlet to repeat"
  # The one-agent rule and the fact that makes it safe sit eight lines apart, and
  # the clause joining them is the whole of the edit that closed that gap. Three
  # pins, because the fact and the rule can each survive while the connective
  # between them is deleted — which is exactly the state the rule was written
  # out of, a bare prohibition whose reason sits seven paragraphs away.
  has "$step7" 'Step 7 spawns exactly one agent, and there is no adjudication worker' \
    "$host Step 7 no longer says it spawns one agent and adjudicates nothing"
  has "$step7" 'Evidence the coordinator already holds is never handed to a second agent to be judged' \
    "$host Step 7 can hand evidence it already holds to a second agent"
  has "$step7" 'An exit status is bounded metadata, not a log' \
    "$host Step 7 lost the fact that lets one agent hold the context firewall"
  has "$step7" 'so the context firewall holds without a second agent between you and the result' \
    "$host Step 7 states the bounded-metadata fact without saying it is why one agent suffices"
  # A rerun at elevated access can pass because of the privilege, and nothing
  # tells that apart from a command that merely needed it. So the result is
  # disclosed rather than absorbed into a green nobody can audit.
  has "$step7" 'What that produces is a qualified pass, not a green' \
    "$host Step 7 reports a rerun refused command as an unqualified green"
  has "$step7" 'green except the named command, which ran at elevated access' \
    "$host Step 7 no longer discloses which command ran at elevated access"
  has "$step7" 'carrying both environment hashes' \
    "$host Step 7 qualified pass no longer carries both environment hashes"
  has "$step7" 'A command can pass *because* of the privilege it was rerun under' \
    "$host Step 7 qualifies the pass without saying what the qualification is for"
  # The brief is inline because a real run searched src/workers, found the
  # contract addressed to another skill, and followed the wrong rule.
  has "$step7" 'This step carries its worker brief inline, below — there is no separate contract file for the final gauntlet.' \
    "$host Step 7 no longer declares its worker brief self-contained"
  hasnt "$ship_watch" 'final-verification' \
    "$host ship-watch phase sends the final-gauntlet worker to the contract it must not read"
  hasnt "$step7" 'src/workers/' \
    "$host Step 7 points its worker at a contract file instead of the inline brief"
  # Scoped to the brief itself, not the file: ship-watch legitimately names a
  # host in its pln:only blocks, while the brief is the part a worker reads, and
  # this step is authorized to word it for its own register. The quoted block is
  # the brief, so the extraction anchors on the quoting rather than on any phrase
  # inside it.
  brief="$WORK/$host-step7-brief.md"
  awk '/^"/ { print; n = 1 } END { exit !n }' "$step7" > "$brief" \
    || fail "$host Step 7 lost its inline gauntlet brief"
  for brief_term in Claude Codex claude codex sandbox 'gh pr' glab npm 'Agent tool' \
    'spawn_agent' 'wait_agent' 'Workflow('; do
    hasnt "$brief" "$brief_term" \
      "$host Step 7 brief names a host, CLI or sandbox product: $brief_term"
  done
  # The same refusal rule is coordinator text in three skills now, and
  # bin/pln-generate resolves pln:include only in src/**/*.core.md, so none of
  # the three can share one fragment with the worker contract or with each
  # other. The first pass at this fix reached /pln-pr alone; /pln and
  # /pln-simplify went on treating a refusal as a plain verification failure,
  # and /pln-simplify additionally deleted the unpublished candidate ref on
  # one — destroying the run's own work over a permissions problem that said
  # nothing about the tree. Each condition is asserted separately, the way the
  # /pln-pr copy above is, because one presence check per file would prove only
  # that each holds a single literal this script names.
  finish_ship="$WORK/$host/phases/pln/finish-ship.md"
  finish_step7="$WORK/$host-finish-step7.md"
  awk '/^### Step 7\./ { s = 1 } /^### Step 8\./ { s = 0 } s' "$finish_ship" > "$finish_step7"
  [ -s "$finish_step7" ] || fail "$host finish-ship phase has no Step 7 section"
  # Both sections are extracted rather than read whole, and for the same
  # reason: each file also includes the shared assurance policy, which states
  # the qualified-pass outcome in its own words. A whole-file check would be
  # answered by that include no matter what the step itself said.
  verify_record="$WORK/$host/phases/pln-simplify/verify-record.md"
  verify_steps="$WORK/$host-verify-steps.md"
  awk '/^After ordinary checkpoints:/ { s = 1 } /^Set `Phase: complete`/ { s = 0 } s' \
    "$verify_record" > "$verify_steps"
  [ -s "$verify_steps" ] || fail "$host /pln-simplify recording has no candidate-verification steps"
  for coordinator in "$finish_step7" "$verify_steps"; do
    has "$coordinator" 'A refused command leaves the gauntlet incomplete — not failed, and not destroyed.' \
      "$coordinator lost the incomplete-not-failed-not-destroyed outcome the shipped copy states"
    has "$coordinator" 'is not a verification result' \
      "$coordinator no longer says an environment refusal is not a verification result"
    has "$coordinator" 'so the rerun is yours: run exactly that one command' \
      "$coordinator no longer gives the rerun to the coordinator that holds the access"
    has "$coordinator" 'which command was refused, the exact refusal, and what access the rerun was granted' \
      "$coordinator rerun no longer records all three facts"
    has "$coordinator" 'never read back into coordinator context' \
      "$coordinator rerun reads the raw gauntlet log into coordinator context"
    has "$coordinator" 'A command that never executed makes the gauntlet incomplete, and an incomplete gauntlet is not a pass' \
      "$coordinator lost the completeness precondition on combining a rerun with the recorded run"
    has "$coordinator" 'the refusal *is* a verification result and the rerun does not repair it' \
      "$coordinator lets a rerun repair a refusal the change under test caused"
    has "$coordinator" 'What still forces a whole repeat is the tree changing or the command set changing; a refusal does neither' \
      "$coordinator no longer says what still forces the whole gauntlet to repeat"
    has "$coordinator" 'What that produces is a qualified pass, not a green' \
      "$coordinator reports a rerun refused command as an unqualified green"
    has "$coordinator" 'green except the named command, which ran at elevated access' \
      "$coordinator no longer discloses which command ran at elevated access"
    has "$coordinator" 'carrying both environment hashes' \
      "$coordinator qualified pass no longer carries both environment hashes"
    has "$coordinator" 'A command can pass *because* of the privilege it was rerun under' \
      "$coordinator qualifies the pass without saying what the qualification is for"
    has "$coordinator" 'the qualification is disclosed rather than absorbed into a green nobody can audit' \
      "$coordinator absorbs a rerun at elevated access into a green nobody can audit"
    # The rule is written in terms of what to do when a command is refused,
    # never of which host refuses: one host's parent/child privilege boundary
    # is the only instance recorded anywhere, and neither of these two skills
    # asserts a host fact by carrying this.
    rule="$WORK/$host-refusal-rule.md"
    awk '/A refused command leaves the gauntlet incomplete/, /qualification is disclosed rather than absorbed/' \
      "$coordinator" > "$rule"
    [ -s "$rule" ] || fail "$coordinator lost the refusal rule block"
    for rule_term in Claude Codex claude codex sandbox 'gh pr' glab npm 'Agent tool' \
      'spawn_agent' 'wait_agent' 'Workflow('; do
      hasnt "$rule" "$rule_term" \
        "$coordinator refusal rule names a host, CLI or sandbox product: $rule_term"
    done
  done
  # A refusal is not the failure either file already handled, and both of those
  # failure clauses stay exactly as consequential as they were for a real one.
  has "$finish_step7" 'A command the environment refused reported nothing about the tree and is not a new item' \
    "$host /pln Step 7 turns a refusal into a new item the way it does a real failure"
  has "$verify_steps" 'delete only the named unpublished candidate ref' \
    "$host /pln-simplify no longer isolates a candidate that genuinely failed"
  has "$verify_steps" 'A refusal is not that failure and this step does not run on one' \
    "$host /pln-simplify deletes the candidate ref over an environment refusal"
  has "$verify_steps" 'Keep the candidate ref.' \
    "$host /pln-simplify no longer keeps the candidate ref through a refusal"
  has "$verify_steps" 'the candidate ref stays where it is, unpublished and unmerged' \
    "$host /pln-simplify does not say what becomes of a refusal that is never cleared"

  for file in "$WORK/$host/SKILL.md" "$WORK/$host/phases/pln/"*.md; do
    hasnt "$file" 'WORKER_ONLY_SENTINEL_' "$file contains worker-only contract prose"
    hasnt "$file" 'Do not inventory strengths or praise the plan' "$file embeds reviewer-only detail"
    hasnt "$file" 'Run the new test before the fix' "$file embeds implementation-worker detail"
  done
done

# Step 2 and Step 7 state their separation from opposite sides, and both
# statements sit in pln:only codex blocks — no Claude instance of that
# privilege boundary is recorded anywhere, so neither was promoted host-neutral.
# A Claude build is therefore the wrong place to look for either. Each half is
# asserted where it exists and asserted absent where it must not appear, so
# moving one side without the other fails here rather than inside a run.
codex_scope="$WORK/codex/phases/pln-pr/scope-baseline.md"
has "$codex_scope" 'never read the raw log into coordinator context or report a sandbox denial as a red baseline' \
  'Step 2 lost its sandbox-denial precedent'
has "$codex_scope" "That is Step 2's handling of a denial, and Step 2's alone" \
  'the Step 2 denial clause again reads as governing every step'
has "$codex_scope" "Step 7's final gauntlet carries its own refusal rule inline" \
  'Step 2 no longer says where Step 7 gets its refusal rule'
has "$WORK/codex/phases/pln-pr/ship-watch.md" "Step 2's caveat does not govern here" \
  'Step 7 no longer disclaims the Step 2 caveat it used to import'
hasnt "$WORK/claude/phases/pln-pr/scope-baseline.md" "Step 2's alone" \
  'the Codex-only denial clause leaked into the Claude build'
hasnt "$WORK/claude/phases/pln-pr/ship-watch.md" "Step 2's caveat does not govern here" \
  'the Codex-only Step 7 disclaimer leaked into the Claude build'

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
