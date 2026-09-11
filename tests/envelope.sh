#!/usr/bin/env bash
# tests/envelope.sh — path, size and field guards for worker result envelopes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-read-envelope"
CONTRACT="$SCRIPT_DIR/../src/workers/context-envelope.md"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-envelope-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

expect_fail() { # expect_fail <description> <args...>
  local what="$1"
  shift
  local rc=0 output
  output="$($BIN "$@" 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] || fail "$what exited 0 (expected non-zero)"
  [ -n "$output" ] || fail "$what failed without an explanation"
}

PLAN_DIR="$WORK/plans/run"
RESULTS_DIR="$PLAN_DIR/results"
EVIDENCE_DIR="$PLAN_DIR/evidence"
OUTSIDE_DIR="$WORK/outside"
mkdir -p "$RESULTS_DIR" "$EVIDENCE_DIR" "$OUTSIDE_DIR"
printf 'detailed notes\n' > "$EVIDENCE_DIR/notes.md"

# The envelope shape has one owner. This test asks the contract which fields
# exist rather than restating them, so a field added there is covered here
# without anyone remembering to extend the loop below.
FIELDS="$(awk '
  state == 0 && /^```text$/ { state = 1; next }
  state == 1 && /^```$/ { state = 2; next }
  state == 1 && /^[A-Z][A-Z_]*:/ { sub(/:.*/, ""); print }
' "$CONTRACT")"
[ -n "$FIELDS" ] || fail "no envelope fields found in $CONTRACT"
echo "$FIELDS" | grep -qx STATUS \
  || fail "envelope field extraction missed STATUS in $CONTRACT"

STATUS_VALUE="complete"
EVIDENCE_VALUE="evidence/notes.md"

make_envelope() { # make_envelope <out-file> [field-to-omit]
  local out="$1" omit="${2:-}" field value
  : > "$out"
  for field in $FIELDS; do
    if [ "$field" != "$omit" ]; then
      case "$field" in
        STATUS) value="$STATUS_VALUE" ;;
        EVIDENCE_FILE) value="$EVIDENCE_VALUE" ;;
        *) value="filled" ;;
      esac
      printf '%s: %s\n' "$field" "$value" >> "$out"
    fi
  done
}

# A complete envelope is printed byte-for-byte.
make_envelope "$RESULTS_DIR/valid.txt"
got="$($BIN --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/valid.txt")"
[ "$got" = "$(cat "$RESULTS_DIR/valid.txt")" ] \
  || fail "a valid result was not printed unchanged"

# The maximum is inclusive: a file exactly on the byte boundary succeeds, and
# one byte less of budget refuses it before content reaches stdout.
VALID_BYTES="$(LC_ALL=C wc -c < "$RESULTS_DIR/valid.txt")"
VALID_BYTES="${VALID_BYTES//[[:space:]]/}"
$BIN --root "$PLAN_DIR" --max-bytes "$VALID_BYTES" "$RESULTS_DIR/valid.txt" >/dev/null \
  || fail "an exact-boundary result was rejected"
expect_fail "an oversized result" \
  --root "$PLAN_DIR" --max-bytes "$((VALID_BYTES - 1))" "$RESULTS_DIR/valid.txt"

expect_fail "a missing result" \
  --root "$PLAN_DIR" --max-bytes 8 "$RESULTS_DIR/missing.txt"

# A regular file named directly outside the plan directory is never readable.
printf 'outside' > "$OUTSIDE_DIR/result.txt"
expect_fail "an outside-root result" \
  --root "$PLAN_DIR" --max-bytes 100 "$OUTSIDE_DIR/result.txt"

# Reject a final-component symlink even if its target is a regular file, so a
# worker cannot redirect the read after the coordinator validates its path.
ln -s "$OUTSIDE_DIR/result.txt" "$RESULTS_DIR/escape.txt"
expect_fail "a symlink escape" \
  --root "$PLAN_DIR" --max-bytes 100 "$RESULTS_DIR/escape.txt"

# Resolving the containing directory also catches a path that looks in-root but
# traverses an in-root directory symlink to reach an outside regular file.
ln -s "$OUTSIDE_DIR" "$PLAN_DIR/escape-dir"
expect_fail "a parent-directory symlink escape" \
  --root "$PLAN_DIR" --max-bytes 100 "$PLAN_DIR/escape-dir/result.txt"

# A result that satisfies every path and size rule and says nothing is what the
# firewall used to accept. Field validation is on by default, so it refuses.
printf 'ok' > "$RESULTS_DIR/bare.txt"
expect_fail "a contentless result" \
  --root "$PLAN_DIR" --max-bytes 100 "$RESULTS_DIR/bare.txt"

# Each contract field is required: dropping any one of them refuses.
for field in $FIELDS; do
  make_envelope "$RESULTS_DIR/omit.txt" "$field"
  expect_fail "an envelope missing $field" \
    --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/omit.txt"
done

# A label with nothing after it is a missing field, whether the contract writes
# that field's value inline or as the block beneath it.
make_envelope "$RESULTS_DIR/valid.txt"
sed 's/^SCOPE: .*/SCOPE:/' "$RESULTS_DIR/valid.txt" > "$RESULTS_DIR/empty-inline.txt"
expect_fail "an envelope with an empty inline field" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/empty-inline.txt"
awk '/^SUMMARY: /{ print "SUMMARY:"; print ""; next } { print }' \
  "$RESULTS_DIR/valid.txt" > "$RESULTS_DIR/empty-block.txt"
expect_fail "an envelope with an empty block field" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/empty-block.txt"

# A filled block field is accepted on the line below its label.
awk '/^SUMMARY: /{ print "SUMMARY:"; print "filled"; next } { print }' \
  "$RESULTS_DIR/valid.txt" > "$RESULTS_DIR/block.txt"
$BIN --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/block.txt" >/dev/null \
  || fail "a block-shaped field value was rejected"

# STATUS has a closed vocabulary; the coordinator's fail-closed behavior keys
# on it, so a third value is malformed rather than a new outcome.
for bad in done ok blocked-ish; do
  STATUS_VALUE="$bad"
  make_envelope "$RESULTS_DIR/status.txt"
  expect_fail "an envelope with STATUS $bad" \
    --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/status.txt"
done
for good in complete blocked; do
  STATUS_VALUE="$good"
  make_envelope "$RESULTS_DIR/status.txt"
  $BIN --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/status.txt" >/dev/null \
    || fail "an envelope with STATUS $good was rejected"
done
STATUS_VALUE="complete"

# The declared evidence file gets the confinement the result file already has:
# the envelope body is worker-authored, and later phases hand that path to
# another worker to read.
EVIDENCE_VALUE="evidence/absent.md"
make_envelope "$RESULTS_DIR/ev-absent.txt"
expect_fail "an envelope naming a missing evidence file" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-absent.txt"

printf 'outside notes\n' > "$OUTSIDE_DIR/notes.md"
EVIDENCE_VALUE="../../outside/notes.md"
make_envelope "$RESULTS_DIR/ev-outside.txt"
expect_fail "an envelope naming an out-of-root evidence file" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-outside.txt"

EVIDENCE_VALUE="$OUTSIDE_DIR/notes.md"
make_envelope "$RESULTS_DIR/ev-absolute.txt"
expect_fail "an envelope naming an out-of-root absolute evidence file" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-absolute.txt"

ln -s "$OUTSIDE_DIR/notes.md" "$EVIDENCE_DIR/link.md"
EVIDENCE_VALUE="evidence/link.md"
make_envelope "$RESULTS_DIR/ev-symlink.txt"
expect_fail "an envelope naming a symlinked evidence file" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-symlink.txt"

# An evidence path inside an in-root directory symlink that leaves the root is
# refused the same way the result path's parent traversal is.
EVIDENCE_VALUE="escape-dir/notes.md"
make_envelope "$RESULTS_DIR/ev-escape-dir.txt"
expect_fail "an envelope whose evidence path traverses a directory symlink" \
  --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-escape-dir.txt"
EVIDENCE_VALUE="evidence/notes.md"

# The escape exists for one case: re-reading a result an earlier attempt
# already validated, whose evidence file may have gone with a reaped
# temporary directory. It drops the field and evidence checks, and nothing
# else — path, symlink and size rules still refuse.
$BIN --no-require-fields --root "$PLAN_DIR" --max-bytes 100 "$RESULTS_DIR/bare.txt" >/dev/null \
  || fail "--no-require-fields rejected a previously validated result"
EVIDENCE_VALUE="evidence/absent.md"
make_envelope "$RESULTS_DIR/ev-reaped.txt"
$BIN --no-require-fields --root "$PLAN_DIR" --max-bytes 4096 "$RESULTS_DIR/ev-reaped.txt" >/dev/null \
  || fail "--no-require-fields rejected a result whose evidence file was reaped"
EVIDENCE_VALUE="evidence/notes.md"
expect_fail "a symlink escape under --no-require-fields" \
  --no-require-fields --root "$PLAN_DIR" --max-bytes 100 "$RESULTS_DIR/escape.txt"
expect_fail "an oversized result under --no-require-fields" \
  --no-require-fields --root "$PLAN_DIR" --max-bytes 1 "$RESULTS_DIR/valid.txt"

echo "OK"
