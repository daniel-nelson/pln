#!/usr/bin/env bash
# tests/peer.sh — regression check for bin/pln-peer, the three-rung ladder.
#
# `pln-peer` is the one place in the suite that answers "which agent gives the
# second opinion", so every skill's review inherits whatever it decides. It is
# driven here against fake `claude` and `codex` CLIs on PATH and a scratch
# PLN_STATE_DIR: no agent CLI is installed, nothing leaves the machine, and the
# developer's own ~/.pln is never touched.
#
# What it pins down:
#
#   - the ladder in order — a configured command beats a probe, a probe beats
#     nothing, and each rung falls through to the next rather than failing.
#   - the skip-the-host rule, in both directions. Under Claude it reaches for
#     Codex, under Codex for Claude, and it never consults the host itself —
#     which is the whole reason a "second opinion" is worth having.
#   - the one-time consent gate: unset asks, `false` declines to rung 3, `true`
#     lets a run through, and nothing is sent in any state until it is granted
#     — `--which` and `--dry-run` included, because both name another vendor's
#     CLI as a destination.
#   - `--which` reporting a selection (`STATUS=ready`) and an empty ladder
#     (rung 3, `STATUS=none`) as two different things, so neither can be read
#     as the other.
#   - a peer that is absent, unauthenticated, empty, failed, timed out, or
#     answering with malformed output is a fallback or a failed run, never a
#     review.
#   - the five-line stdout contract, whatever happened underneath.
#
# Prints OK and exits 0 on success; any failed assertion aborts with a message.
#
# Run:  bash tests/peer.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BIN="$(cd "$SCRIPT_DIR/../bin" && pwd)"
BIN="$REPO_BIN/pln-peer"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-peer-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# The fakes sit in front of a minimal PATH. If a real agent CLI is installed
# inside that minimal PATH, every "no peer available" case below would quietly
# find it and test the opposite of what it says.
BASE_PATH="/usr/bin:/bin"
for c in claude codex; do
  found="$(env PATH="$BASE_PATH" sh -c "command -v $c" 2>/dev/null || true)"
  [ -z "$found" ] || fail "a real $c at $found sits inside the minimal PATH this test relies on"
done

# --- fake CLIs ---------------------------------------------------------------
# Each answers its own auth probe first, so the probe never overwrites the argv
# the run records, and then behaves per its scenario variable.
BOTH="$WORK/bin-both"
ONLY_CLAUDE="$WORK/bin-claude"
ONLY_CODEX="$WORK/bin-codex"
NEITHER="$WORK/bin-none"
mkdir -p "$BOTH" "$ONLY_CLAUDE" "$ONLY_CODEX" "$NEITHER"

cat > "$BOTH/claude" <<'FAKE_CLAUDE'
#!/usr/bin/env bash
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then
  case "${PLN_TEST_CLAUDE_AUTH:-in}" in
    in) echo '{"loggedIn": true}'; exit 0 ;;
    out) echo '{"loggedIn": false}'; exit 0 ;;   # exit 0 and still unusable
    silent) exit 0 ;;                            # exit 0, says nothing
    *) exit 1 ;;
  esac
fi
printf '%s\n' "$*" > "${FAKE_CLAUDE_ARGS:-/dev/null}"
cat > "${FAKE_CLAUDE_STDIN:-/dev/null}"
case "${PLN_TEST_CLAUDE_RUN:-ok}" in
  ok) printf 'claude reviewed the plan\n' ;;
  empty) ;;
  error) printf 'Error: unknown model\n'; exit 1 ;;
  timeout) exit 124 ;;
esac
FAKE_CLAUDE

cat > "$BOTH/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then
  case "${PLN_TEST_CODEX_AUTH:-in}" in
    in) echo 'Logged in'; exit 0 ;;
    *) exit 1 ;;
  esac
fi
printf '%s\n' "$*" > "${FAKE_CODEX_ARGS:-/dev/null}"
cat > "${FAKE_CODEX_STDIN:-/dev/null}"
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
case "${PLN_TEST_CODEX_RUN:-ok}" in
  ok)
    echo '{"type":"thread.started","thread_id":"tid-peer-1"}'
    printf 'codex reviewed the plan\n' > "$out"
    ;;
  empty) echo '{"type":"thread.started","thread_id":"tid-peer-1"}' ;;
  error) echo 'boom'; exit 7 ;;
  timeout) exit 124 ;;
esac
FAKE_CODEX

# A rung-1 peer: the whole contract is prompt on stdin, answer on stdout.
cat > "$BOTH/fakepeer" <<'FAKE_PEER'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FAKE_PEER_ARGS:-/dev/null}"
cat > "${FAKE_PEER_STDIN:-/dev/null}"
case "${PLN_TEST_PEER_RUN:-ok}" in
  ok) printf 'the configured peer reviewed the plan\n' ;;
  empty) ;;
  error) printf 'no\n' >&2; exit 7 ;;
  timeout) exit 124 ;;
esac
FAKE_PEER

chmod +x "$BOTH/claude" "$BOTH/codex" "$BOTH/fakepeer"
cp "$BOTH/claude" "$ONLY_CLAUDE/claude"
cp "$BOTH/codex" "$ONLY_CODEX/codex"

export FAKE_CLAUDE_ARGS="$WORK/claude.args" FAKE_CLAUDE_STDIN="$WORK/claude.stdin"
export FAKE_CODEX_ARGS="$WORK/codex.args" FAKE_CODEX_STDIN="$WORK/codex.stdin"
export FAKE_PEER_ARGS="$WORK/peer.args" FAKE_PEER_STDIN="$WORK/peer.stdin"

export PLN_STATE_DIR="$WORK/state"
CONFIG="$PLN_STATE_DIR/config.yaml"
mkdir -p "$PLN_STATE_DIR"

BRIEF="$WORK/brief.md"
printf 'Read the plan below and argue with it.\n' > "$BRIEF"

# --- helpers -----------------------------------------------------------------
cfg() { # cfg <key> <value|->   ('-' removes the key, which `set` cannot do)
  if [ "$2" = "-" ]; then
    [ -f "$CONFIG" ] || return 0
    grep -v -E "^$1:" "$CONFIG" > "$CONFIG.tmp" || true
    mv "$CONFIG.tmp" "$CONFIG"
  else
    "$REPO_BIN/pln-config" set "$1" "$2"
  fi
}

RC=0
OUT=""
peer() { # peer <path-dir> <args...> — run pln-peer with a chosen PATH
  local dir="$1"; shift
  RC=0
  OUT="$(env PATH="$dir:$BASE_PATH" "$BIN" "$@" 2>"$WORK/stderr")" || RC=$?
}

field() { sed -n "s/^$1=//p" <<<"$OUT"; }

expect() { # expect <rung> <peer> <status> <rc> <description>
  [ "$RC" = "$4" ] || fail "$5 — exit $RC (expected $4)"
  [ "$(field RUNG)" = "$1" ] || fail "$5 — RUNG=$(field RUNG) (expected $1)"
  [ "$(field PEER)" = "$2" ] || fail "$5 — PEER=$(field PEER) (expected $2)"
  [ "$(field STATUS)" = "$3" ] || fail "$5 — STATUS=$(field STATUS) (expected $3)"
  [ "$(wc -l <<<"$OUT")" -eq 5 ] || fail "$5 — printed $(wc -l <<<"$OUT") lines, not the five-line contract"
}

fresh() { # fresh — forget every recorded run
  rm -f "$WORK/claude.args" "$WORK/codex.args" "$WORK/peer.args" \
        "$WORK/claude.stdin" "$WORK/codex.stdin" "$WORK/peer.stdin"
  rm -f "$WORK/run.out" "$WORK/run.out.log" "$WORK/run.out.events"
}

nothing_ran() { # nothing_ran <description>
  for f in "$WORK/claude.args" "$WORK/codex.args" "$WORK/peer.args"; do
    [ -e "$f" ] && fail "$1 — something was sent to $(basename "${f%.args}")"
  done
  [ -e "$WORK/run.out" ] && fail "$1 — an output file was created"
  return 0
}

# --- usage errors: refused before anything is selected or sent ---------------
guard() { # guard <description> <args...>
  local what="$1"; shift
  local rc=0
  env PATH="$BOTH:$BASE_PATH" "$BIN" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] || fail "$what exited $rc (expected 2)"
}
printf '' > "$WORK/blank.md"
guard "no arguments at all"
guard "a missing --out" --brief "$BRIEF"
guard "a missing --brief" --out "$WORK/run.out"
guard "a brief that does not exist" --brief "$WORK/nope.md" --out "$WORK/run.out"
guard "an empty brief" --brief "$WORK/blank.md" --out "$WORK/run.out"
guard "a non-numeric timeout" --brief "$BRIEF" --out "$WORK/run.out" --timeout soon
guard "an unknown host" --brief "$BRIEF" --out "$WORK/run.out" --host solaris
guard "an unknown argument" --brief "$BRIEF" --out "$WORK/run.out" --turbo
nothing_ran "a usage error"

# --- rung 3: no peer anywhere, and no question asked -------------------------
# The consent question is only worth raising when there is somebody to send to,
# so a machine with one agent CLI and no peer_command is never asked it.
cfg peer_command -
cfg peer_consent -
fresh
peer "$NEITHER" --brief "$BRIEF" --out "$WORK/run.out"
expect 3 none none 3 "no peer on the machine"
[ -z "$(field RESULT_FILE)" ] || fail "rung 3 named a result file"
[ -z "$(field LOG_FILE)" ] || fail "rung 3 named a log file"
nothing_ran "rung 3"

# --- the host is never its own peer ------------------------------------------
cfg peer_consent true
fresh
peer "$ONLY_CLAUDE" --host claude --which
expect 3 none none 3 "a Claude host with only claude installed"
peer "$ONLY_CODEX" --host codex --which
expect 3 none none 3 "a Codex host with only codex installed"
nothing_ran "the skip-the-host rule"

# --- rung 2, both directions --------------------------------------------------
peer "$BOTH" --host claude --which
expect 2 codex ready 0 "a Claude host reaching for codex"
SELECTED_STATUS="$(field STATUS)"
peer "$BOTH" --host codex --which
expect 2 claude ready 0 "a Codex host reaching for claude"

# A selection is not an empty ladder. The two once shared STATUS=none, and a
# caller read a peer that was installed, authenticated and consented as "no peer
# available" and skipped the cross-model review over it.
peer "$NEITHER" --host claude --which
expect 3 none none 3 "--which with nobody to send to"
if [ "$SELECTED_STATUS" = "$(field STATUS)" ]; then
  fail "a selected peer and an empty ladder report the same STATUS ($SELECTED_STATUS)"
fi

# Host detection is pln-host's, and pln-peer uses it when --host is absent.
RC=0
OUT="$(env PATH="$BOTH:$BASE_PATH" PLN_HOST=codex "$BIN" --which 2>"$WORK/stderr")" || RC=$?
expect 2 claude ready 0 "an undeclared host detected as codex"

# --- an unauthenticated peer falls through to the next rung ------------------
RC=0
OUT="$(env PATH="$ONLY_CLAUDE:$BASE_PATH" PLN_TEST_CLAUDE_AUTH=out "$BIN" --host codex --which 2>"$WORK/stderr")" || RC=$?
expect 3 none none 3 "a claude that reports loggedIn:false on exit 0"
RC=0
OUT="$(env PATH="$ONLY_CLAUDE:$BASE_PATH" PLN_TEST_CLAUDE_AUTH=silent "$BIN" --host codex --which 2>"$WORK/stderr")" || RC=$?
expect 3 none none 3 "a claude whose auth probe says nothing at all"
RC=0
OUT="$(env PATH="$ONLY_CODEX:$BASE_PATH" PLN_TEST_CODEX_AUTH=out "$BIN" --host claude --which 2>"$WORK/stderr")" || RC=$?
expect 3 none none 3 "a codex that is installed but not logged in"

# --- the one-time consent gate ------------------------------------------------
# Unset: a peer is named so the caller's question can name it, and nothing moves.
cfg peer_consent -
fresh
peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out"
expect 2 claude consent 5 "an unanswered consent question"
nothing_ran "an unanswered consent question"

# --which and --dry-run both name another vendor's CLI as a destination, so
# neither answers before the question does.
peer "$BOTH" --host codex --which
expect 2 claude consent 5 "--which with consent unanswered"
peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out" --dry-run
expect 2 claude consent 5 "--dry-run with consent unanswered"
nothing_ran "consent unanswered"

# A value nobody recognises is not consent. Absence and garbage read alike.
cfg peer_consent maybe
peer "$BOTH" --host codex --which
expect 2 claude consent 5 "a garbage consent value"

# Declined: rung 3, reported as declined, and the same exit code as "no peer"
# so a caller that already falls back needs no new branch.
cfg peer_consent false
peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out"
expect 3 none declined 3 "consent declined"
nothing_ran "consent declined"

# Granted, in any casing.
cfg peer_consent YES
peer "$BOTH" --host codex --which
expect 2 claude ready 0 "consent granted as YES"
cfg peer_consent true

# --- rung 1 beats rung 2, and carries the whole configured command -----------
# The command has flags and spaces: a config read that returned only its first
# token would run `fakepeer` bare and nobody would notice.
cfg peer_command "fakepeer --flag one two"
fresh
peer "$BOTH" --host codex --which
expect 1 fakepeer ready 0 "a configured command outranking an installed peer"

peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out"
expect 1 fakepeer ok 0 "a configured peer that answered"
[ "$(field RESULT_FILE)" = "$WORK/run.out" ] || fail "rung 1 did not name its result file"
[ "$(field LOG_FILE)" = "$WORK/run.out.log" ] || fail "rung 1 did not default the log to <out>.log"
[ "$(cat "$WORK/run.out")" = "the configured peer reviewed the plan" ] \
  || fail "the configured peer's answer did not reach the result file"
cmp -s "$BRIEF" "$WORK/peer.stdin" || fail "the brief did not reach the configured peer on stdin"
grep -q -- '--flag one two' "$WORK/peer.args" \
  || fail "the configured command lost its arguments between config and the run"
[ -e "$WORK/claude.args" ] && fail "rung 1 ran, and rung 2 ran as well"

# --dry-run says what would happen and runs nothing.
fresh
peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out" --dry-run
expect 1 fakepeer ok 0 "a rung-1 dry run"
# The printed command is shell-quoted, so the spaces inside it may arrive escaped.
grep -qE 'sh -c .?fakepeer.?( |\\ )--flag' "$WORK/stderr" \
  || fail "the dry run did not print the command it would have run"
[ -e "$WORK/peer.args" ] && fail "the dry run actually ran the peer"

# --- a rung-1 peer that fails is a failed run, never a review ----------------
rung1_fails() { # rung1_fails <scenario> <status> <description>
  fresh
  RC=0
  OUT="$(env PATH="$BOTH:$BASE_PATH" PLN_TEST_PEER_RUN="$1" \
    "$BIN" --host codex --brief "$BRIEF" --out "$WORK/run.out" 2>"$WORK/stderr")" || RC=$?
  expect 1 fakepeer "$2" 4 "$3"
}
rung1_fails empty empty "a configured peer that exited 0 and wrote nothing"
rung1_fails error error "a configured peer that exited non-zero"
rung1_fails timeout timeout "a configured peer that was killed on the ceiling"

cfg peer_command -

# --- rung 2, end to end through the real helpers -----------------------------
fresh
peer "$BOTH" --host codex --brief "$BRIEF" --out "$WORK/run.out" --model some-model
expect 2 claude ok 0 "a claude peer that answered"
[ "$(cat "$WORK/run.out")" = "claude reviewed the plan" ] \
  || fail "the claude peer's answer did not reach the result file"
cmp -s "$BRIEF" "$WORK/claude.stdin" || fail "the brief did not reach the claude peer on stdin"
grep -q -- '--model some-model' "$WORK/claude.args" || fail "--model did not reach the claude peer"
grep -q -- '--tools' "$WORK/claude.args" || fail "the claude peer was not restricted to a tool set"
[ -e "$WORK/codex.args" ] && fail "the codex helper ran on a Codex host"

fresh
peer "$BOTH" --host claude --brief "$BRIEF" --out "$WORK/run.out" --add-dir "$WORK"
expect 2 codex ok 0 "a codex peer that answered"
[ "$(cat "$WORK/run.out")" = "codex reviewed the plan" ] \
  || fail "the codex peer's answer did not reach the result file"
cmp -s "$BRIEF" "$WORK/codex.stdin" || fail "the brief did not reach the codex peer on stdin"
grep -q -- '-s read-only' "$WORK/codex.args" || fail "a codex peer was not run read-only"
grep -q -- "--add-dir $WORK" "$WORK/codex.args" || fail "--add-dir did not reach the codex peer"

# The helper's own status travels out, and the run is a failure.
rung2_fails() { # rung2_fails <var=value> <host> <peer> <status> <description>
  fresh
  RC=0
  OUT="$(env PATH="$BOTH:$BASE_PATH" "$1" \
    "$BIN" --host "$2" --brief "$BRIEF" --out "$WORK/run.out" 2>"$WORK/stderr")" || RC=$?
  expect 2 "$3" "$4" 4 "$5"
}
rung2_fails PLN_TEST_CLAUDE_RUN=empty codex claude empty "a claude peer that wrote nothing"
rung2_fails PLN_TEST_CLAUDE_RUN=error codex claude error "a claude peer that exited non-zero"
rung2_fails PLN_TEST_CLAUDE_RUN=timeout codex claude timeout "a claude peer that was killed"
rung2_fails PLN_TEST_CODEX_RUN=empty claude codex empty "a codex peer that wrote nothing"
rung2_fails PLN_TEST_CODEX_RUN=error claude codex error "a codex peer that exited non-zero"
rung2_fails PLN_TEST_CODEX_RUN=timeout claude codex timeout "a codex peer that was killed"

# --- a helper that is missing or answers with malformed output ---------------
# pln-peer reads its own copy of the helpers, so this runs a copy of the script
# in a bin directory that is missing one of them.
COPY="$WORK/copybin"
mkdir -p "$COPY"
cp "$REPO_BIN/pln-peer" "$REPO_BIN/pln-config" "$COPY/"
RC=0
OUT="$(env PATH="$BOTH:$BASE_PATH" "$COPY/pln-peer" --host codex \
  --brief "$BRIEF" --out "$WORK/run.out" 2>"$WORK/stderr")" || RC=$?
expect 3 none none 3 "a peer whose helper is missing from the install"

# A helper whose output carries no STATUS line at all: pln-peer must not report
# it as a review, and must not let the helper's own chatter reach its stdout.
cat > "$COPY/pln-claude-agent" <<'FAKE_HELPER'
#!/usr/bin/env bash
echo "unstructured chatter from a helper"
echo "SOMETHING_ELSE=1"
exit 0
FAKE_HELPER
chmod +x "$COPY/pln-claude-agent"
RC=0
OUT="$(env PATH="$BOTH:$BASE_PATH" "$COPY/pln-peer" --host codex \
  --brief "$BRIEF" --out "$WORK/run.out" 2>"$WORK/stderr")" || RC=$?
[ "$(field RUNG)" = "2" ] || fail "a malformed helper answer changed the rung"
[ "$(field STATUS)" = "ok" ] && fail "malformed helper output was reported as a review"
[ "$(wc -l <<<"$OUT")" -eq 5 ] || fail "a malformed helper answer broke the five-line contract"
grep -q 'chatter' <<<"$OUT" && fail "the helper's own output leaked into pln-peer's stdout"

echo "OK"
