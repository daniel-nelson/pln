#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSURANCE="$REPO_DIR/bin/pln-assurance"
SIMPLIFY="$REPO_DIR/bin/pln-simplify"

fail() { echo "FAIL: $*" >&2; exit 1; }
has_line() { printf '%s\n' "$1" | grep -Fqx "$2" || fail "$3"; }

[ -x "$ASSURANCE" ] || fail "missing executable assurance helper: $ASSURANCE"

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
trap 'rm -rf "$FIXTURE"' EXIT
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
