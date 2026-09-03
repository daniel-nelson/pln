#!/usr/bin/env bash
# tests/update-check.sh — bin/pln-update-check and the marker bin/pln-update-apply
# writes for it.
#
# The property under test is that an explicitly requested check actually asks:
# a marker records an upgrade that already happened, and answering a forced
# check out of that file means an explicit update immediately after an
# automatic one never contacts the remote at all. It reported the earlier
# upgrade, wrote an hour of `UP_TO_DATE` into the cache, and looked like it had
# succeeded — observed twice in one afternoon across two hosts.
#
# No network: the remote is a `file://` URL over a scratch file, which is also
# why the forced fetch's cache-buster is built only for http(s).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
fail() { printf 'FAIL: %s\n' "$1"; FAILED=1; }
said() { case "$OUT" in *"$1"*) ;; *) fail "$2"$'\n'"  output was: $OUT" ;; esac; }
didnt_say() { case "$OUT" in *"$1"*) fail "$2"$'\n'"  output was: $OUT" ;; *) ;; esac; }

STATE="$WORK/state"
INSTALL="$WORK/install"
mkdir -p "$STATE" "$INSTALL/bin"
cp "$ROOT/bin/pln-update-check" "$INSTALL/bin/"
REMOTE_FILE="$WORK/remote-version"

check() { # check [--force]
  OUT="$(PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
         PLN_REMOTE_URL="file://$REMOTE_FILE" \
         "$INSTALL/bin/pln-update-check" ${1:+"$1"} 2>&1)"
}
set_local()  { printf '%s\n' "$1" > "$INSTALL/VERSION"; }
set_remote() { printf '%s\n' "$1" > "$REMOTE_FILE"; }
set_marker() { printf '%s\n' "$1" > "$STATE/just-upgraded-from"; }
clear_state() { rm -f "$STATE/just-upgraded-from" "$STATE/last-update-check" "$STATE/update-snoozed"; }

# ─── a passive check is still answered by the marker alone ───────────────────
# This half is unchanged and deliberate: the preamble runs on every invocation
# and must not pay for a fetch to say what it already knows.
clear_state; set_local 1.53.0; set_remote 1.54.0; set_marker '1.52.0'
check
said 'JUST_UPGRADED 1.52.0 1.53.0' "a passive check did not report the marker"
didnt_say 'UPGRADE_AVAILABLE' "a passive check fetched past the marker"
[ -f "$STATE/just-upgraded-from" ] && fail "the marker was not consumed by a passive check"

# ─── a forced check reports the marker AND asks the remote ───────────────────
clear_state; set_local 1.53.0; set_remote 1.54.0; set_marker '1.52.0'
check --force
said 'JUST_UPGRADED 1.52.0 1.53.0' "a forced check dropped the marker news"
said 'UPGRADE_AVAILABLE 1.53.0 1.54.0' \
  "a forced check was answered by the marker and never reached the remote"
[ -f "$STATE/just-upgraded-from" ] && fail "the marker was not consumed by a forced check"

# The cache a marker leaves behind must not silence the next hour either.
case "$(cat "$STATE/last-update-check" 2>/dev/null)" in
  UPGRADE_AVAILABLE*) ;;
  *) fail "a forced check past a marker cached the wrong verdict: $(cat "$STATE/last-update-check" 2>/dev/null)" ;;
esac

# ─── forced, marker present, nothing newer: the marker is the whole news ─────
clear_state; set_local 1.54.0; set_remote 1.54.0; set_marker '1.53.0'
check --force
said 'JUST_UPGRADED 1.53.0 1.54.0' "a forced up-to-date check dropped the marker news"
didnt_say 'UPGRADE_AVAILABLE' "an up-to-date forced check invented an upgrade"

# ─── the marker names the install that wrote it ──────────────────────────────
# One file is shared by every install, so without this whichever host reads it
# first reports another install's upgrade as its own.
clear_state; set_local 1.54.0; set_remote 1.54.0; set_marker '1.53.0 ~/.claude/skills/pln'
check --force
said 'upgraded by ~/.claude/skills/pln' "the marker's writer was not reported"
said 'JUST_UPGRADED 1.53.0 1.54.0' "naming the writer lost the version news"

# A marker from before the field existed carries no writer and invents none.
clear_state; set_local 1.54.0; set_remote 1.54.0; set_marker '1.53.0'
check --force
said 'JUST_UPGRADED 1.53.0 1.54.0' "a writerless marker stopped reporting"
didnt_say 'upgraded by' "a writerless marker was given a writer"

# ─── no marker: the ordinary paths still work ────────────────────────────────
clear_state; set_local 1.53.0; set_remote 1.54.0
check --force
said 'UPGRADE_AVAILABLE 1.53.0 1.54.0' "a forced check with no marker lost the upgrade"
didnt_say 'JUST_UPGRADED' "a check with no marker reported one"

clear_state; set_local 1.54.0; set_remote 1.54.0
check --force
didnt_say 'UPGRADE_AVAILABLE' "an up-to-date check reported an upgrade"
didnt_say 'JUST_UPGRADED' "an up-to-date check reported a marker"

# ─── the writer field is what pln-update-apply actually writes ───────────────
# Pinned as a shape rather than a value: first field the version, the rest free
# text for a human, on one line.
grep -q "printf '%s %s\\\\n' \"\$OLDMIN\" \"\$UPDIRS\" > \"\$STATE_DIR/just-upgraded-from\"" \
  "$ROOT/bin/pln-update-apply" \
  || fail "pln-update-apply no longer writes the version and the upgraded installs into the marker"
grep -q 'UPDIRS=""' "$ROOT/bin/pln-update-apply" \
  || fail "UPDIRS is unset before the loop, which aborts pln-update-apply under set -u"

# ─── the cache-buster is built only for an http(s) remote ────────────────────
# A `file://` override has no edge cache and no query string, so appending one
# would break every test above — and the failure would be a silent fall back to
# "assume up to date".
grep -q 'http://\*|https://\*) HTTP_REMOTE=true' "$ROOT/bin/pln-update-check" \
  || fail "pln-update-check no longer restricts the forced-fetch cache-buster to http(s)"
grep -q 'pln_nocache=' "$ROOT/bin/pln-update-check" \
  || fail "pln-update-check no longer varies the forced-fetch URL past the CDN cache"

[ "$FAILED" -eq 0 ] && echo OK
exit "$FAILED"
