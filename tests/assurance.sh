#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSURANCE="$REPO_DIR/bin/pln-assurance"

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

echo "assurance tests: OK"
