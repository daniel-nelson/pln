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
    'send_input' 'close_agent' 'followup_task' 'list_agents' \
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
# PR fix rounds no longer spawn this worker: the merge that declares the
# clusters writes their node file under these rules, so they keep one owner.
hasnt "$scheduling" 'pr-fix-clusters' 'scheduling contract still offers a PR fix-cluster mode'
has "$scheduling" 'starts every independent fix cluster fresh' \
  'scheduling contract lost the independent-cluster-fresh rule the PR merge applies'

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
has "$merge_contract" 'staged-ledger candidate path' \
  'PR merge worker no longer receives a noncanonical ledger destination'
has "$merge_contract" 'never edit, delete, recreate, or rename canonical `REVIEW.md`' \
  'PR merge worker may publish the shared ledger directly'
has "$merge_contract" 'staged candidate path/digest' \
  'PR merge result no longer binds its staged ledger candidate'
hasnt "$merge_contract" 'Write `REVIEW.md` before any fix' \
  'PR merge worker still directly publishes canonical REVIEW.md'

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
has "$policy" 'A bounded plan re-review reuses the recorded tier' \
  'assurance policy re-classifies every bounded plan re-review'
has "$policy" 'it starts beside the broad reviewer' \
  'assurance policy makes every reader wait for risk classification'


assurance="$REPO_DIR/src/workers/assurance-classification.md"
has "$assurance" 'Classify meaning, not line count' 'assurance worker regressed to size-only risk'
has "$assurance" 'Unknown or conflicting risk' 'assurance worker no longer fails closed'
has "$assurance" 'SPECIALIST_AREAS=' 'assurance worker lost deterministic roster inputs'
has "$assurance" 'pln-assurance diff-stats' 'assurance worker recounts the diff the helper already totalled'

# The signal vocabulary lives in a case statement in bin/pln-assurance. A worker
# told only to "return the signals accepted by" that helper had to go find it:
# one real run grepped the whole skill, read 260 lines of the script, and then
# read two past runs' evidence files to recover the spellings — about two minutes
# of a five-minute classification, on every run. The contract and --help now
# carry the list, so all three copies are held to the binary that accepts them.
ASSURANCE_BIN="$REPO_DIR/bin/pln-assurance"
contract_signals="$(sed -n 's/^- Raises to R\([23]\): //p;s/^- Routine: //p' "$assurance" | tr -d '`' | tr ' ' '\n' | grep -v '^$')"
[ -n "$contract_signals" ] || fail 'assurance contract no longer spells out the accepted signal tokens'
for token in $contract_signals; do
  out="$("$ASSURANCE_BIN" classify --signals "$token" --substantive-files 1 --non-generated-lines 1)"
  case "$out" in
    *"REASON=unknown:$token"*) fail "assurance contract documents '$token', which bin/pln-assurance does not accept" ;;
  esac
  grep -qF -- "$token" "$WORK/assurance-help.txt" 2>/dev/null || {
    "$ASSURANCE_BIN" > "$WORK/assurance-help.txt" 2>&1 || true
    grep -qF -- "$token" "$WORK/assurance-help.txt" || fail "pln-assurance --help omits the accepted signal '$token'"
  }
done
# And nothing the helper accepts may go undocumented. Aliases of a documented
# spelling are the deliberate exception: one canonical token per concept.
aliases='auth public-contract destructive-migration unresolved-critical-conflict'
accepted="$(grep -E '^        [a-z][a-z |-]*\)$' "$ASSURANCE_BIN" | tr '|)' '\n\n' | sed 's/[^a-z-]//g' | grep -v '^$')"
[ -n "$accepted" ] || fail 'could not read the accepted signal set out of bin/pln-assurance'
for token in $accepted; do
  case " $aliases " in *" $token "*) continue ;; esac
  grep -qF -- "$token" "$assurance" || fail "bin/pln-assurance accepts '$token' but the worker contract never names it"
done
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
hasnt "$preflight" 'plan_corpus' 'pre-flight contract still reads the removed plan_corpus key'
hasnt "$preflight" 'prior decision records' 'pre-flight contract still locates records for the removed check'
has "$preflight" 'current git branch and status' 'pre-flight contract lost git-state discovery'

interview="$REPO_DIR/src/workers/interview-research.md"
has "$interview" '## Item mode' 'interview contract lost item research mode'
hasnt "$interview" 'Record-check mode' 'interview contract still carries the removed record-check mode'
hasnt "$interview" 'record-check mode' 'interview contract still names the removed record-check mode'
hasnt "$interview" 'Decision-record-query' 'the retired evidence-profile record lookup is still a mode'
hasnt "$REPO_DIR/src/workers/evidence-collection.md" 'prior-record retrieval' \
  'evidence collection still lists the retired record lookup'
hasnt "$REPO_DIR/src/shared/model-routing-policy.md" 'prior-record retrieval' \
  'routing policy still lists the retired record lookup as evidence work'
has "$interview" 'Do not read earlier `{{PLN_CMD}}` plans' \
  'item research may trawl earlier plans'
has "$interview" 'current owner, closest analogues, and material producers, callers, and consumers' \
  'item research lost the existing-system ownership map'
has "$interview" 'reuse, extension, consolidation, replacement, and directly caused retirement routes' \
  'item research no longer compares additive work with smaller system-fit routes'
has "$interview" 'localized correction inside an established owner' \
  'item research applies the heavy system-fit comparison to local corrections'
has "$interview" 'specific acceptance criterion or invariant' \
  'item research permits unsupported claims of distinctness'
# Interleavings (races, at-least-once delivery, retries) are found in the
# interview, where accepting or preventing each consequence is still cheap.
has "$interview" '`Interleavings:` is a field' \
  'item research no longer always reports interleavings'
has "$interview" 'whose delivery is at-least-once' \
  'item research no longer counts at-least-once delivery as an interleaving'
has "$interview" 'A second request to the same endpoint does not count by itself' \
  'item research reports every web item as an interleaving'
has "$interview" 'Two consequences are two entries' \
  'item research merges distinct consequences into one interleaving'
# Deliberate behavior the code documents is inventoried before any approach
# exists, because the reversal it guards against is written by the coordinator
# afterwards; the interview, not research, compares the plan against it.
has "$interview" '`Documented behavior:` is a field' \
  'item research no longer inventories documented deliberate behavior'
has "$interview" 'The list does not depend on an approach' \
  'the documented-behavior inventory is keyed to an approach research has not seen'
has "$interview" 'removes outright is not listed' \
  'item research lists code the user asked to remove'
# The owner rejected an implementation backstop and a /pln-pr stop for it.
for f in "$REPO_DIR/src/workers/item-implementation.md" "$REPO_DIR/src/workers/pr-review-merge.md" \
         "$REPO_DIR/src/phases/pln/review-approval.core.md"; do
  hasnt "$f" 'Documented behavior' "$f consumes the documented-behavior inventory outside the interview"
done
# The user's own examples stay in plans, never in rule text.
for f in "$interview" "$REPO_DIR/src/phases/pln/interview.core.md" "$REPO_DIR/src/phases/pln/review-approval.core.md"; do
  for name in BullMQ createOrFindBy createOrUpdateBy; do
    hasnt "$f" "$name" "$f names a framework-specific example in an interleaving rule: $name"
  done
done

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
has "$pr_merge" 'pln-build-review-brief --verify-pr-merge' \
  'PR merge does not mechanically verify its prepared context before parsing artifacts'
has "$pr_merge" 'immediately before and immediately after parsing' \
  'PR merge leaves an artifact replacement window around parsing'
has "$pr_merge" 'reopen cited source, rerun the reproduction, trace production reachability' \
  'prepared context displaced independent exact-source semantic verification'
has "$pr_merge" 'mandatory skill' \
  'PR merge no longer consumes skills mandated by project instructions'
has "$pr_merge" 'cannot count as successful reader coverage' \
  'PR merge can count stale or unverified artifacts as successful coverage'

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

# A defect the base branch already had is not this branch's to repair. One run
# auto-repaired a take-back prune that behaved identically on its diff base, and
# that 230-line repair produced a later finding of its own. Provenance is keyed
# to the reproduction's input and consequence, not to where the code sits, and
# the merge worker confirms it rather than taking the reader's word.
has "$pr_merge" '`on_base`' 'PR merge no longer confirms base provenance'
has "$pr_merge" 'stays `deferred` under that key' \
  'PR merge reopens a finding the fix phase deferred and filed'
has "$pr_merge" 'is settled before any route below' \
  'PR merge can refile a deferred finding as pre-existing or out-of-range'
has "$pr_merge" "Record every verified \`branch\` finding's \`branch_purpose\`" \
  'PR merge does not record which findings are the branch purpose'
has "$pr_merge" 'An absent field reads as `none`' \
  'PR merge leaves an absent branch purpose unread'
# 1.97.0: a failure the user accepted in the plan is disclosed, not repaired.
# Only the user's own recorded decision counts, quoted verbatim from a plan the
# handing-off /pln run wrote, naming the same consequence on the same surface.
has "$pr_merge" 'Confirm a failure the user accepted against `PLAN.md`' \
  'PR merge repairs a failure the user accepted in the plan'
has "$pr_merge" 'decision entry beginning `**Decision (user`' \
  'PR merge honours an acceptance that is not the user'"'"'s recorded decision'
has "$pr_merge" 'the marker through the next blank line' \
  'PR merge misses an accepted decision that wraps'
has "$pr_merge" 'on the same surface' \
  'PR merge lets an accepted failure class cover every surface'
has "$pr_merge" 'Acceptance is per consequence' \
  'PR merge lets one accepted consequence cover another'
has "$pr_merge" '`git ls-files --error-unmatch' \
  'PR merge honours a plan that arrived with the branch'
has "$pr_merge" '`plan authored by the handing-off run`' \
  'PR merge honours a plan found only by the newest-plan heuristic'
has "$pr_merge" '`no basis recorded`' \
  'PR merge leaves the likelihood basis of an acceptance unrecorded'
has "$pr_merge" 'before the `on_base` and scoped-range routes' \
  'PR merge can file an accepted failure as pre-existing or out-of-range'
has "$pr_merge" "the envelope's \`accepted\` field" \
  'PR merge envelope does not name accepted findings'
has "$pr_merge" "builds the reproduction's own input" \
  'PR merge can call a finding pre-existing on a base failure reached by a different input'
has "$pr_merge" 'in scope even though the base fails the same way' \
  'PR merge lets a fix branch exclude the defect it set out to fix'
has "$pr_merge" 'gets no repair key' 'PR merge can queue a pre-existing defect for repair'
has "$pr_merge" "the envelope's \`pre_existing\` field" \
  'PR merge envelope no longer names pre-existing findings for filing'
# The post-fix merge runs on this same contract, and the settled candidate
# advances only from the commit its envelope says the counted reader read.
# 1.98.0: a constraint the owner stated ("don't add protections for problems
# we haven't seen", "stop before expanding scope") never reached repair design.
# The merge worker quotes, per repair, the recorded entry it contravenes; the
# fix worker builds only an unquoted repair or defers naming the quote.
has "$pr_merge" "Record every verified actionable finding's \`owner_constraint_fix\` and \`owner_constraint_smaller_fix\`" \
  'PR merge does not say which repair an owner constraint rules out'
has "$pr_merge" 'an entry that a later entry lifts is never quoted' \
  'PR merge can apply a constraint the owner has since lifted'
has "$pr_merge" 'either field may instead quote a `PLAN.md` entry beginning `**Decision (user`' \
  'PR merge cannot apply a constraint the owner stated during /pln'
has "$pr_merge" 'a candidate that changes it is malformed' \
  'PR merge can rewrite the owner constraints it quotes from'
has "$pr_merge" '`Constraints judged: <n>`' \
  'PR merge does not record how many owner constraints it judged against'
has "$pr_merge" 'When the assignment names a constraint re-judge' \
  'a constraint stated mid-run never reaches findings already merged'
has "$pr_merge" 'the owner'"'"'s recorded constraint ruled out every available repair' \
  'PR merge deferred paragraph still treats consequential repairs as automatic deferrals'
has "$pr_merge" '`reader_commit` when the assignment asks for it' \
  'PR merge envelope cannot return the commit a post-fix reader read'
# Every multi-cluster repair round spawned a scheduling worker (5-7 min each,
# ~25 min in one run) whose output was always a linear order. The merge that
# declares the clusters writes the node file instead, under the schedule
# contract's rules by reference, and a cluster's lease covers both repairs the
# fix worker may choose between.
has "$pr_merge" 'apply its node schema and its edge, lease and `UNKNOWN`, cohort, dirty-state and independent-cluster-fresh rules' \
  'PR merge writes fix nodes without the schedule contract rules'
has "$pr_merge" 'the files of both its `fix` and its `smaller_fix`' \
  'PR merge leases a cluster for only one of the repairs its worker may build'
has "$pr_merge" 'row N is the Nth acted-on cluster' \
  'PR merge node rows cannot be mapped back to clusters'
# A post-fix finding outside the scoped range that no in-range repair made
# reachable is filed, never repaired, on the same path as a pre-existing one.
has "$pr_merge" 'with status `out-of-range`' 'PR merge can repair a finding outside the scoped range'
has "$pr_merge" "the envelope's \`out_of_range\` field" \
  'PR merge envelope does not name out-of-range findings for filing'

# Even a reachable finding can carry a cathedral. The same run's proposed repair
# for two dead fields on a persisted type was to validate every envelope against
# its durable journal payload, and the question that reached the user offered
# that design as its only option. 1.76.0 made a /pln interview name the simpler
# route it passed over; this is the review's copy of that field.
has "$pr_merge" 'Persist each finding'"'"'s `smaller_fix` verbatim' \
  'PR merge drops the smaller repair a reader passed over'

# A reviewer can always name another defensible improvement, so a run that
# repairs every real finding has no fixed point to reach. The consequence check
# is what separates a defect the shipped system has from a design someone would
# have chosen differently, and like reachability it is checked at the merge and
# not taken from the reader. Observed: three findings relocating TSDoc between a
# private field, an internal helper and a public getter each merged `critical`
# and opened a repair cluster, two of them carrying behavior-preservation proof.
has "$pr_merge" 'breaks_if_shipped' \
  'PR merge no longer checks what a finding costs if it ships'
has "$pr_merge" 'a preference is **dropped**' \
  'PR merge keeps a finding nobody will act on instead of dropping it'
has "$pr_merge" 'There is no third destination' \
  'PR merge regained a place to defer the call to'
has "$pr_merge" 'A note nobody will read is not a lighter version of acting' \
  'PR merge can resolve a doubtful finding by writing it down for no reader'

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
  # No fix worker was ever told about `smaller_fix`, and one full fix added a
  # persisted escalation transition and a handoff that spawned four later
  # findings. The worker builds the smaller repair and stops on new behavior.
  has "$WORK/$host/phases/pln-pr/fix.md" 'each with its `fix` and `smaller_fix` copied verbatim' \
    "$host fix-worker brief no longer carries the smaller repair"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Build `smaller_fix` unless it is `none found`' \
    "$host fix worker no longer builds the smaller repair by default"
  has "$WORK/$host/phases/pln-pr/fix.md" 'breaks a contract, consumer or invariant the reason names' \
    "$host fix worker honours any rejection reason, so it never builds the smaller repair"
  has "$WORK/$host/phases/pln-pr/fix.md" 'a persisted-state write or state transition, a call with an external effect' \
    "$host fix worker can build new stateful or consequential behavior without asking"
  # Consequential production repairs ask once, remind once, then continue on
  # the recorded selected repair if no answer arrived. Owner constraints bind.
  has "$WORK/$host/phases/pln-pr/fix.md" 'Do this regardless of `branch_purpose` or CI status' \
    "$host still defers an ordinary reachable consequential repair"
  has "$WORK/$host/phases/pln-pr/fix.md" 'before editing or writing its spec' \
    "$host worker can edit before the consequential-repair question"
  has "$WORK/$host/phases/pln-pr/fix.md" 'coordinator'"'"'s recorded user answer or timeout authorization' \
    "$host worker repeats the same blocker after a timed answer"
  has "$WORK/$host/phases/pln-pr/fix.md" 'For needs-a-decision findings, select and record the repair' \
    "$host design decisions still wait indefinitely without a selected fallback"
  has "$WORK/$host/phases/pln-pr/blocker.md" 'pln-decision-window --asked-at' \
    "$host blocker phase lost the durable two-notice timer"
  has "$WORK/$host/phases/pln-pr/blocker.md" 're-check for a reply' \
    "$host timer can override an answer that arrived at its deadline"
  has "$WORK/$host/phases/pln-pr/blocker.md" 'fire enabled notifications again' \
    "$host reminder is silent"
  has "$WORK/$host/phases/pln-pr/blocker.md" 'a reminder that was never sent must be sent' \
    "$host interrupted window can proceed without the second notice"
  has "$WORK/$host/phases/pln-pr/blocker.md" 'A timeout never lifts an owner constraint' \
    "$host timer can override an explicit owner constraint"
  has "$WORK/$host/phases/pln-pr/fix.md" 'A `reached_by: test-only` finding whose only available repair' \
    "$host a test-only finding can spend a user decision through the new-behavior stop"
  has "$WORK/$host/phases/pln-pr/fix.md" 'If no repair is left to build because of the owner'"'"'s recorded constraints' \
    "$host worker can override an explicit owner constraint"
  has "$WORK/$host/phases/pln-pr/fix.md" 'When `smaller_fix` would add one and `fix` would not, build `fix`' \
    "$host fix worker asks unnecessarily when an available repair adds none of the three"
  has "$WORK/$host/phases/pln-pr/fix.md" 'and its `branch_purpose` (absent reads `none`)' \
    "$host fix brief does not carry the branch-purpose quote"
  has "$WORK/$host/phases/pln-pr/fix.md" 'At the checkpoint publish `deferred`' \
    "$host coordinator does not record a deferred finding a later merge can match"
  has "$WORK/$host/phases/pln-pr/fix.md" 'pln-todo add --status proposed' \
    "$host coordinator does not file a deferred finding"
  has "$WORK/$host/phases/pln-pr/fix.md" 'pln-scheduler checkpoint --commit none' \
    "$host a cluster whose every finding deferred has no checkpoint"
  has "$WORK/$host/phases/pln-pr/fix.md" 'it runs no post-fix reader and leaves `Settled candidate` unchanged' \
    "$host a round that changed nothing still spends a post-fix reader"
  has "$WORK/$host/phases/pln-pr/fix.md" '`fixed`, `skipped`, `deferred`, `accepted`, `pre-existing` or `out-of-range`' \
    "$host fix-phase finish gate does not treat a deferred or accepted finding as closed"
  has "$WORK/$host/phases/pln-pr/fix.md" 'a `deferred` one is not repaired on this branch' \
    "$host standing repair authority still covers a deferred finding"
  has "$WORK/$host/phases/pln-pr/fix.md" 'except for a finding you are leaving unbuilt, which gets no spec' \
    "$host a deferred finding can leave a red spec behind"
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'a consequential repair takes the same two-notice window' \
    "$host a CI fix cluster lost the timed consequential-repair question"
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'Every `deferred` finding goes under a heading of its own' \
    "$host PR body does not name deferred repairs"
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'the message'"'"'s one closing line is `HEADS-UP:` naming them' \
    "$host closing message does not name deferred repairs"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" '`skipped`, `deferred` and `accepted` stay as they are' \
    "$host resume reopens a deferred or accepted finding"
  has "$WORK/$host/phases/pln-pr/review.md" 'open/fixed/skipped/deferred/accepted/pre-existing/out-of-range status' \
    "$host ledger status vocabulary lacks deferred or accepted"
  has "$WORK/$host/phases/pln-pr/fix.md" 'an `accepted` one is the user'"'"'s decision' \
    "$host standing repair authority still covers a failure the user accepted"
  for phase in review fix; do
    has "$WORK/$host/phases/pln-pr/$phase.md" 'occurs byte-for-byte in that `PLAN.md`' \
      "$host $phase coordinator publishes an accepted finding without checking its quote"
  done
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'Every `accepted` finding goes under a heading of its own' \
    "$host PR body does not disclose failures the plan accepted"
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'any `deferred` or `accepted` finding' \
    "$host closing message does not name accepted failures"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" '`plan authored by the handing-off run`' \
    "$host ledger does not record whether the plan came from the handing-off run"
  # 1.98.0: owner constraints are recorded at scope-baseline, appended mid-run,
  # byte-checked at every merge publish, and steer each fix brief.
  has "$WORK/$host/pln-pr/SKILL.md" 'review depth, owner constraints,' \
    "$host /pln-pr router State summary omits owner constraints"
  has "$WORK/$host/pln-pr/SKILL.md" 'is appended verbatim to `Owner constraints` in a candidate of its own' \
    "$host a constraint the owner states mid-run is not recorded"
  has "$WORK/$host/pln-pr/SKILL.md" 'before the next review brief is assembled' \
    "$host a mid-run constraint can land after the next brief digests the ledger"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'Review depth, Owner constraints,' \
    "$host initial ledger State has no owner-constraints field"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'or the literal `none stated`' \
    "$host scope-baseline leaves an empty owner-constraints field ambiguous"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'are never a source' \
    "$host tool or worker text can be recorded as an owner constraint"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" "sed -n '<line>p' <path>" \
    "$host a constraint quoted from a named file is recorded unchecked"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'this is not a question and adds no stop' \
    "$host recording owner constraints adds a stop before the PR"
  has "$WORK/$host/phases/pln-pr/review.md" 'byte-identical to the canonical field the merge was dispatched on' \
    "$host review coordinator publishes a merge that rewrote owner constraints"
  has "$WORK/$host/phases/pln-pr/review.md" '`owner_constraint_fix`, `owner_constraint_smaller_fix`' \
    "$host ledger findings do not carry the owner-constraint fields"
  has "$WORK/$host/phases/pln-pr/fix.md" '`owner_constraint_fix` and `owner_constraint_smaller_fix` — the owner'"'"'s constraint' \
    "$host fix brief does not carry the owner-constraint quotes"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Never build a repair whose field is a quote' \
    "$host fix worker can build a repair the owner ruled out"
  has "$WORK/$host/phases/pln-pr/fix.md" 'name it as deferred with the quoted constraint' \
    "$host a constraint deferral does not name its quote"
  has "$WORK/$host/phases/pln-pr/fix.md" 'record the quoted constraint and keep its repair key' \
    "$host a filed constraint deferral does not name its quote"
  has "$WORK/$host/phases/pln-pr/fix.md" 'an assignment naming it a constraint re-judge' \
    "$host a mid-run constraint never re-judges open findings"
  has "$WORK/$host/phases/pln-pr/fix.md" 'than the ledger header'"'"'s `Constraints judged`' \
    "$host fix phase cannot tell that a constraint arrived after the last merge"
  has "$WORK/$host/phases/pln-pr/fix.md" 'byte-identical to the canonical field the merge was dispatched on' \
    "$host post-fix coordinator publishes a merge that rewrote owner constraints"
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'naming the owner constraint that ruled out every repair, quoted' \
    "$host PR body does not name a constraint deferral's quote"
  has "$WORK/$host/phases/pln-pr/fix.md" 'record its checkpoint with `--commit none`' \
    "$host fix invocation commits a cluster that changed nothing"
  has "$WORK/$host/phases/pln-pr/review.md" 'on_base: string' \
    "$host review phase no longer asks whether the base already fails"
  has "$WORK/$host/phases/pln-pr/review.md" 'with the same input your reproduction uses' \
    "$host reviewer brief keys base provenance to code location instead of the reproduction"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Give each finding an `on_base`' \
    "$host post-fix red team no longer states base provenance"
  for phase in review fix; do
    has "$WORK/$host/phases/pln-pr/$phase.md" "merge envelope's \`pre_existing\` and" \
      "$host $phase phase no longer files the pre-existing findings its merge named"
  done
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'Every `pre-existing` finding' \
    "$host PR body and closing message can omit filed pre-existing defects"
  has "$WORK/$host/phases/pln-pr/review.md" 'smaller_fix: string' \
    "$host review phase no longer asks for the smaller repair passed over"
  has "$WORK/$host/phases/pln-pr/review.md" 'the literal `none found`' \
    "$host reviewer brief lost the no-smaller-repair answer"
  has "$WORK/$host/phases/pln-pr/fix.md" 'carries the finding'"'"'s `smaller_fix` beside its proposed fix' \
    "$host decision question can present one design as the only option"
  has "$WORK/$host/phases/pln-pr/review.md" 'breaks_if_shipped: string' \
    "$host review phase no longer requires a shipped consequence on every finding"
  has "$WORK/$host/phases/pln-pr/review.md" 'Write the literal `nothing`' \
    "$host reviewer brief lost the no-consequence answer"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Nothing reaches this phase that is not work' \
    "$host fix phase can still build a finding with no shipped consequence"
  has "$WORK/$host/phases/pln-pr/fix.md" 'a cheap repair is not a reason to build something' \
    "$host fix phase can readmit a dropped finding because the repair looks small"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Settled candidate' \
    "$host fix phase lost the scope that keeps later rounds on the repairs"
  has "$WORK/$host/phases/pln-pr/fix.md" 'This is a scope rule, not a round cap' \
    "$host settled-candidate rule no longer distinguishes itself from the removed round cap"
  hasnt "$WORK/$host/phases/pln-pr/ship-watch.md" 'the branch ships without them' \
    "$host closing message regained a tally of work nobody is doing"
  # 1.92.0 settled only after a clean post-fix round, which one run never
  # reached in four rounds while its cumulative repair diff grew from +859 to
  # +1427 lines. The anchor now moves to the commit the last successful
  # post-fix reader read, and a failed reader leaves it where it was.
  hasnt "$WORK/$host/phases/pln-pr/fix.md" 'post-fix assurance on that candidate clean' \
    "$host settled candidate still waits for a clean round that may never come"
  hasnt "$WORK/$host/phases/pln-pr/fix.md" 'which shrinks as the repairs land' \
    "$host fix phase still claims a cumulative repair diff shrinks"
  has "$WORK/$host/phases/pln-pr/fix.md" 'git diff <Settled candidate> <candidate commit>' \
    "$host later post-fix readers are not briefed with the exact repair range"
  has "$WORK/$host/phases/pln-pr/fix.md" 'diff-fingerprint --root <repository-root> --base <Settled candidate>' \
    "$host scoped repair diff has no mechanical identity"
  has "$WORK/$host/phases/pln-pr/fix.md" 'from the post-fix merge result, never at dispatch' \
    "$host settled candidate can advance on a reader nobody counted"
  has "$WORK/$host/phases/pln-pr/fix.md" 'A failed or uncounted reader leaves `Settled candidate` where it was' \
    "$host a failed post-fix reader can advance the anchor past bytes nobody read"
  has "$WORK/$host/phases/pln-pr/fix.md" 'base code or an earlier round'"'"'s repair code' \
    "$host made-reachable exception narrowed to base code"
  # 1.92.0 recorded a fingerprint here; a digest no git command resolves would
  # make the narrowed brief a range nobody can read.
  has "$WORK/$host/phases/pln-pr/fix.md" 'that does not resolve with `git rev-parse --verify' \
    "$host an older release's fingerprint in Settled candidate becomes an unreadable range"
  # Up to 1.95.0 the post-fix merge named no contract, so a worker borrowed
  # pr-review-merge.md, hunted for the prepared brief it requires, and one round
  # messaged the coordinator for it. It now gets that contract and that brief.
  has "$WORK/$host/phases/pln-pr/fix.md" '--artifact post-fix-red-team' \
    "$host post-fix merge brief does not inventory the red team's artifact"
  has "$WORK/$host/phases/pln-pr/fix.md" '--reader-metadata "<plan-dir>/evidence/post-fix-readers.tsv"' \
    "$host post-fix merge brief has no reader metadata"
  has "$WORK/$host/phases/pln-pr/fix.md" '--diff-map "<plan-dir>/evidence/post-fix-diff-files.txt"' \
    "$host post-fix merge brief has no repair-range diff map"
  has "$WORK/$host/phases/pln-pr/fix.md" 'src/workers/pr-review-merge.md` on that brief' \
    "$host post-fix merge still names no contract"
  has "$WORK/$host/phases/pln-pr/fix.md" 'Its assignment also carries' \
    "$host post-fix-only duties do not reach the merge worker"
  # No per-round scheduling worker; the coordinator edits the merge's node
  # file mechanically when the dispatched set moves.
  hasnt "$WORK/$host/phases/pln-pr/fix.md" 'pr-fix-clusters' \
    "$host fix phase still spawns a scheduling worker per round"
  hasnt "$WORK/$host/phases/pln-pr/fix.md" 'With two or more clusters' \
    "$host fix phase still branches to a scheduling worker"
  has "$WORK/$host/phases/pln-pr/fix.md" 'appending serially is always a valid order' \
    "$host fix phase has no rule for clusters the merge did not declare"
  has "$WORK/$host/phases/pln-pr/fix.md" 'remove the rows of clusters not being dispatched' \
    "$host fix phase builds a manifest with rows for skipped clusters"
  has "$WORK/$host/phases/pln-pr/fix.md" '<plan-dir>/fix-nodes.tsv' \
    "$host post-fix merge is not assigned the node output path"
  has "$WORK/$host/phases/pln-pr/fix.md" '<plan-dir>/fix-dirty-start.tsv' \
    "$host fix nodes are not tied to a dirty snapshot taken before the merge"
  has "$WORK/$host/phases/pln-pr/review.md" '<plan-dir>/fix-nodes.tsv' \
    "$host first merge is not assigned the node output path"
  has "$WORK/$host/phases/pln-pr/review.md" '<plan-dir>/fix-dirty-start.tsv' \
    "$host first merge has no dirty snapshot"
  for phase in review fix; do
    has "$WORK/$host/phases/pln-pr/$phase.md" "\`out_of_range\` fields once with" \
      "$host $phase phase does not file out-of-range findings"
  done
  has "$WORK/$host/phases/pln-pr/ship-watch.md" 'every `out-of-range` finding, marked as outside' \
    "$host PR body drops findings filed as outside the scoped range"
  # Execution is linear since 1.60.0; the wave and worktree text stayed behind.
  for phase in fix blocker ship-watch; do
    for stale in 'isolated wave' 'isolated sibling' 'isolated disjoint' 'per cluster with `isolation' \
      'assigned worktree' 'concurrent writes would race' 'every cluster in the wave' \
      'can run concurrently when leases are disjoint'; do
      hasnt "$WORK/$host/phases/pln-pr/$phase.md" "$stale" \
        "$host $phase phase still describes parallel fix waves: $stale"
    done
  done
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'Settled candidate' \
    "$host ledger no longer carries the settled candidate across a compaction"
  has "$WORK/$host/SKILL.md" 'at most two exact operations' "$host /pln router lost the direct lookup budget"
  has "$WORK/$host/SKILL.md" 'routing.tsv' "$host /pln router lost the local routing ledger"
  has "$WORK/$host/pln-pr/SKILL.md" 'at most two exact operations' "$host /pln-pr router lost the direct lookup budget"
  has "$WORK/$host/pln-pr/SKILL.md" 'routing.tsv' "$host /pln-pr router lost the local routing ledger"
  has "$WORK/$host/phases/pln/outline.md" 'Preflight is judgment work' "$host preflight no longer stays frontier"
  hasnt "$WORK/$host/phases/pln/interview.md" 'Before asking, check the record' \
    "$host interview still carries the removed check against earlier plans"
  hasnt "$WORK/$host/phases/pln/interview.md" 'record-check mode' \
    "$host interview still dispatches the removed record-check worker"
  has "$WORK/$host/phases/pln/interview.md" 'strongest existing-owner route' \
    "$host interview no longer gates new durable concepts on system fit"
  has "$WORK/$host/phases/pln/interview.md" 'do not admit the new concept' \
    "$host interview does not block unsupported additive ownership"
  has "$WORK/$host/phases/pln/interview.md" 'even when plan review is disabled' \
    "$host system-fit gate incorrectly depends on plan review"
  has "$WORK/$host/phases/pln/interview.md" 'no direct retirement found' \
    "$host interview no longer records the directly caused retirement outcome"
  has "$WORK/$host/phases/pln/interview.md" 'Interleavings are settled one consequence at a time' \
    "$host interview does not consume the research envelope's interleavings"
  has "$WORK/$host/phases/pln/interview.md" 'a stated exception to the durable-surface rule above' \
    "$host a taken prevention is not reconciled with the durable-surface ask rule"
  has "$WORK/$host/phases/pln/interview.md" 'with accepting it as the floor option' \
    "$host an interleaving question has no accept floor"
  has "$WORK/$host/phases/pln/interview.md" "The accept option's own line names the consequence, the surface and the likelihood basis" \
    "$host an accepted interleaving is recorded without what /pln-pr needs to honour it"
  has "$WORK/$host/phases/pln/interview.md" 'Documented behavior is not changed as a side effect' \
    "$host interview does not consume the research envelope's documented behavior"
  has "$WORK/$host/phases/pln/interview.md" 'with keeping the current behavior as one option, one reversal per question' \
    "$host a side-effect reversal is not its own question with a keep option"
  has "$WORK/$host/phases/pln/interview.md" "on every later rewrite of the item's section" \
    "$host a reversal written into the section after step 6 is never compared"
  has "$WORK/$host/phases/pln/interview.md" 'agent-written item text, a `Decision (agent)` or a disclosed decision never exempts it' \
    "$host agent-written plan text exempts a reversal of documented behavior"
  has "$WORK/$host/phases/pln/interview.md" 'is settled by that interleaving question and not asked again here' \
    "$host one documented design can be asked about twice"
  has "$WORK/$host/phases/pln/interview.md" 'gets its Reversals line and no gate disclosure' \
    "$host an asked reversal is repeated at the gate"
  has "$WORK/$host/phases/pln/interview.md" "An answer that changes an item's approach dispatches a fresh item-mode worker" \
    "$host interview keeps research written for an approach an answer replaced"
  has "$WORK/$host/phases/pln/review-approval.md" "record a \`Decision (user, selected)\` pair whose option line is that entry's line" \
    "$host a gate override of a taken prevention has no recorded form"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'Possibly unbounded metadata' "$host PR scope phase lost file-first metadata collection"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'PR disposition: ready' \
    "$host plain PR request no longer records ready disposition"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'PLN_GAUNTLET_V1' \
    "$host scope phase lost declared gauntlet graph format"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'Legacy plain command lists remain serial' \
    "$host scope phase infers parallelism for legacy commands"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'known coordinator-only command is assigned `coordinator` and run there on its first attempt' \
    "$host scope phase still burns a worker attempt on known coordinator-only work"
  has "$WORK/$host/phases/pln-pr/scope-baseline.md" 'assigned executor and its required terminal/network/filesystem/browser' \
    "$host environment identity lost executor requirements"
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
  has "$step7" 'bin/pln-gauntlet' "$host Step 7 does not use the declared gauntlet runner"
  has "$step7" '--status <plan-root>/evidence/final-gauntlet.coordinator.status --executor coordinator' \
    "$host Step 7 does not run the coordinator subset explicitly first"
  has "$step7" '--executor worker --completed <plan-root>/evidence/final-gauntlet.coordinator.status' \
    "$host Step 7 worker can omit the coordinator-status handoff"
  has "$step7" 'refuses the default `--executor all`' \
    "$host Step 7 allows the default executor to collapse coordinator/worker ownership"
  has "$step7" 'src/workers/context-envelope.md' \
    "$host Step 7 worker does not read the shared envelope format"
  has "$step7" 'bin/pln-read-envelope --root <plan-root> --max-bytes 2048' \
    "$host Step 7 worker does not self-validate its envelope"
  has "$step7" 'coordinator runs the same `pln-read-envelope` command itself and remains authoritative' \
    "$host Step 7 worker self-validation displaced coordinator authority"
  has "$step7" 'A pure version bump never triggers the functional gauntlet' \
    "$host Step 7 reruns functional verification for a version-only correction"
  has "$step7" 'mixed version-and-code delta' \
    "$host Step 7 reuses functional evidence across mixed changes"
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
  has "$ship_watch" 'A plain put-up/open/create request, including `review=none` or “skip review,” is `ready`' \
    "$host exact late-skip trace still becomes an implicit draft"
  has "$ship_watch" 'adding `--draft` only for `keep-draft` or `policy-draft`' \
    "$host ready PR path can still receive --draft"
  has "$ship_watch" 'A new ready PR offers optional CI watching but never starts it unprompted' \
    "$host ready PR path still enters mandatory CI watch"
  has "$ship_watch" 'an update to an already-open PR never touches its draft/ready state' \
    "$host existing PR disposition can be rewritten"
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

# The original plan-review mode is a compatibility surface: adding the PR-merge
# inventory may not change one byte of an existing caller's output.
{
  printf 'Repository root: /example/root\nPlan file: %s\nRepository commit: deadbeef\n\n' "$brief_dir/PLAN.md"
  cat "$review"
  printf '\n\n--- PLAN ---\n'
  cat "$brief_dir/PLAN.md"
  printf '\n--- END PLAN ---\n'
} > "$brief_dir/expected-review.md"
cmp -s "$brief_dir/expected-review.md" "$brief_dir/review.md" \
  || fail 'plan-review mode is not byte-compatible'

# PR-merge mode carries a contract first and only typed, escaped, source-bound
# metadata after it. Large optional inputs stay path/size/digest metadata, so
# their bytes cannot turn into instructions or overflow the bounded brief.
merge_repo="$WORK/pr-merge-repo"
mkdir -p "$merge_repo/nested/deeper" "$merge_repo/evidence" "$merge_repo/skills/nested-only"
git -C "$merge_repo" init -q
printf 'root instructions\n' > "$merge_repo/AGENTS.md"
printf 'use mandatory skill nested-only\n' > "$merge_repo/nested/AGENTS.md"
ln -s ../AGENTS.md "$merge_repo/nested/deeper/AGENTS.md"
printf 'ignored/\n' > "$merge_repo/.gitignore"
mkdir -p "$merge_repo/ignored/deep"
printf 'ignored nested instructions\n' > "$merge_repo/ignored/deep/AGENTS.md"
printf 'must stay outside the manifest\n' > "$merge_repo/.git/AGENTS.md"
printf '%s\n' '---' 'name: nested-only' 'description: fixture' '---' '# Fixture' \
  > "$merge_repo/skills/nested-only/SKILL.md"
mkdir -p "$WORK/external-skill"
printf '%s\n' '---' 'name: linked-skill' 'description: fixture' '---' '# Linked fixture' \
  > "$WORK/external-skill/SKILL.md"
ln -s "$WORK/external-skill" "$merge_repo/skills/linked-skill"
printf 'commands\n' > "$merge_repo/commands.txt"
printf 'environment\n' > "$merge_repo/environment.txt"
printf 'ledger\n' > "$merge_repo/REVIEW.md"
printf 'diff map\n' > "$merge_repo/diff-files.txt"
printf 'broad\tsuccess\n' > "$merge_repo/readers.tsv"
printf 'contract-first sentinel\n' > "$merge_repo/merge-contract.md"
weird_artifact="$merge_repo/evidence/reader"$'\n''## forged-heading.json'
printf '{"findings":[]}\n' > "$weird_artifact"
{
  printf 'NEVER_INLINE_THIS_LARGE_PLAN\n'
  dd if=/dev/zero bs=1024 count=200 2>/dev/null | tr '\0' x
} > "$merge_repo/PLAN.md"

candidate="$("$REPO_DIR/bin/pln-assurance" fingerprint \
  --root "$merge_repo" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" \
  | awk -F= '$1 == "CANDIDATE_SHA256" { print $2 }')"
merge_brief="$WORK/pr-merge.brief"
"$REPO_DIR/bin/pln-build-review-brief" --mode pr-merge \
  --contract "$merge_repo/merge-contract.md" --root "$merge_repo" \
  --candidate "$candidate" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" --plan "$merge_repo/PLAN.md" \
  --ledger "$merge_repo/REVIEW.md" --diff-map "$merge_repo/diff-files.txt" \
  --reader-metadata "$merge_repo/readers.tsv" \
  --artifact $'broad\nINSTRUCTION\tforged' "$weird_artifact" \
  --skill-root "$merge_repo/skills" --out "$merge_brief"

[ "$(head -n 1 "$merge_brief")" = 'contract-first sentinel' ] \
  || fail 'PR-merge contract is not first'
has "$merge_brief" 'PLN_PR_MERGE_CONTEXT_V1' 'PR-merge brief lost its typed schema marker'
has "$merge_brief" 'CONTENT_POLICY' 'PR-merge brief lost its path-only content policy'
has "$merge_brief" $'TREE_SHA256\t' 'PR-merge brief lost its tree fingerprint'
has "$merge_brief" $'COMMAND_SHA256\t' 'PR-merge brief lost its command fingerprint'
has "$merge_brief" $'ENVIRONMENT_SHA256\t' 'PR-merge brief lost its environment fingerprint'
hasnt "$merge_brief" 'NEVER_INLINE_THIS_LARGE_PLAN' 'large optional plan content was copied inline'
hasnt "$merge_brief" '## forged-heading.json' 'artifact path escaped the typed schema'
hasnt "$merge_brief" $'INSTRUCTION\tforged' 'artifact role escaped the typed schema'
[ "$(wc -c < "$merge_brief" | tr -d ' ')" -le 65536 ] || fail 'PR-merge brief exceeded its byte cap'
nested_instruction_hex="$(printf 'nested/AGENTS.md' | od -An -v -tx1 | tr -d ' \n')"
ignored_instruction_hex="$(printf 'ignored/deep/AGENTS.md' | od -An -v -tx1 | tr -d ' \n')"
git_internal_instruction_hex="$(printf '.git/AGENTS.md' | od -An -v -tx1 | tr -d ' \n')"
nested_skill_hex="$(printf 'nested-only/SKILL.md' | od -An -v -tx1 | tr -d ' \n')"
linked_skill_path="$(cd "$WORK/external-skill" && pwd -P)/SKILL.md"
linked_skill_hex="$(printf '%s' "$linked_skill_path" | od -An -v -tx1 | tr -d ' \n')"
has "$merge_brief" "$nested_instruction_hex" 'nested AGENTS.md was omitted from the instruction manifest'
has "$merge_brief" "$ignored_instruction_hex" 'gitignored nested AGENTS.md was omitted from the instruction manifest'
hasnt "$merge_brief" "$git_internal_instruction_hex" 'repository-internal AGENTS.md entered the instruction manifest'
has "$merge_brief" "$nested_skill_hex" 'skill mandated only by nested instructions was omitted'
has "$merge_brief" "$linked_skill_hex" 'symlink-installed skill was omitted from the skill manifest'
"$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  | grep -q '^STATUS=verified$' || fail 'fresh PR-merge context did not verify'

outside="$WORK/outside-reader.json"
printf '{"findings":[]}\n' > "$outside"
if "$REPO_DIR/bin/pln-build-review-brief" --mode pr-merge \
  --contract "$merge_repo/merge-contract.md" --root "$merge_repo" \
  --candidate "$candidate" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" --ledger "$merge_repo/REVIEW.md" \
  --diff-map "$merge_repo/diff-files.txt" --reader-metadata "$merge_repo/readers.tsv" \
  --artifact escape "$outside" \
  --skill-root "$merge_repo/skills" \
  --out "$WORK/escape.brief" >"$WORK/build-escape.out" 2>"$WORK/build-escape.err"; then
  fail 'out-of-root artifact entered a PR-merge brief'
fi
has "$WORK/build-escape.err" 'escapes root' 'out-of-root artifact failure was not attributed'

dd if=/dev/zero bs=1024 count=66 2>/dev/null | tr '\0' c > "$merge_repo/huge-contract.md"
large_candidate="$("$REPO_DIR/bin/pln-assurance" fingerprint \
  --root "$merge_repo" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" \
  | awk -F= '$1 == "CANDIDATE_SHA256" { print $2 }')"
if "$REPO_DIR/bin/pln-build-review-brief" --mode pr-merge \
  --contract "$merge_repo/huge-contract.md" --root "$merge_repo" \
  --candidate "$large_candidate" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" --ledger "$merge_repo/REVIEW.md" \
  --diff-map "$merge_repo/diff-files.txt" --reader-metadata "$merge_repo/readers.tsv" \
  --artifact broad "$weird_artifact" --skill-root "$merge_repo/skills" \
  --out "$WORK/oversize.brief" >"$WORK/build-oversize.out" 2>"$WORK/build-oversize.err"; then
  fail 'oversized PR-merge brief was published'
fi
has "$WORK/build-oversize.err" 'cap is 65536' 'PR-merge byte-cap failure was not attributed'
rm "$merge_repo/huge-contract.md"

cp "$weird_artifact" "$WORK/reader.backup"
printf '{"findings":[ ]}\n' > "$weird_artifact"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-size.out" 2>"$WORK/verify-size.err"; then
  fail 'artifact size replacement verified'
fi
has "$WORK/verify-size.err" 'ARTIFACT size mismatch' 'artifact size mismatch was not attributed'
cp "$WORK/reader.backup" "$weird_artifact"
printf '{"findingz":[]}\n' > "$weird_artifact"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-digest.out" 2>"$WORK/verify-digest.err"; then
  fail 'same-size artifact replacement verified'
fi
has "$WORK/verify-digest.err" 'ARTIFACT digest mismatch' 'artifact digest mismatch was not attributed'
cp "$WORK/reader.backup" "$weird_artifact"

rm "$weird_artifact"
ln -s "$outside" "$weird_artifact"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-link.out" 2>"$WORK/verify-link.err"; then
  fail 'symlink artifact replacement verified'
fi
has "$WORK/verify-link.err" 'symlink file is not allowed' 'symlink replacement was not rejected'
rm "$weird_artifact"
cp "$WORK/reader.backup" "$weird_artifact"

mkdir -p "$merge_repo/ignored/deep/later"
printf 'late ignored instructions\n' > "$merge_repo/ignored/deep/later/CLAUDE.md"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-manifest.out" 2>"$WORK/verify-manifest.err"; then
  fail 'incomplete instruction manifest verified'
fi
has "$WORK/verify-manifest.err" 'instruction manifest is stale or incomplete' \
  'instruction-manifest drift was not attributed'
rm "$merge_repo/ignored/deep/later/CLAUDE.md"
rmdir "$merge_repo/ignored/deep/later"

mkdir -p "$merge_repo/skills/late-skill"
printf '%s\n' '---' 'name: late-skill' 'description: fixture' '---' \
  > "$merge_repo/skills/late-skill/SKILL.md"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-skills.out" 2>"$WORK/verify-skills.err"; then
  fail 'incomplete skill manifest verified'
fi
has "$WORK/verify-skills.err" 'skill manifest is stale or incomplete' \
  'skill-manifest drift was not attributed'
rm "$merge_repo/skills/late-skill/SKILL.md"
rmdir "$merge_repo/skills/late-skill"

printf 'candidate drift\n' > "$merge_repo/ordinary-source.txt"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$merge_brief" \
  >"$WORK/verify-candidate.out" 2>"$WORK/verify-candidate.err"; then
  fail 'stale candidate fingerprint verified'
fi
has "$WORK/verify-candidate.err" 'candidate fingerprint mismatch' \
  'candidate drift was not attributed'

# The post-fix merge reuses pr-merge mode unchanged: one red-team artifact, a
# one-row reader table, the repair range's diff map, and no plan. It gets the
# same confinement and digest checks as the first merge, so a red-team result
# replaced after the brief was built fails verification instead of counting.
printf '{"findings":[]}\n' > "$merge_repo/evidence/post-fix-red-team.json"
printf 'post-fix-red-team\tsuccess\tevidence/post-fix-red-team.json\n' \
  > "$merge_repo/evidence/post-fix-readers.tsv"
printf 'M\tordinary-source.txt\n' > "$merge_repo/evidence/post-fix-diff-files.txt"
post_fix_candidate="$("$REPO_DIR/bin/pln-assurance" fingerprint \
  --root "$merge_repo" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" \
  | awk -F= '$1 == "CANDIDATE_SHA256" { print $2 }')"
post_fix_brief="$WORK/post-fix-merge.brief"
"$REPO_DIR/bin/pln-build-review-brief" --mode pr-merge \
  --contract "$REPO_DIR/src/workers/pr-review-merge.md" --root "$merge_repo" \
  --candidate "$post_fix_candidate" --commands "$merge_repo/commands.txt" \
  --environment "$merge_repo/environment.txt" --ledger "$merge_repo/REVIEW.md" \
  --diff-map "$merge_repo/evidence/post-fix-diff-files.txt" \
  --reader-metadata "$merge_repo/evidence/post-fix-readers.tsv" \
  --artifact post-fix-red-team "$merge_repo/evidence/post-fix-red-team.json" \
  --skill-root "$merge_repo/skills" --out "$post_fix_brief" >/dev/null \
  || fail 'single-artifact post-fix merge brief was not built'
[ "$(head -n 1 "$post_fix_brief")" = '# PR review merge contract' ] \
  || fail 'post-fix merge brief does not carry the merge contract first'
post_fix_role_hex="$(printf 'post-fix-red-team' | od -An -v -tx1 | tr -d ' \n')"
[ "$(grep -c "^ARTIFACT	$post_fix_role_hex	" "$post_fix_brief")" -eq 1 ] \
  || fail 'post-fix merge brief does not inventory exactly one red-team artifact'
[ "$(grep -c '^ARTIFACT	' "$post_fix_brief")" -eq 4 ] \
  || fail 'post-fix merge brief inventories artifacts beyond red team, ledger, diff map and reader table'
"$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$post_fix_brief" \
  | grep -q '^STATUS=verified$' || fail 'fresh post-fix merge context did not verify'
printf '{"findings":[{"title":"x"}]}\n' > "$merge_repo/evidence/post-fix-red-team.json"
if "$REPO_DIR/bin/pln-build-review-brief" --verify-pr-merge "$post_fix_brief" \
  >"$WORK/verify-post-fix.out" 2>"$WORK/verify-post-fix.err"; then
  fail 'replaced post-fix red-team artifact verified'
fi

# REVIEW.md publication is a narrow compare-and-publish boundary. A complete
# candidate becomes visible by one sibling rename only after its run identity,
# prior digest, and generation still match under the ledger lock.
publisher="$REPO_DIR/bin/pln-publish-review"
[ -x "$publisher" ] || fail 'missing executable REVIEW.md publisher'

# A pre-publisher resumable ledger has no generation. Its exact digest and
# durable run identity authorize one generation-zero migration without
# discarding any of its state or starting a new run.
legacy_root="$WORK/review-publish-legacy"
mkdir -p "$legacy_root/evidence"
printf '%s\n' '# Review' '## State' 'Run identity: legacy-run' \
  'Phase: fix' 'Finding: still open' > "$legacy_root/REVIEW.md"
legacy_digest="$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$legacy_root/REVIEW.md"; else sha256sum "$legacy_root/REVIEW.md"; fi | awk '{ print $1 }')"
printf '%s\n' '# Review' '## State' 'Run identity: legacy-run' \
  'Ledger generation: 1' 'Phase: fix' 'Finding: still open' \
  > "$legacy_root/evidence/migrated.md"
"$publisher" --root "$legacy_root" --ledger "$legacy_root/REVIEW.md" \
  --candidate "$legacy_root/evidence/migrated.md" --run-id legacy-run \
  --expected-digest "$legacy_digest" --expected-generation 0 \
  > "$WORK/publish-legacy.out"
cmp -s "$legacy_root/evidence/migrated.md" "$legacy_root/REVIEW.md" \
  || fail 'legacy REVIEW.md did not migrate without losing resumable state'

publish_root="$WORK/review-publish"
mkdir -p "$publish_root/evidence"
ledger="$publish_root/REVIEW.md"
run_id='run-fixture-1'
write_review_candidate() {
  local file="$1" generation="$2" body="$3"
  printf '%s\n' '# Review' '## State' "Run identity: $run_id" \
    "Ledger generation: $generation" "Body: $body" > "$file"
}
file_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    sha256sum "$1" | awk '{ print $1 }'
  fi
}

candidate_1="$publish_root/evidence/review-1.md"
write_review_candidate "$candidate_1" 1 'one'
"$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$candidate_1" --run-id "$run_id" \
  --expected-digest absent --expected-generation 0 > "$WORK/publish-create.out"
cmp -s "$candidate_1" "$ledger" || fail 'initial REVIEW.md candidate was not published exactly'
has "$WORK/publish-create.out" 'LEDGER_GENERATION=1' 'publisher omitted the new generation'
digest_1="$(file_sha256 "$ledger")"

candidate_2="$publish_root/evidence/review-2.md"
write_review_candidate "$candidate_2" 2 'two'
"$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$candidate_2" --run-id "$run_id" \
  --expected-digest "$digest_1" --expected-generation 1 > "$WORK/publish-replace.out"
cmp -s "$candidate_2" "$ledger" || fail 'replacement REVIEW.md candidate was not published exactly'
digest_2="$(file_sha256 "$ledger")"

# A delayed writer prepared from generation 1 cannot overwrite generation 2.
stale_candidate="$publish_root/evidence/review-stale.md"
write_review_candidate "$stale_candidate" 2 'stale'
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$stale_candidate" --run-id "$run_id" \
  --expected-digest "$digest_1" --expected-generation 1 \
  >"$WORK/publish-stale.out" 2>"$WORK/publish-stale.err"; then
  fail 'stale REVIEW.md publisher replaced a newer generation'
fi
has "$WORK/publish-stale.err" 'stale publication' 'stale writer failure was not attributed'
[ "$(file_sha256 "$ledger")" = "$digest_2" ] || fail 'stale writer changed REVIEW.md bytes'

# Generation, digest, and durable run identity are independent compare-and-set
# guards; holding one correct cannot compensate for another being stale.
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$stale_candidate" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 1 \
  >"$WORK/publish-generation.out" 2>"$WORK/publish-generation.err"; then
  fail 'stale REVIEW.md generation was accepted with a current digest'
fi
has "$WORK/publish-generation.err" 'current ledger generation differs' \
  'generation mismatch was not attributed'

candidate_3="$publish_root/evidence/review-3.md"
write_review_candidate "$candidate_3" 3 'three'
wrong_digest="$(printf '0%.0s' {1..64})"
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$candidate_3" --run-id "$run_id" \
  --expected-digest "$wrong_digest" --expected-generation 2 \
  >"$WORK/publish-digest.out" 2>"$WORK/publish-digest.err"; then
  fail 'stale REVIEW.md digest was accepted with a current generation'
fi
has "$WORK/publish-digest.err" 'current ledger digest differs' \
  'digest mismatch was not attributed'

other_run_candidate="$publish_root/evidence/review-other-run.md"
printf '%s\n' '# Review' '## State' 'Run identity: other-run' \
  'Ledger generation: 3' 'Body: other' > "$other_run_candidate"
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$other_run_candidate" --run-id 'other-run' \
  --expected-digest "$digest_2" --expected-generation 2 \
  >"$WORK/publish-run.out" 2>"$WORK/publish-run.err"; then
  fail 'different durable run identity replaced REVIEW.md'
fi
has "$WORK/publish-run.err" 'current run identity differs' \
  'run-identity mismatch was not attributed'
[ "$(file_sha256 "$ledger")" = "$digest_2" ] || fail 'failed compare-and-set guard changed REVIEW.md bytes'

# Copy/pre-rename failures retain the prior complete bytes and clean every
# sibling temp and lock. These are process-visible replacement guarantees, not
# a claim that directory data survives power loss.
for fault in partial-copy before-rename; do
  if PLN_PUBLISH_REVIEW_FAULT="$fault" "$publisher" \
    --root "$publish_root" --ledger "$ledger" --candidate "$candidate_3" \
    --run-id "$run_id" --expected-digest "$digest_2" --expected-generation 2 \
    >"$WORK/publish-$fault.out" 2>"$WORK/publish-$fault.err"; then
    fail "$fault REVIEW.md publication unexpectedly succeeded"
  fi
  [ "$(file_sha256 "$ledger")" = "$digest_2" ] || fail "$fault changed REVIEW.md bytes"
  if find "$publish_root" -maxdepth 1 \( -name '.REVIEW.md.publish.*' -o -name '.REVIEW.md.publish.lock' \) \
    | grep -q .; then
    fail "$fault left REVIEW.md publication debris"
  fi
done

# Guard the complete candidate boundary before taking the lock.
printf '' > "$publish_root/evidence/empty.md"
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$publish_root/evidence/empty.md" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 2 >/dev/null 2>&1; then
  fail 'empty REVIEW.md candidate was accepted'
fi
ln -s "$candidate_3" "$publish_root/evidence/linked.md"
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$publish_root/evidence/linked.md" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 2 >/dev/null 2>&1; then
  fail 'symlink REVIEW.md candidate was accepted'
fi
ln -s "$publish_root/evidence" "$publish_root/linked-evidence"
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$publish_root/linked-evidence/review-3.md" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 2 >/dev/null 2>&1; then
  fail 'REVIEW.md candidate beneath a symlink parent was accepted'
fi
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$outside" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 2 >/dev/null 2>&1; then
  fail 'out-of-root REVIEW.md candidate was accepted'
fi
if "$publisher" --root "$publish_root" --ledger "$ledger" \
  --candidate "$ledger" --run-id "$run_id" \
  --expected-digest "$digest_2" --expected-generation 2 >/dev/null 2>&1; then
  fail 'canonical REVIEW.md was accepted as its own candidate'
fi

# Two publishers derived from the same state serialize: exactly one transition
# wins and the other is rejected without erasing the winner.
concurrent_a="$publish_root/evidence/review-3a.md"
concurrent_b="$publish_root/evidence/review-3b.md"
write_review_candidate "$concurrent_a" 3 'three-a'
write_review_candidate "$concurrent_b" 3 'three-b'
set +e
"$publisher" --root "$publish_root" --ledger "$ledger" --candidate "$concurrent_a" \
  --run-id "$run_id" --expected-digest "$digest_2" --expected-generation 2 \
  >"$WORK/publish-a.out" 2>"$WORK/publish-a.err" & publish_a_pid=$!
"$publisher" --root "$publish_root" --ledger "$ledger" --candidate "$concurrent_b" \
  --run-id "$run_id" --expected-digest "$digest_2" --expected-generation 2 \
  >"$WORK/publish-b.out" 2>"$WORK/publish-b.err" & publish_b_pid=$!
wait "$publish_a_pid"; publish_a_status=$?
wait "$publish_b_pid"; publish_b_status=$?
set -e
[ "$((publish_a_status + publish_b_status))" -eq 2 ] \
  || fail 'concurrent REVIEW.md publishers did not produce one success and one stale rejection'
if [ "$publish_a_status" -eq 0 ]; then
  cmp -s "$concurrent_a" "$ledger" || fail 'concurrent winner was not retained byte-for-byte'
  has "$WORK/publish-b.err" 'stale publication' 'concurrent loser was not rejected as stale'
else
  cmp -s "$concurrent_b" "$ledger" || fail 'concurrent winner was not retained byte-for-byte'
  has "$WORK/publish-a.err" 'stale publication' 'concurrent loser was not rejected as stale'
fi

echo "OK"
