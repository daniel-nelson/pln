#!/usr/bin/env bash
# tests/claude-agent.sh — regression check for bin/pln-claude-agent.
#
# The mirror of tests/codex-agent.sh, for the other direction: cross-provider
# consultation and the rare one-shot legacy-host fallback share this guarded
# helper, so it is driven here against a fake `claude` on PATH — no Claude
# install, network, or credentials.
#
# What it pins down is the set of guards whose absence fails *silently*: a run
# that exits non-zero having printed prose is a failure and not a review, a run
# that writes nothing is a failure and not an empty answer, the brief travels on
# stdin rather than argv, the peer is restricted with `--tools` (which takes
# permissions away) and never with `--allowedTools` (which only adds them), and
# ANTHROPIC_API_KEY is left alone, because for plenty of installs it is the only
# way the CLI authenticates at all.
#
# Prints OK and exits 0 on success; any failed assertion aborts with a message.
#
# Run:  bash tests/claude-agent.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-claude-agent"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-claude-agent-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- a fake claude that records how it was called ----------------------------
FAKE="$WORK/fakebin"
mkdir -p "$FAKE"
cat > "$FAKE/claude" <<'FAKE_CLAUDE'
#!/usr/bin/env bash
# Records argv and stdin, then behaves per PLN_TEST_SCENARIO.
printf '%s\n' "$*" > "${FAKE_ARGS_FILE:-/dev/null}"
cat > "${FAKE_STDIN_FILE:-/dev/null}"
case "${PLN_TEST_SCENARIO:-ok}" in
  ok)
    printf 'the peer said this\n'
    ;;
  empty)
    ;;
  error)
    # A rejected --model exits non-zero having printed a sentence of prose:
    # the exact shape that turns a failure into a "review" if only the file
    # is read.
    printf 'Error: unknown model\n'
    exit 1
    ;;
  timeout)
    exit 124
    ;;
esac
FAKE_CLAUDE
chmod +x "$FAKE/claude"
export PATH="$FAKE:$PATH"
export FAKE_ARGS_FILE="$WORK/args" FAKE_STDIN_FILE="$WORK/stdin"

BRIEF="$WORK/brief.md"
printf 'review `this` and $that and "the other"\n' > "$BRIEF"

run() { # run <scenario> <out-file> [extra args...]
  local scenario="$1" out="$2"; shift 2
  PLN_TEST_SCENARIO="$scenario" "$BIN" --brief "$BRIEF" --out "$out" \
    --cd "$WORK" "$@" 2>"$WORK/stderr"
}

# --- a successful run: status, result, and nothing else on stdout ------------
out="$WORK/ok.out"
res="$(run ok "$out")" || fail "successful run exited non-zero"
grep -q '^STATUS=ok$' <<<"$res" || fail "success did not report STATUS=ok"
grep -q "^RESULT_FILE=$out\$" <<<"$res" || fail "RESULT_FILE line missing or wrong"
grep -q "^LOG_FILE=$out.log\$" <<<"$res" || fail "LOG_FILE did not default to <out>.log"
grep -q '^ACTUAL_PROFILE=inherit$' <<<"$res" || fail "default semantic profile was not attributed"
grep -q '^ACTUAL_MODEL=inherited-unreported$' <<<"$res" || fail "default inherited model was not attributed truthfully"
grep -q '^ACTUAL_EFFORT=inherited-unreported$' <<<"$res" || fail "default inherited effort was not attributed truthfully"
[ "$(wc -l <<<"$res")" -eq 6 ] || fail "helper printed something other than its six lines"
[ "$(cat "$out")" = "the peer said this" ] || fail "result file does not hold the peer's answer"
[ -f "$out.log" ] || fail "no log file was written"

# --- the brief travels on stdin, not argv ------------------------------------
cmp -s "$BRIEF" "$WORK/stdin" || fail "the brief did not reach claude on stdin"
grep -q 'the other' "$WORK/args" && fail "the brief leaked onto the command line"

# --- exit 0 with an empty result is a failure, not an empty answer -----------
out="$WORK/empty.out"
printf 'stale result from a previous run\n' > "$out"
rc=0; res="$(run empty "$out")" || rc=$?
[ "$rc" -eq 4 ] || fail "empty result exited $rc (expected 4)"
grep -q '^STATUS=empty$' <<<"$res" || fail "empty result not reported as STATUS=empty"
[ -s "$out" ] && fail "a stale result file was left in place instead of being truncated"

# --- a non-zero exit is a failure even though prose was printed --------------
out="$WORK/err.out"
rc=0; res="$(run error "$out")" || rc=$?
[ "$rc" -eq 4 ] || fail "a failed run exited $rc (expected 4)"
grep -q '^STATUS=error$' <<<"$res" || fail "a failed run was not reported as STATUS=error"
grep -q 'unknown model' "$out" || fail "the failed run's prose should still be on disk for the caller to read"

# --- a killed run is reported as a timeout -----------------------------------
rc=0; res="$(run timeout "$WORK/to.out")" || rc=$?
[ "$rc" -eq 4 ] || fail "timeout exited $rc (expected 4)"
grep -q '^STATUS=timeout$' <<<"$res" || fail "a 124 exit was not reported as STATUS=timeout"

# --- a run with no time ceiling still runs -----------------------------------
# `--timeout 0` leaves the timeout wrapper empty, which is also what happens on
# any machine with neither timeout(1) nor gtimeout(1) — every stock Mac. Under
# bash 3.2, still the /bin/bash macOS ships, an unguarded empty array is an
# unbound variable and the helper dies before it ever calls the CLI.
out="$WORK/noceiling.out"
res="$(run ok "$out" --timeout 0)" || fail "a run with no time ceiling exited non-zero"
grep -q '^STATUS=ok$' <<<"$res" || fail "a run with no time ceiling did not report STATUS=ok"
[ "$(cat "$out")" = "the peer said this" ] || fail "a run with no time ceiling wrote no result"

# --- the composed command: the guards that make a peer read-only -------------
cmd="$("$BIN" --brief "$BRIEF" --out "$WORK/dry.out" --cd "$WORK" \
  --add-dir "$WORK" --dry-run 2>&1 >/dev/null)"
grep -q -- ' -p ' <<<"$cmd" || fail "print mode is not requested"
grep -q -- '--output-format text' <<<"$cmd" || fail "the output format is not pinned"
# The printed command is shell-quoted, so the commas may arrive escaped.
grep -qE -- '--tools Read.?,Grep.?,Glob' <<<"$cmd" || fail "the default tool set is not Read,Grep,Glob"
grep -q -- '--allowedTools' <<<"$cmd" && fail "--allowedTools only adds permissions; it can never make a peer read-only"
grep -q -- '--strict-mcp-config' <<<"$cmd" || fail "MCP servers are not excluded"
grep -q -- '--no-session-persistence' <<<"$cmd" || fail "the run would land in the user's /resume picker"
grep -q -- '--add-dir' <<<"$cmd" || fail "--add-dir was dropped"
grep -q 'ANTHROPIC_API_KEY' <<<"$cmd" && fail "ANTHROPIC_API_KEY must be left alone — it is a legitimate way to authenticate"

cmd="$("$BIN" --brief "$BRIEF" --out "$WORK/dry.out" --cd "$WORK" \
  --tools Read --profile judgment --model some-model --effort high --dry-run 2>&1 >/dev/null)"
grep -q -- '--tools Read ' <<<"$cmd" || fail "--tools was not honored"
grep -q -- '--model some-model' <<<"$cmd" || fail "--model was not passed through"
grep -q -- '--effort high' <<<"$cmd" || fail "--effort was not passed through"

# --- usage errors write nothing and exit 2 -----------------------------------
printf '' > "$WORK/blank.md"
guard() { # guard <description> <args...>
  local what="$1"; shift
  local rc=0
  "$BIN" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] || fail "$what exited $rc (expected 2)"
}
guard "a missing --brief" --out "$WORK/x.out"
guard "a missing --out" --brief "$BRIEF"
guard "a brief that does not exist" --brief "$WORK/nope.md" --out "$WORK/x.out"
guard "an empty brief" --brief "$WORK/blank.md" --out "$WORK/x.out"
guard "a non-numeric timeout" --brief "$BRIEF" --out "$WORK/x.out" --timeout soon
guard "an unknown argument" --brief "$BRIEF" --out "$WORK/x.out" --turbo
guard "an unknown profile" --brief "$BRIEF" --out "$WORK/x.out" --profile guess
guard "an unknown effort" --brief "$BRIEF" --out "$WORK/x.out" --effort enormous
[ -e "$WORK/x.out" ] && fail "a usage error still created the output file"

# A working root that does not exist is refused too, but that check runs after
# the output file has been truncated — so it gets a path of its own rather than
# weakening the assertion above.
guard "a working root that does not exist" --brief "$BRIEF" --out "$WORK/badcd.out" --cd "$WORK/nowhere"

# --- no claude on PATH is a clear, distinct failure --------------------------
rc=0
env PATH="/usr/bin:/bin" "$BIN" --brief "$BRIEF" --out "$WORK/noclaude.out" \
  --cd "$WORK" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || fail "a missing Claude CLI exited $rc (expected 3)"

echo "OK"
