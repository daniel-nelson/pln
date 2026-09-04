#!/usr/bin/env bash
# tests/codex-agent.sh — regression check for bin/pln-codex-agent.
#
# Drives the helper against a fake `codex` on PATH, so the test needs no Codex
# install, no network, and no credentials. What it pins down is the behavior
# the orchestration loop depends on: a run that writes nothing is a failure and
# not an empty result, the thread id is read out of the event stream, the brief
# travels on stdin rather than argv, `resume` is not handed the session flags it
# doesn't accept, and a resume with no thread id is refused rather than quietly
# started as a fresh session that would redo the blocked item's work.
#
# Prints OK and exits 0 on success; any failed assertion aborts with a message.
#
# Run:  bash tests/codex-agent.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/../bin/pln-codex-agent"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-codex-agent-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- a fake codex that records how it was called -----------------------------
FAKE="$WORK/fakebin"
mkdir -p "$FAKE"
cat > "$FAKE/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
# Records argv and stdin, then behaves per PLN_TEST_SCENARIO.
printf '%s\n' "$*" > "${FAKE_ARGS_FILE:-/dev/null}"
cat > "${FAKE_STDIN_FILE:-/dev/null}"
out=""
prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out="$a"
  prev="$a"
done
case "${PLN_TEST_SCENARIO:-ok}" in
  ok)
    echo '{"type":"thread.started","thread_id":"tid-abc-123"}'
    echo '{"type":"turn.started"}'
    printf 'the agent said this\n' > "$out"
    ;;
  empty)
    echo '{"type":"thread.started","thread_id":"tid-abc-123"}'
    ;;
  error)
    echo 'something went wrong'
    exit 7
    ;;
  timeout)
    exit 124
    ;;
esac
FAKE_CODEX
chmod +x "$FAKE/codex"
export PATH="$FAKE:$PATH"
export FAKE_ARGS_FILE="$WORK/args" FAKE_STDIN_FILE="$WORK/stdin"

BRIEF="$WORK/brief.md"
printf 'do the thing `with backticks` and $dollars and "quotes"\n' > "$BRIEF"

run() { # run <scenario> <out-file> [extra args...]
  local scenario="$1" out="$2"; shift 2
  PLN_TEST_SCENARIO="$scenario" "$BIN" --brief "$BRIEF" --out "$out" "$@" 2>"$WORK/stderr"
}

# --- a successful run: status, thread id, result -----------------------------
out="$WORK/ok.out"
res="$(run ok "$out")" || fail "successful run exited non-zero"
grep -q '^STATUS=ok$' <<<"$res" || fail "success did not report STATUS=ok"
grep -q '^THREAD_ID=tid-abc-123$' <<<"$res" || fail "thread id not read from the event stream"
grep -q "^RESULT_FILE=$out\$" <<<"$res" || fail "RESULT_FILE line missing or wrong"
grep -q "^EVENTS_FILE=$out.events\$" <<<"$res" || fail "EVENTS_FILE did not default to <out>.events"
grep -q '^ACTUAL_PROFILE=inherit$' <<<"$res" || fail "default semantic profile was not attributed"
grep -q '^ACTUAL_MODEL=inherited-unreported$' <<<"$res" || fail "default inherited model was not attributed truthfully"
grep -q '^ACTUAL_EFFORT=inherited-unreported$' <<<"$res" || fail "default inherited effort was not attributed truthfully"
[ "$(cat "$out")" = "the agent said this" ] || fail "result file does not hold the agent's message"
[ "$(wc -l <<<"$res")" -eq 7 ] || fail "helper printed something other than its seven lines"
grep -q 'thread.started' "$out.events" || fail "event stream was not captured to the events file"

# --- --out never collides with the envelope path the brief assigns -----------
# `--out` captures the agent's final chat message, which is only ever a
# `RESULT_FILE=` pointer; the worker writes its bounded envelope to the path its
# brief assigns. A brief that names one path for both loses the envelope to the
# pointer, silently, after the work succeeded — a real run had to re-run a
# completed evidence worker for exactly this.
COLLIDE_BRIEF="$WORK/collide-brief.md"
COLLIDE_OUT="$WORK/results/envelope.txt"
mkdir -p "$WORK/results"
printf 'Write your bounded envelope to %s and nothing else.\n' "$COLLIDE_OUT" > "$COLLIDE_BRIEF"
if "$BIN" --brief "$COLLIDE_BRIEF" --out "$COLLIDE_OUT" --dry-run >"$WORK/collide.out" 2>"$WORK/collide.err"; then
  fail "--out was accepted on a path the brief also names"
fi
grep -q 'is a path the brief also names' "$WORK/collide.err" \
  || fail "the refusal did not say why the two paths cannot be one"
grep -q 'separate capture path' "$WORK/collide.err" \
  || fail "the refusal did not name the way out"
[ -s "$COLLIDE_OUT" ] || [ ! -e "$COLLIDE_OUT" ] \
  || fail "the refused run still truncated the envelope path"
# A distinct capture path is unaffected.
"$BIN" --brief "$COLLIDE_BRIEF" --out "$WORK/results/envelope.agent.txt" --dry-run >/dev/null 2>&1 \
  || fail "a distinct capture path was refused"

# --- the brief travels on stdin, not argv ------------------------------------
cmp -s "$BRIEF" "$WORK/stdin" || fail "the brief did not reach codex on stdin"
grep -q -- '-$' "$WORK/args" || fail "codex was not told to read the prompt from stdin"
grep -q 'backticks' "$WORK/args" && fail "the brief leaked onto the command line"

# --- exit 0 with an empty result is a failure, not an empty answer -----------
out="$WORK/empty.out"
printf 'stale result from a previous run\n' > "$out"
rc=0; res="$(run empty "$out")" || rc=$?
[ "$rc" -eq 4 ] || fail "empty result exited $rc (expected 4)"
grep -q '^STATUS=empty$' <<<"$res" || fail "empty result not reported as STATUS=empty"
[ -s "$out" ] && fail "a stale result file was left in place instead of being truncated"

# --- a non-zero codex exit is an error --------------------------------------
rc=0; res="$(run error "$WORK/err.out")" || rc=$?
[ "$rc" -eq 4 ] || fail "codex failure exited $rc (expected 4)"
grep -q '^STATUS=error$' <<<"$res" || fail "codex failure not reported as STATUS=error"

# --- a killed run is reported as a timeout ----------------------------------
rc=0; res="$(run timeout "$WORK/to.out")" || rc=$?
[ "$rc" -eq 4 ] || fail "timeout exited $rc (expected 4)"
grep -q '^STATUS=timeout$' <<<"$res" || fail "a 124 exit was not reported as STATUS=timeout"

# --- a spawn with no time ceiling still runs ---------------------------------
# `--timeout 0` leaves the timeout wrapper empty, which is also what happens on
# any machine with neither timeout(1) nor gtimeout(1) — every stock Mac. Under
# bash 3.2, still the /bin/bash macOS ships, an unguarded empty array is an
# unbound variable and the helper dies before it ever calls the CLI.
out="$WORK/noceiling.out"
res="$(run ok "$out" --timeout 0)" || fail "a spawn with no time ceiling exited non-zero"
grep -q '^STATUS=ok$' <<<"$res" || fail "a spawn with no time ceiling did not report STATUS=ok"
[ "$(cat "$out")" = "the agent said this" ] || fail "a spawn with no time ceiling wrote no result"

# --- the composed command: guards present, resume flags withheld -------------
cmd="$("$BIN" --brief "$BRIEF" --out "$WORK/dry.out" --add-dir "$WORK" --dry-run 2>&1 >/dev/null)"
grep -q -- '-u OPENAI_API_KEY' <<<"$cmd" || fail "OPENAI_API_KEY is not unset for the child"
grep -q -- '-u CODEX_API_KEY' <<<"$cmd" || fail "CODEX_API_KEY is not unset for the child"
grep -q -- '--json' <<<"$cmd" || fail "the event stream is not requested"
grep -q -- '-s workspace-write' <<<"$cmd" || fail "default sandbox is not workspace-write"
grep -q -- '--add-dir' <<<"$cmd" || fail "--add-dir was dropped"

cmd="$("$BIN" --brief "$BRIEF" --out "$WORK/dry.out" --profile judgment \
  --model gpt-5.6-sol --effort high --dry-run 2>&1 >/dev/null)"
grep -q -- '-m gpt-5.6-sol' <<<"$cmd" || fail "the routed model was not passed through"
grep -qF -- 'model_reasoning_effort=\"high\"' <<<"$cmd" || fail "the routed reasoning effort was not passed through"

cmd="$("$BIN" --brief "$BRIEF" --out "$WORK/dry.out" --resume tid-9 --sandbox read-only \
  --add-dir "$WORK" --dry-run 2>&1 >/dev/null)"
grep -q 'resume tid-9' <<<"$cmd" || fail "resume id not passed"
grep -q -- '-s ' <<<"$cmd" && fail "resume was handed --sandbox, which it does not accept"
grep -q -- '--add-dir' <<<"$cmd" && fail "resume was handed --add-dir, which it does not accept"
grep -q -- ' -C ' <<<"$cmd" && fail "resume was handed -C, which it does not accept"

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
guard "an unknown sandbox" --brief "$BRIEF" --out "$WORK/x.out" --sandbox wide-open
guard "a non-numeric timeout" --brief "$BRIEF" --out "$WORK/x.out" --timeout soon
guard "an unknown argument" --brief "$BRIEF" --out "$WORK/x.out" --turbo
guard "an unknown profile" --brief "$BRIEF" --out "$WORK/x.out" --profile guess
guard "an unknown effort" --brief "$BRIEF" --out "$WORK/x.out" --effort enormous
guard "an empty --resume id" --brief "$BRIEF" --out "$WORK/x.out" --resume ""
[ -e "$WORK/x.out" ] && fail "a usage error still created the output file"

# --- no codex on PATH is a clear, distinct failure ---------------------------
rc=0
env PATH="/usr/bin:/bin" "$BIN" --brief "$BRIEF" --out "$WORK/nocodex.out" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || fail "a missing Codex CLI exited $rc (expected 3)"

echo "OK"
