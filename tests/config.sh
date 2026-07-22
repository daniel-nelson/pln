#!/usr/bin/env bash
# tests/config.sh — regression check for bin/pln-config.
#
# The read path carries more weight than a config reader usually does: a value
# may be a whole invocation (`peer_command: claude -p --model opus`), and a
# `get` that returned only the first token would silently run `claude` where the
# user asked for something else. So the property pinned here is that a value
# survives the round trip *as written* — spaces, flags and all — while the
# single-token booleans the rest of the suite reads keep reading identically.
#
# Everything runs against a scratch PLN_STATE_DIR, so the developer's own
# ~/.pln is never read and never written.
#
# Prints OK and exits 0 on success; any failed assertion aborts with a message.
#
# Run:  bash tests/config.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-config"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-config-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export PLN_STATE_DIR="$WORK/state"
CONFIG="$PLN_STATE_DIR/config.yaml"

eq() { # eq <got> <want> <description>
  [ "$1" = "$2" ] || fail "$3 — got '$1', wanted '$2'"
}

# --- a machine with no config at all is not an error -------------------------
# Every caller in the suite reads a key before anything has ever written one, so
# this is the common case, not the edge one.
eq "$("$BIN" get peer_command)" "" "a missing config file did not read as empty"
eq "$("$BIN" list)" "" "list on a missing config file printed something"
[ -e "$CONFIG" ] && fail "a read created the config file"

# --- a boolean survives the round trip byte-identical ------------------------
"$BIN" set notify_push false
eq "$("$BIN" get notify_push)" "false" "a boolean did not read back byte-identical"
"$BIN" set notify_push true
eq "$("$BIN" get notify_push)" "true" "an overwritten boolean did not read back"
eq "$(grep -c '^notify_push:' "$CONFIG")" "1" "set appended a second line instead of rewriting the first"

# --- a full command line survives whole --------------------------------------
CMD="codex exec --model gpt-5 -s read-only"
"$BIN" set peer_command "$CMD"
eq "$("$BIN" get peer_command)" "$CMD" "a value containing spaces was truncated"
eq "$("$BIN" get notify_push)" "true" "rewriting one key disturbed another"

# --- surrounding whitespace is trimmed, on both sides -------------------------
printf 'padded:    spaced value   \n' >> "$CONFIG"
eq "$("$BIN" get padded)" "spaced value" "surrounding whitespace was not trimmed"

# --- a value written with no space after the colon still reads ---------------
printf 'tight:value\n' >> "$CONFIG"
eq "$("$BIN" get tight)" "value" "a key written without a space after the colon read as empty"

# --- one key is never another key's prefix -----------------------------------
# `notify` and `notify_push` both ship, and `peer_command` / `peer_consent`
# share a prefix too: a read of the shorter name must not answer with the
# longer one's value.
eq "$("$BIN" get notify)" "" "an unset key answered with a longer key's value"
"$BIN" set notify false
eq "$("$BIN" get notify)" "false" "the shorter key did not read back its own value"
eq "$("$BIN" get notify_push)" "true" "setting the shorter key disturbed the longer one"

# --- a missing key is empty and successful, not an error ---------------------
rc=0; got="$("$BIN" get never_set_by_anyone)" || rc=$?
eq "$rc" "0" "reading a missing key exited non-zero"
eq "$got" "" "reading a missing key printed something"

# --- list shows what was written ---------------------------------------------
"$BIN" list | grep -q '^peer_command: codex exec --model gpt-5 -s read-only$' \
  || fail "list did not show the stored command line"

# --- usage errors -------------------------------------------------------------
guard() { # guard <description> <args...>
  local what="$1"; shift
  local rc=0
  "$BIN" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || fail "$what exited 0 (expected non-zero)"
}
guard "no subcommand at all"
guard "an unknown subcommand" frobnicate
guard "get with no key" get
guard "set with no key" set
guard "set with no value" set lonely
# An empty value is refused rather than clearing the key. Pinned deliberately:
# the consent flow only ever writes true/false, and anything that wants a key
# *un*answered has to remove the line, not blank it.
guard "set with an empty value" set peer_consent ""
eq "$("$BIN" get peer_command)" "$CMD" "a rejected write still altered the file"

echo "OK"
