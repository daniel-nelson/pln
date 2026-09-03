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

# ─── a forced check resolves the ref instead of trusting a mutable CDN path ──
# `raw.githubusercontent.com/<owner>/<repo>/main/VERSION` means a different file
# after every merge and is served with `max-age=300`, so a check seconds after a
# release can answer with the previous version — observed 21 seconds after a
# merge, and not fixed by asking the edge nicely. A forced check resolves the ref
# with `git ls-remote` (not edge-cached) and reads the immutable sha path.
#
# Driven through a fake `git` on `PATH`, never the network.
FAKEBIN="$WORK/fakebin"; mkdir -p "$FAKEBIN"
fake_git() { # fake_git <stdout> [exit]
  cat > "$FAKEBIN/git" <<EOF
#!/usr/bin/env bash
printf '%s' "$1"
exit ${2:-0}
EOF
  chmod +x "$FAKEBIN/git"
}

# The override the other cases use is a file:// URL, which is not the raw host,
# so the resolving path must leave it alone rather than mangling it.
fake_git 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef	refs/heads/main'
clear_state; set_local 1.55.0; set_remote 1.56.0
OUT="$(PATH="$FAKEBIN:$PATH" PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
       PLN_REMOTE_URL="file://$REMOTE_FILE" "$INSTALL/bin/pln-update-check" --force 2>&1)"
said 'UPGRADE_AVAILABLE 1.55.0 1.56.0' \
  "a non-raw remote was not left alone by the ref-resolving path"

# A `git` that fails resolves nothing, and the check still answers from the
# plain URL rather than reporting a false up-to-date.
fake_git '' 1
clear_state; set_local 1.55.0; set_remote 1.56.0
OUT="$(PATH="$FAKEBIN:$PATH" PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
       PLN_REMOTE_URL="file://$REMOTE_FILE" "$INSTALL/bin/pln-update-check" --force 2>&1)"
said 'UPGRADE_AVAILABLE 1.55.0 1.56.0' "a failed ls-remote lost the upgrade"

# Source properties the fake cannot reach: the resolving path is anchored to the
# raw host, it asks git for the ref rather than guessing, and a pinned URL that
# returns nothing falls back to the plain one instead of standing as a verdict.
grep -q "RAW_HOST_PREFIX='https://raw.githubusercontent.com/'" "$ROOT/bin/pln-update-check" \
  || fail "the ref-resolving path is no longer anchored to the raw host"
grep -q 'git ls-remote' "$ROOT/bin/pln-update-check" \
  || fail "a forced check no longer resolves the ref before fetching"
grep -q 'FETCH_URL" != "\$REMOTE_URL' "$ROOT/bin/pln-update-check" \
  || fail "an empty pinned fetch no longer falls back to the plain URL"
grep -q 'FORCE_CHECK" = "true" \] && command -v git' "$ROOT/bin/pln-update-check" \
  || fail "the passive check now pays for a ref resolution it does not need"

[ "$FAILED" -eq 0 ] && echo OK
exit "$FAILED"
