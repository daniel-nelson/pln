#!/usr/bin/env bash
# tests/routing-rule.sh — regression check for bin/pln-routing-rule.
#
# Drives the helper through every RESULT state using the PLN_ROUTING_TARGET
# hook against throwaway temp dirs. Prints OK and exits 0 on success; any
# failed assertion aborts (set -e) with a message and a non-zero exit.
#
# Run:  bash tests/routing-rule.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-routing-rule"
MARKER="<!-- pln-pr-routing -->"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-routing-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Count how many times the marker line appears in a file.
marker_count() { grep -cF "$MARKER" "$1" 2>/dev/null || true; }

# --- --plan previews and writes nothing --------------------------------------
d="$WORK/plan"; mkdir -p "$d"
target="$d/CLAUDE.md"
printf 'existing content\n' > "$target"
before="$(cat "$target")"
out="$(PLN_ROUTING_TARGET="$target" "$BIN" --plan)"
grep -q 'RESULT: plan:add' <<<"$out" || fail "--plan did not report plan:add"
[ "$(cat "$target")" = "$before" ] || fail "--plan modified the target file"

# --- --apply adds the block and preserves prior content ----------------------
d="$WORK/apply"; mkdir -p "$d"
target="$d/CLAUDE.md"
printf 'prior line\n' > "$target"
out="$(PLN_ROUTING_TARGET="$target" "$BIN" --apply)"
grep -q 'RESULT: added' <<<"$out" || fail "--apply did not report added"
grep -qF "$MARKER" "$target" || fail "--apply did not write the marker"
grep -qF 'prior line' "$target" || fail "--apply clobbered prior content"
[ "$(marker_count "$target")" -eq 1 ] || fail "--apply wrote the block more than once"

# --- second --apply is idempotent (already-present, block appears once) ------
out="$(PLN_ROUTING_TARGET="$target" "$BIN" --apply)"
grep -q 'RESULT: already-present' <<<"$out" || fail "second --apply not already-present"
[ "$(marker_count "$target")" -eq 1 ] || fail "second --apply duplicated the block"

# --- --remove strips the block (idempotent) ----------------------------------
out="$(PLN_ROUTING_TARGET="$target" "$BIN" --remove)"
grep -q 'RESULT: removed' <<<"$out" || fail "--remove did not report removed"
grep -qF "$MARKER" "$target" && fail "--remove left the marker behind"
grep -qF 'prior line' "$target" || fail "--remove damaged prior content"
out="$(PLN_ROUTING_TARGET="$target" "$BIN" --remove)"
grep -q 'RESULT: not-present' <<<"$out" || fail "second --remove not not-present"

# --- missing parent dir → no-target, nothing created -------------------------
missing="$WORK/does-not-exist/CLAUDE.md"
out="$(PLN_ROUTING_TARGET="$missing" "$BIN" --plan)"
grep -q 'RESULT: no-target' <<<"$out" || fail "--plan on missing dir not no-target"
out="$(PLN_ROUTING_TARGET="$missing" "$BIN" --apply)"
grep -q 'RESULT: no-target' <<<"$out" || fail "--apply on missing dir not no-target"
[ -e "$missing" ] && fail "--apply created a file in a missing parent dir"
[ -d "$WORK/does-not-exist" ] && fail "--apply created the missing parent dir"

# --- unknown arg and bare invocation write nothing and exit non-zero ---------
d="$WORK/noop"; mkdir -p "$d"
target="$d/CLAUDE.md"
printf 'untouched\n' > "$target"
before="$(cat "$target")"
for arg in --help --bogus ""; do
  if PLN_ROUTING_TARGET="$target" "$BIN" $arg >/dev/null 2>&1; then
    fail "invocation with arg '$arg' exited zero (expected non-zero)"
  fi
  [ "$(cat "$target")" = "$before" ] || fail "invocation with arg '$arg' modified the target"
done

echo "OK"
