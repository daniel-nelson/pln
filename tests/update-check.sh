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
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

FAILED=0
fail() { printf 'FAIL: %s\n' "$1"; FAILED=1; }
said() { case "$OUT" in *"$1"*) ;; *) fail "$2"$'\n'"  output was: $OUT" ;; esac; }
didnt_say() { case "$OUT" in *"$1"*) fail "$2"$'\n'"  output was: $OUT" ;; *) ;; esac; }

STATE="$WORK/state"
INSTALL="$WORK/install"
mkdir -p "$STATE" "$INSTALL/bin"
cp "$ROOT/bin/pln-update-check" "$INSTALL/bin/"
cp "$ROOT/bin/pln-config" "$INSTALL/bin/"
REMOTE_FILE="$WORK/remote-version"

check() { # check [--force]
  OUT="$(PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
         PLN_REMOTE_URL="file://$REMOTE_FILE" \
         "$INSTALL/bin/pln-update-check" ${1:+"$1"} 2>&1)"
}
set_local()  { printf '%s\n' "$1" > "$INSTALL/VERSION"; }
set_remote() { printf '%s\n' "$1" > "$REMOTE_FILE"; }
set_marker() { printf '%s\n' "$1" > "$STATE/just-upgraded-from"; }
clear_state() {
  rm -f "$STATE/just-upgraded-from" "$STATE/last-update-check" "$STATE/update-snoozed" "$STATE/config.yaml"
  rm -rf "$STATE/update-receipts"
}

receipt_start() { # receipt_start <run-id>
  OUT="$(PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
         PLN_REMOTE_URL="file://$REMOTE_FILE" \
         "$INSTALL/bin/pln-update-check" --start "$1" 2>&1)"
  CHALLENGE="$(printf '%s\n' "$OUT" | awk '/^UPDATE_RECEIPT_READY / { print $2; exit }')"
}

receipt_consume() { # receipt_consume <run-id> <challenge>
  OUT="$(PLN_SKILL_DIR="$INSTALL" PLN_STATE_DIR="$STATE" \
         "$INSTALL/bin/pln-update-check" --consume "$1" "$2" 2>&1)"
  CONSUME_STATUS=$?
}

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

# ─── receipt mode has a closed, truthful verdict set ─────────────────────────
# Machine output is always explicit. The router keeps CURRENT results silent to
# the user and relays only the existing upgrade news lines.
clear_state; set_local 1.54.0; set_remote 1.54.0
receipt_start '/repo/plans/run-a/PLAN.md'
said ' VERIFIED_CURRENT verified' "a remote-verified current check has no truthful receipt verdict"
[ -n "$CHALLENGE" ] || fail "a verified current check returned no receipt challenge"
receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "a verified current receipt was refused"
said 'UPDATE_RECEIPT_CONSUMED VERIFIED_CURRENT verified' "the verified current receipt lost its freshness source"

# The second check is answered by the still-valid current cache, but mints a
# fresh generation rather than replaying the first receipt.
receipt_start '/repo/plans/run-a/PLAN.md'
said ' CACHED_CURRENT cached' "a cached current check was not distinguished from a remote verification"
receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "a cached-current receipt was refused"

clear_state; set_local 1.53.0; set_remote 1.54.0
receipt_start '/repo/plans/run-a/PLAN.md'
said ' UPGRADE_AVAILABLE verified' "an available upgrade has no closed receipt verdict"
said 'UPGRADE_AVAILABLE 1.53.0 1.54.0' "receipt mode dropped the existing upgrade news"
receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "the explicit upgrade-available outcome blocked recovery"

clear_state; set_local 1.54.0; set_remote 1.54.0; set_marker '1.53.0'
receipt_start '/repo/plans/run-a/PLAN.md'
said ' JUST_UPGRADED upgrade-event' "a just-upgraded marker has no distinct receipt verdict"
said 'JUST_UPGRADED 1.53.0 1.54.0' "receipt mode dropped the existing just-upgraded news"
receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "the explicit just-upgraded outcome blocked recovery"

clear_state; set_local 1.54.0; set_remote 1.54.0
printf 'update_check: false\n' > "$STATE/config.yaml"
receipt_start '/repo/plans/run-a/PLAN.md'
said ' DISABLED none' "configured-disabled was not an explicit degraded outcome"
receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "the explicit configured-disabled outcome blocked recovery"
said 'UPDATE_RECEIPT_CONSUMED DISABLED none' "configured-disabled falsely claimed freshness"

# Empty and invalid remote bytes are indeterminate, never current. Neither may
# mint an UP_TO_DATE cache entry, but the explicit degraded receipt remains
# consumable so a network outage does not block the universal workflow.
for invalid in empty html; do
  clear_state; set_local 1.54.0
  case "$invalid" in
    empty) : > "$REMOTE_FILE" ;;
    html) printf '<html>no version</html>\n' > "$REMOTE_FILE" ;;
  esac
  receipt_start '/repo/plans/run-a/PLAN.md'
  said ' UNAVAILABLE none' "$invalid remote data was not an explicit indeterminate outcome"
  case "$(cat "$STATE/last-update-check" 2>/dev/null)" in
    UP_TO_DATE*) fail "$invalid remote data minted a current cache verdict" ;;
  esac
  receipt_consume '/repo/plans/run-a/PLAN.md' "$CHALLENGE"
  [ "$CONSUME_STATUS" -eq 0 ] || fail "$invalid remote's explicit degraded receipt blocked recovery"
  said 'UPDATE_RECEIPT_CONSUMED UNAVAILABLE none' "$invalid remote falsely claimed freshness"
done

# A cache written by an older checker carries no proof marker. It must be
# revalidated, not promoted into a CACHED_CURRENT receipt.
clear_state; set_local 1.54.0; : > "$REMOTE_FILE"
printf 'UP_TO_DATE 1.54.0\n' > "$STATE/last-update-check"
receipt_start '/repo/plans/run-a/PLAN.md'
said ' UNAVAILABLE none' "an unproved legacy current cache minted a current receipt"
didnt_say ' CACHED_CURRENT cached' "an unproved legacy current cache was trusted"

# ─── receipts are run-bound, generation-bound, and one-time ──────────────────
# A legacy run has no prior receipt state; its first recovery creates and
# consumes generation one normally.
clear_state; set_local 1.54.0; set_remote 1.54.0
receipt_start '/repo/plans/legacy/PLAN.md'
LEGACY_CHALLENGE="$CHALLENGE"
receipt_consume '/repo/plans/legacy/PLAN.md' "$LEGACY_CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "the first recovery of a legacy run was refused"

# A successful consume spends the receipt. Same-run replay and a second
# recovery that skipped a fresh check both fail.
receipt_consume '/repo/plans/legacy/PLAN.md' "$LEGACY_CHALLENGE"
[ "$CONSUME_STATUS" -ne 0 ] || fail "a spent receipt was replayed in the same run"
receipt_consume '/repo/plans/legacy/PLAN.md' "$LEGACY_CHALLENGE"
[ "$CONSUME_STATUS" -ne 0 ] || fail "a second recovery proceeded without a new update check"

# A post-compaction start replaces the generation. The old challenge—including
# unconsumed crash residue—cannot satisfy the new recovery.
clear_state; set_local 1.54.0; set_remote 1.54.0
receipt_start '/repo/plans/run-a/PLAN.md'; OLD_CHALLENGE="$CHALLENGE"
receipt_start '/repo/plans/run-a/PLAN.md'; NEW_CHALLENGE="$CHALLENGE"
[ "$OLD_CHALLENGE" != "$NEW_CHALLENGE" ] || fail "a new recovery reused the prior challenge"
receipt_consume '/repo/plans/run-a/PLAN.md' "$OLD_CHALLENGE"
[ "$CONSUME_STATUS" -ne 0 ] || fail "unconsumed crash residue satisfied the next recovery"
receipt_consume '/repo/plans/run-a/PLAN.md' "$NEW_CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "the replacement post-compaction receipt was refused"

# Wrong-run and wrong-challenge attempts fail without spending the valid
# receipt; a fabricated challenge models a checker invocation that was skipped.
receipt_start '/repo/plans/run-a/PLAN.md'; VALID_CHALLENGE="$CHALLENGE"
receipt_consume '/repo/plans/run-b/PLAN.md' "$VALID_CHALLENGE"
[ "$CONSUME_STATUS" -ne 0 ] || fail "a receipt was accepted for the wrong durable run"
receipt_consume '/repo/plans/run-a/PLAN.md' 'g999999'
[ "$CONSUME_STATUS" -ne 0 ] || fail "a wrong or fabricated challenge was accepted"
receipt_consume '/repo/plans/run-a/PLAN.md' "$VALID_CHALLENGE"
[ "$CONSUME_STATUS" -eq 0 ] || fail "a wrong-run/challenge attempt spent the valid receipt"

# ─── receipts live in a per-user temp dir a sandboxed run can write ──────────
# Codex's workspace-write sandbox grants the workspace and the temp dirs, never
# `~/.pln`, so a receipt kept there made every sandboxed `--start` exit 4 before
# it reached the remote. With no `PLN_STATE_DIR` override the receipts move to
# `$TMPDIR/pln-update-receipts-<uid>`; cache, marker and config stay put.
#
# Shared `/tmp` is why the directory is checked before use: a symlink planted
# at that name, another user's directory, or one anyone else can write would
# let another local user forge a `VERIFIED_CURRENT` receipt. Each is refused
# with the same exit 4 as any other receipt-state failure.
UID_NOW="$(id -u)"
THOME="$WORK/home"
TTMP="$WORK/tmp"
tmp_env() { # tmp_env <cmd args...> — no PLN_STATE_DIR, scratch HOME and TMPDIR
  env -u PLN_STATE_DIR HOME="$THOME" TMPDIR="$TTMP/" PATH="${TPATH:-$PATH}" \
    PLN_SKILL_DIR="$INSTALL" PLN_REMOTE_URL="file://$REMOTE_FILE" "$@"
}
tmp_start() { # tmp_start <run-id>
  OUT="$(tmp_env "$INSTALL/bin/pln-update-check" --start "$1" 2>&1)"
  START_STATUS=$?
  CHALLENGE="$(printf '%s\n' "$OUT" | awk '/^UPDATE_RECEIPT_READY / { print $2; exit }')"
}
tmp_consume() { # tmp_consume <run-id> <challenge>
  OUT="$(tmp_env "$INSTALL/bin/pln-update-check" --consume "$1" "$2" 2>&1)"
  CONSUME_STATUS=$?
}
tmp_reset() {
  [ -d "$THOME" ] && chmod -R u+w "$THOME" 2>/dev/null
  [ -d "$TTMP" ] && chmod -R u+w "$TTMP" 2>/dev/null
  rm -rf "$THOME" "$TTMP"
  mkdir -p "$THOME/.pln" "$TTMP"
}
TRDIR="$TTMP/pln-update-receipts-$UID_NOW"
set_local 1.53.0; set_remote 1.54.0

# A read-only `~/.pln` no longer stops the receipt round trip. Skipped for
# root, which a mode bit never refuses.
if [ "$UID_NOW" != "0" ]; then
  tmp_reset; chmod a-w "$THOME/.pln"
  tmp_start '/repo/plans/sandboxed/PLAN.md'
  [ "$START_STATUS" -eq 0 ] || fail "--start with a read-only ~/.pln exited $START_STATUS"
  said ' UPGRADE_AVAILABLE verified' "--start with a read-only ~/.pln lost the real verdict"
  tmp_consume '/repo/plans/sandboxed/PLAN.md' "$CHALLENGE"
  [ "$CONSUME_STATUS" -eq 0 ] || fail "--consume with a read-only ~/.pln exited $CONSUME_STATUS"
  said 'UPDATE_RECEIPT_CONSUMED UPGRADE_AVAILABLE verified' \
    "--consume with a read-only ~/.pln lost the real verdict"
  [ -d "$TRDIR" ] && [ ! -L "$TRDIR" ] || fail "the receipt did not land under \$TMPDIR/pln-update-receipts-<uid>"
  case "$(ls -ld "$TRDIR" 2>/dev/null)" in
    d???------*) ;;
    *) fail "the temp receipt dir was created open to others: $(ls -ld "$TRDIR" 2>/dev/null)" ;;
  esac
  [ -e "$THOME/.pln/update-receipts" ] && fail "a receipt was still written under ~/.pln"
  chmod u+w "$THOME/.pln"
fi

# A symlink at the receipt path is refused, whoever owns its target.
tmp_reset; mkdir -m 700 "$WORK/tmp-target"; ln -s "$WORK/tmp-target" "$TRDIR"
tmp_start '/repo/plans/linked/PLAN.md'
[ "$START_STATUS" -eq 4 ] || fail "a symlink to a user-owned dir was used as the receipt dir (exit $START_STATUS)"
[ -z "$(ls -A "$WORK/tmp-target")" ] || fail "--start wrote through a symlinked receipt dir"
rm -rf "$WORK/tmp-target"

tmp_reset; ln -s / "$TRDIR"
tmp_start '/repo/plans/linked/PLAN.md'
[ "$START_STATUS" -eq 4 ] || fail "a symlink to a root-owned dir was used as the receipt dir (exit $START_STATUS)"

# A directory of ours that group or other can write into is refused, not
# repaired: anything planted before this run would already be inside it.
tmp_reset; mkdir "$TRDIR"; chmod 775 "$TRDIR"
tmp_start '/repo/plans/open/PLAN.md'
[ "$START_STATUS" -eq 4 ] || fail "a group/other-accessible receipt dir was used (exit $START_STATUS)"
[ -z "$(ls -A "$TRDIR")" ] || fail "--start wrote into a group/other-accessible receipt dir"

# Another user's directory. A non-root test cannot create one, so a fake `id`
# on PATH names a different uid: the directory named for that uid then exists
# and is owned by someone else — the real user — which is the refused case.
OTHER_UID=$((UID_NOW + 1))
REAL_ID="$(command -v id)"
FAKEID="$WORK/fakeid"; mkdir -p "$FAKEID"
cat > "$FAKEID/id" <<EOF
#!/bin/sh
[ "\$1" = "-u" ] && { echo $OTHER_UID; exit 0; }
exec "$REAL_ID" "\$@"
EOF
chmod +x "$FAKEID/id"
tmp_reset; mkdir -m 700 "$TTMP/pln-update-receipts-$OTHER_UID"
TPATH="$FAKEID:$PATH" tmp_start '/repo/plans/foreign/PLAN.md'
[ "$START_STATUS" -eq 4 ] || fail "another user's receipt dir was used (exit $START_STATUS)"
[ -z "$(ls -A "$TTMP/pln-update-receipts-$OTHER_UID")" ] || fail "--start wrote into another user's receipt dir"

# The PLN_STATE_DIR override still keeps receipts under it, which is what
# isolates every other case in this file.
clear_state
receipt_start '/repo/plans/override/PLAN.md'
[ -d "$STATE/update-receipts" ] || fail "PLN_STATE_DIR no longer relocates the receipts"
tmp_reset

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
