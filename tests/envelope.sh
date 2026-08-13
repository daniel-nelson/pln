#!/usr/bin/env bash
# tests/envelope.sh — path and size guards for worker result envelopes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-read-envelope"

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
OUTSIDE_DIR="$WORK/outside"
mkdir -p "$RESULTS_DIR" "$OUTSIDE_DIR"

# A normal in-root result is printed byte-for-byte.
printf 'valid envelope' > "$RESULTS_DIR/valid.txt"
got="$($BIN --root "$PLAN_DIR" --max-bytes 100 "$RESULTS_DIR/valid.txt")"
[ "$got" = 'valid envelope' ] || fail "a valid result was not printed unchanged"

# The maximum is inclusive: a file exactly on the byte boundary succeeds.
printf '12345678' > "$RESULTS_DIR/boundary.txt"
got="$($BIN --root "$PLAN_DIR" --max-bytes 8 "$RESULTS_DIR/boundary.txt")"
[ "$got" = '12345678' ] || fail "an exact-boundary result was rejected"

# One byte beyond the ceiling is rejected before content reaches stdout.
printf '123456789' > "$RESULTS_DIR/oversize.txt"
expect_fail "an oversized result" \
  --root "$PLAN_DIR" --max-bytes 8 "$RESULTS_DIR/oversize.txt"

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

echo "OK"
