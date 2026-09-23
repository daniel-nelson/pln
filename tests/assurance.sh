#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSURANCE="$REPO_DIR/bin/pln-assurance"
GAUNTLET="$REPO_DIR/bin/pln-gauntlet"
SIMPLIFY="$REPO_DIR/bin/pln-simplify"

fail() { echo "FAIL: $*" >&2; exit 1; }
has_line() { printf '%s\n' "$1" | grep -Fqx "$2" || fail "$3"; }

[ -x "$ASSURANCE" ] || fail "missing executable assurance helper: $ASSURANCE"
[ -x "$GAUNTLET" ] || fail "missing executable gauntlet helper: $GAUNTLET"

# Semantic signals decide the floor. Numeric size can raise R1 to R2 but can
# never lower an R3 change.
out="$($ASSURANCE classify --signals routine --substantive-files 2 --non-generated-lines 18)"
has_line "$out" 'RISK=R1' 'routine work did not classify as R1'

out="$($ASSURANCE classify --signals routine --substantive-files 11 --non-generated-lines 18)"
has_line "$out" 'RISK=R2' 'file threshold did not raise routine work to R2'

out="$($ASSURANCE classify --signals auth --substantive-files 1 --non-generated-lines 1)"
has_line "$out" 'RISK=R3' 'tiny authentication change was lowered by line count'

out="$($ASSURANCE classify --signals unknown --substantive-files 0 --non-generated-lines 0)"
has_line "$out" 'RISK=R3' 'unknown risk did not fail closed to R3'

if "$ASSURANCE" classify --signals routine,auth --substantive-files nope --non-generated-lines 1 >/dev/null 2>&1; then
  fail 'non-numeric substantive-file count was accepted'
fi

# R3 has exactly one broad slot, at most two risk-specific slots, and one
# adversarial slot. A peer substitutes in that slot rather than adding a fifth.
out="$($ASSURANCE roster --risk R3 --areas security,data,compatibility --adversary peer)"
has_line "$out" $'SLOT\tbroad\tsame-model' 'R3 roster lost the broad reader'
has_line "$out" $'SLOT\trisk-security\tsame-model' 'R3 roster lost first risk reader'
has_line "$out" $'SLOT\trisk-data\tsame-model' 'R3 roster lost second risk reader'
has_line "$out" $'SLOT\tadversarial\tpeer' 'peer did not fill the adversarial slot'
[ "$(printf '%s\n' "$out" | grep -c '^SLOT')" -eq 4 ] || fail 'R3 pre-fix roster exceeded four slots'

out="$($ASSURANCE roster --risk R3 --areas security --adversary local)"
has_line "$out" $'SLOT\tadversarial\tsame-model' 'local adversarial substitute was not attributed'

out="$($ASSURANCE roster --risk R2 --areas data,testing,security --adversary local)"
[ "$(printf '%s\n' "$out" | grep -c '^SLOT')" -eq 3 ] || fail 'R2 roster did not cap specialists at two'

out="$($ASSURANCE roster --risk R1 --areas security --adversary peer)"
[ "$(printf '%s\n' "$out" | grep -c '^SLOT')" -eq 1 ] || fail 'R1 roster was not broad-only'

# A plan-review round whose every rostered reader wrote, this round, exactly the
# terminal no-findings line needs no merge worker. Every other state keeps it:
# a missing role, an artifact left from an earlier round, a failed reader, and a
# roster where one reader found something. The verdict never carries content.
SKIP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pln-merge-skip-test.XXXXXX")"
trap 'rm -rf "$SKIP_DIR"' EXIT
touch -t 202609220900 "$SKIP_DIR/round.brief.md"
empty_artifact() { printf 'Nothing worth changing\n' > "$SKIP_DIR/$1"; touch -t 202609220930 "$SKIP_DIR/$1"; }
empty_artifact broad.md
empty_artifact risk-data.md
empty_artifact adversarial.md
skip() {
  "$ASSURANCE" merge-skip --since "$SKIP_DIR/round.brief.md" "$@"
}
out="$(skip --roles broad,risk-data,adversarial --artifact "broad=$SKIP_DIR/broad.md" \
  --artifact "risk-data=$SKIP_DIR/risk-data.md" --artifact "adversarial=$SKIP_DIR/adversarial.md")"
has_line "$out" 'SKIP_MERGE=yes' 'an all-empty fresh roster still ran the merge'
has_line "$out" 'REASON=all-empty' 'an all-empty skip lost its reason'

out="$(skip --roles broad,risk-data,adversarial --artifact "broad=$SKIP_DIR/broad.md" \
  --artifact "risk-data=$SKIP_DIR/risk-data.md")"
has_line "$out" 'SKIP_MERGE=no' 'a rostered role with no artifact skipped the merge'
has_line "$out" 'REASON=adversarial:missing' 'a missing role was not named'
out="$(skip --roles broad --artifact "broad=$SKIP_DIR/absent.md")"
has_line "$out" 'REASON=broad:missing' 'an artifact path that does not exist was not missing coverage'

touch -t 202609220800 "$SKIP_DIR/risk-data.md"
out="$(skip --roles broad,risk-data --artifact "broad=$SKIP_DIR/broad.md" --artifact "risk-data=$SKIP_DIR/risk-data.md")"
has_line "$out" 'SKIP_MERGE=no' 'an artifact from an earlier round skipped the merge'
has_line "$out" 'REASON=risk-data:stale' 'a stale artifact was not named'
empty_artifact risk-data.md

printf 'STATUS=failed\nREASON=unauthenticated\n' > "$SKIP_DIR/adversarial.md"
touch -t 202609220930 "$SKIP_DIR/adversarial.md"
out="$(skip --roles broad,adversarial --artifact "broad=$SKIP_DIR/broad.md" --artifact "adversarial=$SKIP_DIR/adversarial.md")"
has_line "$out" 'SKIP_MERGE=no' 'a failed reader counted as a clean one'
: > "$SKIP_DIR/adversarial.md"; touch -t 202609220930 "$SKIP_DIR/adversarial.md"
out="$(skip --roles broad,adversarial --artifact "broad=$SKIP_DIR/broad.md" --artifact "adversarial=$SKIP_DIR/adversarial.md")"
has_line "$out" 'REASON=adversarial:empty' 'an empty reader artifact counted as a clean one'

# "Nothing worth changing" also ends a review that has findings, so the test is
# the whole file, never its last line.
printf '1. Item 2 cites a file that does not exist.\n\nNothing worth changing\n' > "$SKIP_DIR/risk-data.md"
touch -t 202609220930 "$SKIP_DIR/risk-data.md"
out="$(skip --roles broad,risk-data --artifact "broad=$SKIP_DIR/broad.md" --artifact "risk-data=$SKIP_DIR/risk-data.md")"
has_line "$out" 'SKIP_MERGE=no' 'a mixed empty/non-empty roster skipped the merge'
has_line "$out" 'REASON=risk-data:not-empty' 'the reader with findings was not named'
case "$out" in *'does not exist'*) fail 'merge-skip printed finding text' ;; esac

ln -s "$SKIP_DIR/broad.md" "$SKIP_DIR/link.md"
out="$(skip --roles broad --artifact "broad=$SKIP_DIR/link.md")"
has_line "$out" 'REASON=broad:symlink' 'a symlinked artifact was followed'

for bad in "--roles risk-data --artifact risk-data=$SKIP_DIR/broad.md" \
  "--roles broad --artifact adversarial=$SKIP_DIR/broad.md" \
  "--roles broad,broad --artifact broad=$SKIP_DIR/broad.md" \
  "--roles broad --artifact broad=$SKIP_DIR/broad.md --artifact broad=$SKIP_DIR/broad.md"; do
  # shellcheck disable=SC2086
  if skip $bad >/dev/null 2>&1; then fail "merge-skip accepted a malformed roster: $bad"; fi
done
if "$ASSURANCE" merge-skip --roles broad --since "$SKIP_DIR/no-marker" --artifact "broad=$SKIP_DIR/broad.md" >/dev/null 2>&1; then
  fail 'merge-skip ran without a round-start marker'
fi
rm -rf "$SKIP_DIR"
trap - EXIT

# Adopted shipping authorizes every new, verified, in-scope repair regardless
# of how many prior review rounds ran. Only per-defect non-progress or a real
# user-owned boundary can stop the unattended flow.
out="$($ASSURANCE repair-action --disposition new --failed-attempts 0)"
has_line "$out" 'ACTION=repair' 'a new round-two finding asked for redundant permission'
has_line "$out" 'REASON=new-verified-finding' 'a new finding lost its repair reason'

out="$($ASSURANCE repair-action --disposition persisted --failed-attempts 2)"
has_line "$out" 'ACTION=repair' 'a same-defect retry stopped before the stuck threshold'

out="$($ASSURANCE repair-action --disposition persisted --failed-attempts 3)"
has_line "$out" 'ACTION=block' 'three failed repairs of the same defect did not stop'
has_line "$out" 'REASON=same-defect-stuck' 'a stuck defect lost its blocker reason'

for disposition in needs-decision out-of-scope destructive worker-blocked; do
  out="$($ASSURANCE repair-action --disposition "$disposition" --failed-attempts 0)"
  has_line "$out" 'ACTION=block' "$disposition did not preserve a genuine blocker"
done

if "$ASSURANCE" repair-action --disposition persisted --failed-attempts nope >/dev/null 2>&1; then
  fail 'repair action accepted a non-numeric attempt count'
fi

# A finding with no consequence the shipped system produces is dropped by the
# merge worker and never reaches a disposition at all. `preference` is not a
# repair action, and admitting one here would be a branch with no caller.
if "$ASSURANCE" repair-action --disposition preference --failed-attempts 0 >/dev/null 2>&1; then
  fail 'repair-action still admits a disposition nothing routes to it'
fi

# Repair identity follows the semantic proof rather than a title, round, or
# citation. Structural keys additionally bind the established owner.
structural_one="$($ASSURANCE repair-key --kind structural --boundary 'configuration loading' --owner 'src/config.ts' --check 'bash tests/config.sh')"
structural_two="$($ASSURANCE repair-key --check 'bash tests/config.sh' --owner 'src/config.ts' --boundary 'configuration loading' --kind structural)"
[ "$structural_one" = "$structural_two" ] || fail 'structural repair key depends on argument order'
case "$structural_one" in REPAIR_KEY=structural:????????????????????????????????????????????????????????????????) ;; *) fail 'structural repair key output is malformed' ;; esac

structural_changed="$($ASSURANCE repair-key --kind structural --boundary 'configuration loading' --owner 'src/config.ts' --check 'bash tests/config-compat.sh')"
[ "$structural_changed" != "$structural_one" ] || fail 'different structural reference checks shared a repair key'

behavioral="$($ASSURANCE repair-key --kind behavioral --boundary 'configuration loading' --check 'bash tests/config.sh')"
[ "$behavioral" != "$structural_one" ] || fail 'behavioral and structural identities collided'

if "$ASSURANCE" repair-key --kind structural --boundary ownerless --check check >/dev/null 2>&1; then
  fail 'structural repair key accepted a missing owner'
fi

# Fingerprints bind verification to the exact candidate tree, command set, and
# relevant environment. Any one changing invalidates reuse.
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/pln-assurance-test.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$FIXTURE-unknown" "$FIXTURE-shallow"' EXIT
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email test@example.com
git -C "$FIXTURE" config user.name Test
printf 'one\n' > "$FIXTURE/source.txt"
git -C "$FIXTURE" add source.txt
git -C "$FIXTURE" commit -qm initial
printf 'bash tests/a.sh\n' > "$FIXTURE/commands.txt"
printf 'runtime=node-24\ntimezone=UTC\n' > "$FIXTURE/environment.txt"

first="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
second="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
[ "$first" = "$second" ] || fail 'unchanged candidate fingerprint was not deterministic'

review_before="$($ASSURANCE diff-fingerprint --root "$FIXTURE" --base HEAD)"
has_line "$review_before" "DIFF_BASE=$(git -C "$FIXTURE" rev-parse HEAD)" \
  'review fingerprint lost its exact merge base'
printf 'two\n' > "$FIXTURE/source.txt"
review_after="$($ASSURANCE diff-fingerprint --root "$FIXTURE" --base HEAD)"
[ "$review_before" != "$review_after" ] || fail 'changed reviewed diff preserved its fingerprint'
printf 'one\n' > "$FIXTURE/source.txt"
[ "$($ASSURANCE diff-fingerprint --root "$FIXTURE" --base HEAD)" = "$review_before" ] \
  || fail 'restored reviewed diff did not restore its fingerprint'

# The size facts a worker used to read off the numstat are computed over the same
# subject: merge-base to the working tree, text lines counted, binaries apart.
out="$($ASSURANCE diff-stats --root "$FIXTURE" --base HEAD)"
has_line "$out" 'FILES=0' 'an empty reviewed diff reported changed files'
has_line "$out" 'DIFF_LINES=0' 'an empty reviewed diff reported changed lines'
printf 'two\nthree\n' > "$FIXTURE/source.txt"
printf '\000\001binary' > "$FIXTURE/blob.bin"
git -C "$FIXTURE" add blob.bin
out="$($ASSURANCE diff-stats --root "$FIXTURE" --base HEAD)"
has_line "$out" 'FILES=2' 'diff-stats miscounted changed files'
has_line "$out" 'ADDED=2' 'diff-stats miscounted added lines'
has_line "$out" 'DELETED=1' 'diff-stats miscounted deleted lines'
has_line "$out" 'DIFF_LINES=3' 'DIFF_LINES is not added plus deleted'
has_line "$out" 'BINARY=1' 'diff-stats did not count a binary file apart'
if "$ASSURANCE" diff-stats --root "$FIXTURE" --base no-such-ref >/dev/null 2>&1; then
  fail 'diff-stats accepted a base that is not a commit'
fi
git -C "$FIXTURE" rm -q --cached blob.bin
rm -f "$FIXTURE/blob.bin"
printf 'one\n' > "$FIXTURE/source.txt"

# Where the bytes are recorded is not what they are. Staging and committing an
# already-verified tree change HEAD and `git status` while leaving every file
# identical, so the fingerprint must not move — and must return to its earlier
# value when the content does. It once folded both in, and the commit that
# followed a passing gauntlet invalidated it and bought a second full run of the
# same commands over the same content.
FP() { $ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt"; }
printf 'pending\n' > "$FIXTURE/pending.txt"
untracked_fp="$(FP)"
[ "$untracked_fp" != "$first" ] || fail 'a new untracked file did not invalidate fingerprint'
git -C "$FIXTURE" add pending.txt
[ "$(FP)" = "$untracked_fp" ] || fail 'staging an unchanged file moved the fingerprint'
git -C "$FIXTURE" commit -qm pending
[ "$(FP)" = "$untracked_fp" ] || fail 'committing an unchanged tree moved the fingerprint'
git -C "$FIXTURE" rm -q pending.txt
git -C "$FIXTURE" commit -qm drop-pending
[ "$(FP)" = "$first" ] || fail 'restoring the content did not restore the fingerprint'

printf 'two\n' > "$FIXTURE/source.txt"
tree_changed="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
[ "$tree_changed" != "$first" ] || fail 'working-tree edit did not invalidate fingerprint'

printf 'one\n' > "$FIXTURE/source.txt"
printf 'bash tests/b.sh\n' > "$FIXTURE/commands.txt"
commands_changed="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
[ "$commands_changed" != "$first" ] || fail 'command-set edit did not invalidate fingerprint'

printf 'bash tests/a.sh\n' > "$FIXTURE/commands.txt"
printf 'runtime=node-24\ntimezone=America/Los_Angeles\n' > "$FIXTURE/environment.txt"
environment_changed="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
[ "$environment_changed" != "$first" ] || fail 'environment edit did not invalidate fingerprint'

# The command artifact is the declaration boundary for safe gauntlet
# parallelism. Legacy lists remain serial. V1 groups may overlap only when the
# project declared the group and no dependency, exclusive resource, or tree
# mutation makes the pair unsafe. Results are joined in declaration order.
GAUNTLET_OUT="$(mktemp -d "${TMPDIR:-/tmp}/pln-gauntlet-test.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$FIXTURE-unknown" "$FIXTURE-shallow" "$GAUNTLET_OUT"' EXIT
printf 'runtime=test\nexecutor=worker\n' > "$GAUNTLET_OUT/environment.txt"
printf 'printf first > %s/legacy-first\ntest -f %s/legacy-first\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT" > "$GAUNTLET_OUT/legacy.commands"
"$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/legacy.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/legacy-logs" \
  --status "$GAUNTLET_OUT/legacy.status"
has_line "$(cat "$GAUNTLET_OUT/legacy.status")" $'RESULT\t2\tpass\t0' \
  'legacy command list did not execute serially'

{
  printf 'PLN_GAUNTLET_V1\n'
  printf 'a\t-\tfast\t-\tclean\tworker\ttouch %s/a.started; i=0; while [ ! -e %s/b.started ] && [ $i -lt 40 ]; do sleep 0.05; i=$((i+1)); done; test -e %s/b.started; touch %s/a.done\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'b\t-\tfast\t-\tclean\tworker\ttouch %s/b.started; i=0; while [ ! -e %s/a.started ] && [ $i -lt 40 ]; do sleep 0.05; i=$((i+1)); done; test -e %s/a.started; touch %s/b.done\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'after\ta,b\t-\t-\tclean\tworker\ttest -e %s/a.done && test -e %s/b.done\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'lock-a\tafter\tlocked\tdb\tclean\tworker\tmkdir %s/lock; sleep 0.1; rmdir %s/lock\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'lock-b\tafter\tlocked\tdb\tclean\tworker\tmkdir %s/lock; sleep 0.1; rmdir %s/lock\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'mutator-a\tlock-a,lock-b\tmutators\t-\tmutates\tworker\tmkdir %s/mutator-lock; sleep 0.1; rmdir %s/mutator-lock\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT"
  printf 'mutator-b\tlock-a,lock-b\tmutators\t-\tmutates\tworker\tmkdir %s/mutator-lock; sleep 0.1; rmdir %s/mutator-lock\n' "$GAUNTLET_OUT" "$GAUNTLET_OUT"
} > "$GAUNTLET_OUT/declared.commands"
"$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/declared.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/declared-logs" \
  --status "$GAUNTLET_OUT/declared.status"
[ "$(grep '^RESULT' "$GAUNTLET_OUT/declared.status" | cut -f2 | paste -sd, -)" = 'a,b,after,lock-a,lock-b,mutator-a,mutator-b' ] \
  || fail 'declared gauntlet results lost deterministic declaration order'
[ "$(find "$GAUNTLET_OUT/declared-logs" -name '*.log' | wc -l | tr -d ' ')" -eq 7 ] \
  || fail 'declared gauntlet did not keep one raw log per command'

printf 'runtime=test\nexecutor=coordinator\n' > "$GAUNTLET_OUT/environment-executor.txt"
worker_identity="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$GAUNTLET_OUT/declared.commands" --environment "$GAUNTLET_OUT/environment.txt")"
coordinator_identity="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$GAUNTLET_OUT/declared.commands" --environment "$GAUNTLET_OUT/environment-executor.txt")"
[ "$worker_identity" != "$coordinator_identity" ] \
  || fail 'executor requirement did not participate in candidate identity'

printf 'PLN_GAUNTLET_V1\ncoord\t-\t-\t-\tclean\tcoordinator\ttest ! -e %s/coordinator-ran; touch %s/coordinator-ran\nwork\tcoord\t-\t-\tclean\tworker\ttest -e %s/coordinator-ran; touch %s/worker-ran\n' \
  "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT" "$GAUNTLET_OUT" > "$GAUNTLET_OUT/executors.commands"
if "$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/executors.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/unsafe-default-logs" \
  --status "$GAUNTLET_OUT/unsafe-default.status" >/dev/null 2>&1; then
  fail 'default executor ran a declared coordinator-only command'
fi
[ ! -e "$GAUNTLET_OUT/coordinator-ran" ] \
  || fail 'default executor refusal happened after coordinator-only execution'
"$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/executors.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/coordinator-logs" \
  --status "$GAUNTLET_OUT/coordinator.status" --executor coordinator
[ ! -e "$GAUNTLET_OUT/worker-ran" ] || fail 'coordinator pass ran a worker command'
has_line "$(cat "$GAUNTLET_OUT/coordinator.status")" $'RESULT\twork\tdeferred\t-' \
  'coordinator pass did not defer worker command'
"$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/executors.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/worker-logs" \
  --status "$GAUNTLET_OUT/worker.status" --executor worker --completed "$GAUNTLET_OUT/coordinator.status"
[ -e "$GAUNTLET_OUT/worker-ran" ] || fail 'worker pass did not run after coordinator prerequisite'
has_line "$(cat "$GAUNTLET_OUT/worker.status")" $'RESULT\tcoord\tpass\t0' \
  'worker pass did not consume coordinator result'

printf 'PLN_GAUNTLET_V1\nfail\t-\t-\t-\tclean\tworker\texit 7\nblocked\tfail\t-\t-\tclean\tworker\texit 0\n' > "$GAUNTLET_OUT/fail.commands"
if "$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/fail.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/fail-logs" \
  --status "$GAUNTLET_OUT/fail.status" >/dev/null 2>&1; then
  fail 'failed/incomplete gauntlet returned success'
fi
has_line "$(cat "$GAUNTLET_OUT/fail.status")" $'RESULT\tfail\tfail\t7' 'failed command lost its exit status'
has_line "$(cat "$GAUNTLET_OUT/fail.status")" $'RESULT\tblocked\tincomplete\t-' 'dependent command was not fail-closed incomplete'

printf 'PLN_GAUNTLET_V1\nmutate\t-\t-\t-\tmutates\tworker\tprintf changed > source.txt\n' > "$GAUNTLET_OUT/mutate.commands"
if "$GAUNTLET" run --root "$FIXTURE" --commands "$GAUNTLET_OUT/mutate.commands" \
  --environment "$GAUNTLET_OUT/environment.txt" --logs "$GAUNTLET_OUT/mutate-logs" \
  --status "$GAUNTLET_OUT/mutate.status" >/dev/null 2>&1; then
  fail 'command-caused tree mutation returned success'
fi
has_line "$(cat "$GAUNTLET_OUT/mutate.status")" 'TREE_MUTATION=detected' 'tree mutation was not recorded fail-closed'
git -C "$FIXTURE" checkout -q -- source.txt

# A tracked symlink to a directory must fingerprint (git hash-object on the
# path follows the link and dies), and retargeting the link must invalidate.
mkdir "$FIXTURE/linked-dir"
printf 'inner\n' > "$FIXTURE/linked-dir/inner.txt"
ln -s linked-dir "$FIXTURE/dir-link"
git -C "$FIXTURE" add linked-dir dir-link
if ! symlinked="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt" 2>/dev/null)"; then
  fail 'fingerprint failed on a tracked symlink to a directory'
fi
rm "$FIXTURE/dir-link"
ln -s other-target "$FIXTURE/dir-link"
retargeted="$($ASSURANCE fingerprint --root "$FIXTURE" --commands "$FIXTURE/commands.txt" --environment "$FIXTURE/environment.txt")"
[ "$retargeted" != "$symlinked" ] || fail 'retargeted symlink did not invalidate fingerprint'
rm "$FIXTURE/dir-link"
ln -s linked-dir "$FIXTURE/dir-link"

# Simplification success metadata has a content-only identity distinct from the
# assurance candidate fingerprint. The marker grammar and cadence boundaries
# are a portable V1 protocol, not prose interpreted by a model.
[ -x "$SIMPLIFY" ] || fail 'missing executable simplification helper'
git -C "$FIXTURE" checkout -q -- source.txt
git -C "$FIXTURE" add commands.txt environment.txt
git -C "$FIXTURE" commit -qm fixtures
content="$($SIMPLIFY fingerprint --repo "$FIXTURE")"
case "$content" in CONTENT_SHA256=????????????????????????????????????????????????????????????????) ;; *) fail 'content fingerprint output is malformed' ;; esac
if "$SIMPLIFY" marker --repo "$FIXTURE" --completed 2026-02-31T12:34:56Z >/dev/null 2>&1; then
  fail 'marker accepted a calendar-invalid UTC timestamp'
fi
marker="$($SIMPLIFY marker --repo "$FIXTURE" --completed 2026-08-18T12:34:56Z)"
[ "$marker" = "PLN-SIMPLIFY-V1 completed=2026-08-18T12:34:56Z content-sha256=${content#CONTENT_SHA256=}" ] \
  || fail 'V1 marker grammar changed'
if "$SIMPLIFY" marker --repo "$FIXTURE" --completed 2026-08-18T12:34:56+00:00 >/dev/null 2>&1; then
  fail 'marker accepted a non-canonical UTC timestamp'
fi
git -C "$FIXTURE" commit --allow-empty -qm "simplification assessment" -m "$marker"
marker_new="$($SIMPLIFY marker --repo "$FIXTURE" --completed 2026-08-18T12:35:00Z)"
git -C "$FIXTURE" commit --allow-empty -qm "newer simplification assessment" -m "$marker_new"
status="$($SIMPLIFY status --repo "$FIXTURE" --now 2026-08-18T12:34:56Z)"
has_line "$status" 'STATUS=fresh' 'an unchanged marker candidate was not fresh'
has_line "$status" "MARKER=$marker_new" 'multiple-marker winner did not select the greatest completion time'
marker="$marker_new"
selected="$($SIMPLIFY selected-marker --repo "$FIXTURE" --head HEAD)"
[ "$selected" = "$marker" ] || fail 'selected-marker did not return the exact valid winner'
BODY="$FIXTURE/pr-body.txt"
printf 'Summary\n\nPLN-SIMPLIFY-V99 completed=bad\n' > "$BODY"
"$SIMPLIFY" propagate --repo "$FIXTURE" --body "$BODY"
body_once="$(shasum -a 256 "$BODY" | awk '{print $1}')"
"$SIMPLIFY" propagate --repo "$FIXTURE" --body "$BODY"
body_twice="$(shasum -a 256 "$BODY" | awk '{print $1}')"
[ "$body_once" = "$body_twice" ] || fail 'PR-body propagation changed bytes on its second run'
[ "$(grep -c '^PLN-SIMPLIFY-V1 completed=' "$BODY")" -eq 1 ] \
  || fail 'PR-body marker propagation was not idempotent'
grep -qF "$marker" "$BODY" || fail 'PR-body propagation changed the selected exact marker line'

# Hybrid cadence: unchanged content stays fresh; after a content change, either
# visible-commit or elapsed-time threshold can make it due/overdue, with overdue
# taking precedence. Defaults are frozen at 100/250 commits and 90/180 days.
printf 'changed\n' > "$FIXTURE/source.txt"
git -C "$FIXTURE" add source.txt
git -C "$FIXTURE" commit -qm changed
if "$SIMPLIFY" selected-marker --repo "$FIXTURE" --head HEAD >/dev/null 2>&1; then
  fail 'selected-marker accepted a marker invalidated by candidate content'
fi
stale_body_hash="$(shasum -a 256 "$BODY" | awk '{print $1}')"
if "$SIMPLIFY" propagate --repo "$FIXTURE" --body "$BODY" --head HEAD >/dev/null 2>&1; then
  fail 'PR-body propagation accepted a marker invalidated by candidate content'
fi
[ "$(shasum -a 256 "$BODY" | awk '{print $1}')" = "$stale_body_hash" ] \
  || fail 'failed stale-marker propagation mutated the PR body'
status="$($SIMPLIFY status --repo "$FIXTURE" --now 2026-11-16T12:35:00Z --due-commits 100 --overdue-commits 250 --due-days 90 --overdue-days 180)"
has_line "$status" 'STATUS=due' 'time threshold did not make changed content due'
status="$($SIMPLIFY status --repo "$FIXTURE" --now 2026-08-18T12:34:56Z --due-commits 1 --overdue-commits 250 --due-days 90 --overdue-days 180)"
has_line "$status" 'STATUS=due' 'visible-commit threshold did not make changed content due'
status="$($SIMPLIFY status --repo "$FIXTURE" --now 2027-02-14T12:35:00Z --due-commits 100 --overdue-commits 250 --due-days 90 --overdue-days 180)"
has_line "$status" 'STATUS=overdue' 'time threshold did not make changed content overdue'

# Missing/stripped metadata is unknown, malformed marker-like lines do not win,
# and unsupported protocols fail open as unknown rather than fabricated age.
UNKNOWN="$FIXTURE-unknown"
mkdir -p "$UNKNOWN"
git -C "$UNKNOWN" init -q
git -C "$UNKNOWN" config user.email test@example.com
git -C "$UNKNOWN" config user.name Test
printf 'x\n' > "$UNKNOWN/x"
git -C "$UNKNOWN" add x
git -C "$UNKNOWN" commit -qm 'PLN-SIMPLIFY-V2 completed=2026-08-18T12:34:56Z content-sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
status="$($SIMPLIFY status --repo "$UNKNOWN" --now 2026-08-18T12:34:56Z)"
has_line "$status" 'STATUS=unknown' 'missing supported metadata fabricated staleness'

# A repository that has never recorded a marker is measured from its own first
# commit, so the first assessment of all is reachable by cadence instead of being
# the one thing cadence can never ask for. Past either due threshold it says
# never-simplified and claims no marker; it never escalates to overdue, so it
# cannot block a required policy. A shallow clone keeps saying unknown, because
# a truncated history would invent both numbers.
status="$($SIMPLIFY status --repo "$UNKNOWN" --now 2026-08-18T12:34:56Z --due-commits 1)"
has_line "$status" 'STATUS=due' 'an unmarked repository past the commit threshold stayed silent'
has_line "$status" 'REASON=never-simplified' 'an unmarked repository reported a marker-derived reason'
has_line "$status" 'MARKER=none' 'an unmarked repository fabricated a marker'
status="$($SIMPLIFY status --repo "$UNKNOWN" --now 2030-08-18T12:34:56Z)"
has_line "$status" 'STATUS=due' 'an unmarked repository past the age threshold stayed silent'
status="$($SIMPLIFY status --repo "$UNKNOWN" --now 2030-08-18T12:34:56Z --due-commits 1 --overdue-commits 1 --due-days 1 --overdue-days 1)"
has_line "$status" 'STATUS=due' 'an unmarked repository escalated past due'
printf 'schema=1\nmode=required\nminimum-client=1\nprotocol=1\n' > "$UNKNOWN/.pln-simplify-policy"
decision="$($SIMPLIFY enforce --repo "$UNKNOWN" --base HEAD --head HEAD --run-id never --now 2030-08-18T12:34:56Z)"
has_line "$decision" 'ACTION=disclose' 'a never-simplified repository blocked a required policy'
rm "$UNKNOWN/.pln-simplify-policy"
SHALLOW="$FIXTURE-shallow"
git clone -q --depth 1 "file://$UNKNOWN" "$SHALLOW" 2>/dev/null
status="$($SIMPLIFY status --repo "$SHALLOW" --now 2030-08-18T12:34:56Z --due-commits 1)"
has_line "$status" 'STATUS=unknown' 'a shallow clone fabricated never-simplified cadence'
has_line "$status" 'REASON=shallow-no-valid-reachable-v1-marker' 'a shallow clone lost its truncation attribution'

# Repository policy is advisory by default. A supported V1 required policy can
# stop only overdue, while disabled is silent and unknown remains non-blocking.
policy="$FIXTURE/.pln-simplify-policy"
printf 'schema=1\nmode=required\nminimum-client=1\nprotocol=1\ndue-commits=100\noverdue-commits=250\ndue-days=90\noverdue-days=180\n' > "$policy"
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id run-1 --now 2027-02-14T12:35:00Z)"
has_line "$decision" 'ACTION=block' 'required policy did not block overdue status'
binding_one="$(printf '%s\n' "$decision" | sed -n 's/^BYPASS_BINDING=//p')"
[ -n "$binding_one" ] || fail 'required-policy result omitted its run-bound bypass binding'
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id run-2 --now 2027-02-14T12:35:00Z)"
binding_two="$(printf '%s\n' "$decision" | sed -n 's/^BYPASS_BINDING=//p')"
[ "$binding_one" != "$binding_two" ] || fail 'freshness bypass binding ignored durable run identity'
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD^ --head HEAD --run-id run-1 --now 2027-02-14T12:35:00Z)"
binding_base="$(printf '%s\n' "$decision" | sed -n 's/^BYPASS_BINDING=//p')"
[ "$binding_one" != "$binding_base" ] || fail 'freshness bypass binding ignored resolved base identity'
printf 'schema=1\nmode=required\nminimum-client=1\nprotocol=1\ndue-commits=99\noverdue-commits=249\ndue-days=89\noverdue-days=179\n' > "$policy"
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id run-1 --now 2027-02-14T12:35:00Z)"
binding_policy="$(printf '%s\n' "$decision" | sed -n 's/^BYPASS_BINDING=//p')"
[ "$binding_one" != "$binding_policy" ] || fail 'freshness bypass binding ignored policy content'

# Explicit status arguments are the test/CI override layer and win over policy
# thresholds. Unsupported policy versions fail closed only in required mode;
# advisory older-client compatibility remains observable but non-blocking.
printf 'schema=1\nmode=advisory\nminimum-client=1\nprotocol=1\ndue-commits=500\noverdue-commits=600\ndue-days=500\noverdue-days=600\n' > "$policy"
status="$($SIMPLIFY status --repo "$FIXTURE" --now 2026-08-18T12:34:56Z --due-commits 1 --overdue-commits 250 --due-days 90 --overdue-days 180)"
has_line "$status" 'STATUS=due' 'explicit cadence threshold did not override repository policy'
printf 'schema=2\nmode=advisory\nminimum-client=99\nprotocol=2\n' > "$policy"
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id compatibility --now 2027-02-14T12:35:00Z)"
has_line "$decision" 'ACTION=follow-up' 'unsupported advisory policy became a blocking compatibility break'
printf 'schema=1\nmode=disabled\nminimum-client=1\nprotocol=1\n' > "$policy"
decision="$($SIMPLIFY enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id disabled --now 2027-02-14T12:35:00Z)"
has_line "$decision" 'STATUS=disabled' 'disabled repository policy was not silent'
has_line "$decision" 'ACTION=continue' 'disabled repository policy blocked review'
printf 'schema=2\nmode=required\nminimum-client=1\nprotocol=1\n' > "$policy"
if "$SIMPLIFY" enforce --repo "$FIXTURE" --base HEAD --head HEAD --run-id run-3 >/dev/null 2>&1; then
  fail 'aware client accepted an unsupported required policy schema'
fi

echo "assurance tests: OK"
