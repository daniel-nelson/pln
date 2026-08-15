#!/usr/bin/env bash
# tests/setup.sh — regression check for the one-time peer/cross-model nudge
# `setup` prints at the end of its run.
#
# `setup` resolves its helpers by full path (`"$SKILL_DIR/bin/pln-peer"`,
# `"$SKILL_DIR/bin/pln-config"`), not by bare command name, so the
# "prepend a fake dir to PATH" trick the rest of the suite uses would never be
# reached — a bare `pln-peer`/`pln-config` is never invoked. Instead this test
# builds a throwaway install directory shaped like a real one (`setup`,
# `bin/pln-host`, `bin/pln-generate`, `bin/pln-config` — real copies, since
# none of them shells out to an agent CLI or reads the developer's own
# `~/.pln` once PLN_STATE_DIR/PLN_HOST are overridden — plus fake peer and
# route helpers, since their exit codes and STATUS fields are what these
# branches inspect) and runs the real `setup` script against it,
# with PATH trimmed to a base so a bare command would fail loudly rather than
# quietly finding something real.
#
# What it pins down, from the matrix in PLAN.md's item 1:
#   - ready (rung 1 or 2, STATUS=ready, exit 0) — no tip, flag set
#   - consent pending (exit 5, STATUS=consent) — no tip, flag set
#   - declined (exit 3, STATUS=declined) — no tip, flag set
#   - nothing usable (exit 3, RUNG=3, STATUS=none) — the tip, flag left unset
#     so it resurfaces on the next `setup` run
#   - the tip names the other host's CLI (codex on a Claude install, claude on
#     a Codex install)
#   - once the flag is already true, pln-peer is never even invoked
#
# Prints OK and exits 0 on success; any failed assertion aborts with a message.
#
# Run:  bash tests/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-setup-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# Normalized the same way `setup` normalizes its own SKILL_DIR (`cd && pwd`),
# so a later exact-path grep against setup's printed tip isn't defeated by a
# TMPDIR that already ends in a slash (which would otherwise leave a lone `//`
# in $WORK that `cd`/`pwd` silently collapses away inside setup but not here).
WORK="$(cd "$WORK" && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

BASE_PATH="/usr/bin:/bin"

# ─── a throwaway install directory ────────────────────────────────────────────
# Mirrors what a real clone's setup sees: itself, plus a bin/ with pln-host and
# pln-config as real copies (neither shells out to an agent CLI, and both are
# driven here through PLN_HOST/PLN_STATE_DIR so the developer's own machine and
# ~/.pln are never touched), pln-generate faked to a no-op (its own behavior is
# tests/generate.sh's job, not this branch's), and pln-peer faked so each
# scenario below can dictate its exit code and STATUS directly.
SKILL="$WORK/skill"
mkdir -p "$SKILL/bin"
cp "$REPO_DIR/setup" "$SKILL/setup"
cp "$REPO_DIR/bin/pln-host" "$SKILL/bin/pln-host"
cp "$REPO_DIR/bin/pln-config" "$SKILL/bin/pln-config"
chmod +x "$SKILL/setup" "$SKILL/bin/pln-host" "$SKILL/bin/pln-config"

cat > "$SKILL/bin/pln-generate" <<'FAKE_GENERATE'
#!/usr/bin/env bash
# setup's build step is exercised by tests/generate.sh; this branch only cares
# that setup reaches its trailing nudge block, so this is a silent no-op.
exit 0
FAKE_GENERATE
chmod +x "$SKILL/bin/pln-generate"

cat > "$SKILL/bin/pln-peer" <<'FAKE_PEER'
#!/usr/bin/env bash
# A fake --which: prints the eight-line contract and exits per scenario, so the
# test controls exactly what setup's nudge branch sees.
printf '%s\n' "$*" >> "${FAKE_PEER_LOG:-/dev/null}"
case "${FAKE_PEER_SCENARIO:?FAKE_PEER_SCENARIO not set}" in
  ready)
    printf 'RUNG=1\nPEER=fakepeer\nSTATUS=ready\nRESULT_FILE=\nLOG_FILE=\nACTUAL_PROFILE=judgment\nACTUAL_MODEL=unreported\nACTUAL_EFFORT=unreported\n'
    exit 0 ;;
  consent)
    printf 'RUNG=2\nPEER=claude\nSTATUS=consent\nRESULT_FILE=\nLOG_FILE=\nACTUAL_PROFILE=judgment\nACTUAL_MODEL=unreported\nACTUAL_EFFORT=unreported\n'
    exit 5 ;;
  declined)
    printf 'RUNG=3\nPEER=none\nSTATUS=declined\nRESULT_FILE=\nLOG_FILE=\nACTUAL_PROFILE=judgment\nACTUAL_MODEL=unreported\nACTUAL_EFFORT=unreported\n'
    exit 3 ;;
  none)
    printf 'RUNG=3\nPEER=none\nSTATUS=none\nRESULT_FILE=\nLOG_FILE=\nACTUAL_PROFILE=judgment\nACTUAL_MODEL=unreported\nACTUAL_EFFORT=unreported\n'
    exit 3 ;;
  *) echo "FAKE_PEER: unknown scenario '$FAKE_PEER_SCENARIO'" >&2; exit 9 ;;
esac
FAKE_PEER
chmod +x "$SKILL/bin/pln-peer"

# The "one clone cannot serve both hosts" check earlier in setup reads
# $HOME/.claude|.agents|.codex/skills/pln — point HOME somewhere empty so it
# never sees the developer's real installs.
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"

STORE="$WORK/state"

run_setup() { # run_setup <host> <scenario>
  rm -rf "$STORE"
  mkdir -p "$STORE"
  : > "$WORK/peer.log"
  RC=0
  OUT="$(env PATH="$BASE_PATH" HOME="$FAKE_HOME" PLN_HOST="$1" PLN_STATE_DIR="$STORE" \
    FAKE_PEER_SCENARIO="$2" FAKE_PEER_LOG="$WORK/peer.log" \
    "$SKILL/setup" 2>&1)" || RC=$?
}

get_flag() { env PLN_STATE_DIR="$STORE" "$SKILL/bin/pln-config" get peer_nudge_shown; }

peer_was_called() { [ -s "$WORK/peer.log" ]; }

# --- ready: a peer is usable — no tip, flag set -------------------------------
run_setup claude ready
[ "$RC" -eq 0 ] || fail "setup exited $RC on a ready peer (expected 0) — output:\n$OUT"
echo "$OUT" | grep -q "Tip:" && fail "a ready peer still printed the tip"
[ "$(get_flag)" = "true" ] || fail "a ready peer did not set peer_nudge_shown"

# --- consent pending: the existing one-time gate handles it later ------------
run_setup claude consent
[ "$RC" -eq 0 ] || fail "setup exited $RC on consent-pending (expected 0) — output:\n$OUT"
echo "$OUT" | grep -q "Tip:" && fail "consent-pending still printed the tip"
[ "$(get_flag)" = "true" ] || fail "consent-pending did not set peer_nudge_shown"

# --- declined: the user already said no ---------------------------------------
run_setup claude declined
[ "$RC" -eq 0 ] || fail "setup exited $RC on declined (expected 0) — output:\n$OUT"
echo "$OUT" | grep -q "Tip:" && fail "a declined peer still printed the tip"
[ "$(get_flag)" = "true" ] || fail "declined did not set peer_nudge_shown"

# --- nothing usable: the only case that prints the tip, and the flag is left
# unset so the tip resurfaces on the next setup run ----------------------------
run_setup claude none
[ "$RC" -eq 0 ] || fail "setup exited $RC when nothing was usable (expected 0) — output:\n$OUT"
echo "$OUT" | grep -q "Tip: pln can get a cross-model check" \
  || fail "nothing usable did not print the tip — output:\n$OUT"
[ "$(get_flag)" = "" ] || fail "the tip branch set peer_nudge_shown (should resurface next run)"
echo "$OUT" | grep -q 'Install and sign in to codex,' \
  || fail "a Claude host's tip did not name codex — output:\n$OUT"
echo "$OUT" | grep -qF "$SKILL/bin/pln-config\" set peer_command" \
  || fail "the tip did not point at pln-config by its resolved path — output:\n$OUT"

# --- the tip names the other host's CLI on a Codex install --------------------
run_setup codex none
[ "$RC" -eq 0 ] || fail "setup exited $RC on a Codex host with nothing usable — output:\n$OUT"
echo "$OUT" | grep -q 'Install and sign in to claude,' \
  || fail "a Codex host's tip did not name claude — output:\n$OUT"
echo "$OUT" | grep -q 'Install and sign in to codex,' \
  && fail "a Codex host's tip named codex instead of claude"

# --- once the flag is already true, pln-peer is never even invoked -----------
rm -rf "$STORE"
mkdir -p "$STORE"
env PLN_STATE_DIR="$STORE" "$SKILL/bin/pln-config" set peer_nudge_shown true >/dev/null
: > "$WORK/peer.log"
RC=0
OUT="$(env PATH="$BASE_PATH" HOME="$FAKE_HOME" PLN_HOST="claude" PLN_STATE_DIR="$STORE" \
  FAKE_PEER_SCENARIO="none" FAKE_PEER_LOG="$WORK/peer.log" \
  "$SKILL/setup" 2>&1)" || RC=$?
[ "$RC" -eq 0 ] || fail "setup exited $RC when already nudged — output:\n$OUT"
echo "$OUT" | grep -q "Tip:" && fail "an already-nudged install printed the tip again"
peer_was_called && fail "an already-nudged install still called pln-peer"

# --- optional economy evidence routing is surfaced once, only when usable ---
cat > "$SKILL/bin/pln-model-route" <<'FAKE_ROUTE'
#!/usr/bin/env bash
case "${FAKE_ECONOMY_SCENARIO:-unavailable}" in
  available) printf 'STATUS=available\nHOST=%s\nMODEL=economy\nEFFORT=low\n' "${3:-unknown}"; exit 0 ;;
  unavailable) printf 'STATUS=unavailable\nHOST=%s\nMODEL=\nEFFORT=\n' "${3:-unknown}"; exit 3 ;;
esac
FAKE_ROUTE
chmod +x "$SKILL/bin/pln-model-route"

rm -rf "$STORE"; mkdir -p "$STORE"
RC=0
OUT="$(env PATH="$BASE_PATH" HOME="$FAKE_HOME" PLN_HOST=codex PLN_STATE_DIR="$STORE" \
  FAKE_PEER_SCENARIO=ready FAKE_ECONOMY_SCENARIO=available "$SKILL/setup" 2>&1)" || RC=$?
[ "$RC" -eq 0 ] || fail "setup exited $RC while surfacing economy routing — output:\n$OUT"
echo "$OUT" | grep -q 'bounded fact-and-citation collection' \
  || fail "available economy routing was not surfaced — output:\n$OUT"
echo "$OUT" | grep -qF "$SKILL/bin/pln-config\" set evidence_profile economy" \
  || fail "the economy notice did not include the exact enable command"
[ "$(env PLN_STATE_DIR="$STORE" "$SKILL/bin/pln-config" get economy_nudge_shown)" = true ] \
  || fail "the economy notice did not persist its one-time marker"

OUT="$(env PATH="$BASE_PATH" HOME="$FAKE_HOME" PLN_HOST=codex PLN_STATE_DIR="$STORE" \
  FAKE_PEER_SCENARIO=ready FAKE_ECONOMY_SCENARIO=available "$SKILL/setup" 2>&1)"
echo "$OUT" | grep -q 'bounded fact-and-citation collection' \
  && fail "the economy notice repeated after its marker was set"

rm -rf "$STORE"; mkdir -p "$STORE"
OUT="$(env PATH="$BASE_PATH" HOME="$FAKE_HOME" PLN_HOST=codex PLN_STATE_DIR="$STORE" \
  FAKE_PEER_SCENARIO=ready FAKE_ECONOMY_SCENARIO=unavailable "$SKILL/setup" 2>&1)"
echo "$OUT" | grep -q 'bounded fact-and-citation collection' \
  && fail "unavailable economy routing printed a notice"
[ "$(env PLN_STATE_DIR="$STORE" "$SKILL/bin/pln-config" get economy_nudge_shown)" = "" ] \
  || fail "unavailable economy routing marked the notice as shown"

echo "OK"
