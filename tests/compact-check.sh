#!/usr/bin/env bash
# tests/compact-check.sh — bin/pln-compact-check against scratch transcripts.
#
# The transcript lines below are cut-down copies of the records Claude Code
# writes: a router load is a user record carrying the router heading, a
# compaction is a system record with subtype compact_boundary, and the copies
# that follow a compaction (the summary, the re-attached skill, a request
# snapshot) carry the heading too without being a load.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$ROOT/bin/pln-compact-check"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-compact-test.XXXXXX")"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"

fail() { echo "FAIL: $*" >&2; exit 1; }

HEADING='# pln — personal planning workflow'
LOAD='{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Base directory for this skill: /x/pln\n\n'"$HEADING"'\n"}]}}'
READ='{"type":"user","message":{"role":"user","content":[{"tool_use_id":"t1","type":"tool_result","content":"7\t'"$HEADING"'\n"}]}}'
BOUNDARY='{"type":"system","subtype":"compact_boundary","content":"Conversation compacted"}'
SUMMARY='{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"Summary: ran '"$HEADING"'"}}'
ATTACH='{"type":"attachment","attachment":{"type":"invoked_skills","skills":[{"name":"pln","content":"'"$HEADING"'"}]}}'
BLOB='{"type":"api-request-blob","content":[{"type":"text","text":"'"$HEADING"'"}]}'
PROMPT='{"type":"user","message":{"role":"user","content":"c"}}'

transcript() { # transcript <record>... — writes a fresh transcript, prints its path
  local f r
  f="$(mktemp "$WORK/t.XXXXXX")"
  for r in "$@"; do printf '%s\n' "$r" >> "$f"; done
  printf '%s' "$f"
}
run() { # run <transcript-path> — the hook's stdout; fails the test on non-zero
  local out rc=0
  out="$(printf '{"session_id":"s","transcript_path":"%s","hook_event_name":"UserPromptSubmit","prompt":"c"}' "$1" | "$BIN")" || rc=$?
  [ "$rc" -eq 0 ] || fail "pln-compact-check exited $rc; a UserPromptSubmit hook must never block"
  printf '%s' "$out"
}
fires() { [ -n "$(run "$1")" ] || fail "$2"; }
silent() { [ -z "$(run "$1")" ] || fail "$2"; }

[ -x "$BIN" ] || fail "bin/pln-compact-check is missing or not executable"

# Malformed or absent input is silence, never an error.
out="$(printf 'not json' | "$BIN")" || fail "garbage stdin made the hook exit non-zero"
[ -z "$out" ] || fail "garbage stdin produced output"
silent "$WORK/missing.jsonl" "a transcript that does not exist produced output"

# No compaction since the load: nothing to recover.
silent "$(transcript "$LOAD" "$PROMPT")" "an uncompacted session produced output"

# A compaction before pln was ever loaded is none of pln's business.
silent "$(transcript "$BOUNDARY" "$SUMMARY" "$LOAD" "$PROMPT")" \
  "a compaction that predates the load produced output"

# A compaction after the load fires once, naming the router to read, and is
# silent on every later prompt.
t="$(transcript "$LOAD" "$PROMPT" "$BOUNDARY" "$SUMMARY" "$ATTACH" "$BLOB" "$PROMPT")"
first="$(run "$t")"
[ -n "$first" ] \
  || fail "a compaction after the load was not announced; the summary, re-attached copy or request snapshot was taken for a load"
printf '%s' "$first" | grep -qF "$ROOT/SKILL.md with the Read tool, the whole file" \
  || fail "the announcement does not name the whole-file Read of $ROOT/SKILL.md"
printf '%s' "$first" | grep -qF 'ask it again in full' \
  || fail "the announcement does not cover the question the compaction hid"
silent "$t" "the same compaction was announced twice"

# A second compaction is a new one.
printf '%s\n%s\n' "$BOUNDARY" "$PROMPT" >> "$t"
fires "$t" "a second compaction after the first announcement was not announced"
silent "$t" "the second compaction was announced twice"

# Reading the router after the compaction is the recovery; nothing to say.
silent "$(transcript "$LOAD" "$BOUNDARY" "$SUMMARY" "$ATTACH" "$READ" "$PROMPT")" \
  "a session that re-read the router after compacting was told to re-read it"

# Separate sessions keep separate state.
a="$(transcript "$LOAD" "$BOUNDARY" "$PROMPT")"
b="$(transcript "$LOAD" "$BOUNDARY" "$PROMPT")"
fires "$a" "session a was not announced"
fires "$b" "session b was silenced by session a's state"

# State it cannot keep private means silence, not repetition: another user's
# planted directory, a symlink, or one open to group or other.
state="$TMPDIR/pln-compact-$(id -u)"
rm -rf "$state"
mkdir -m 755 "$state"
silent "$(transcript "$LOAD" "$BOUNDARY" "$PROMPT")" "a group/other-readable state dir was used"
rm -rf "$state"
mkdir -m 700 "$WORK/elsewhere"
ln -s "$WORK/elsewhere" "$state"
silent "$(transcript "$LOAD" "$BOUNDARY" "$PROMPT")" "a symlinked state dir was used"
rm -f "$state"
mkdir -m 500 "$state"
silent "$(transcript "$LOAD" "$BOUNDARY" "$PROMPT")" \
  "a state dir it could not write was used; the announcement would repeat on every prompt"
chmod 700 "$state"

echo "OK"
