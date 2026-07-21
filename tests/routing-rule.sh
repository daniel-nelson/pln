#!/usr/bin/env bash
# tests/routing-rule.sh — regression check for bin/pln-routing-rule.
#
# Drives the helper through every RESULT state using the PLN_ROUTING_TARGET
# hook against throwaway temp dirs, then checks the per-host target resolution
# and rule wording via PLN_HOST + a fake HOME. Prints OK and exits 0 on success;
# any failed assertion aborts (set -e) with a message and a non-zero exit.
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

# Pin the host for the RESULT-state cases below so the suite behaves the same
# whether it is run from a Claude Code session, a Codex session, or a bare
# shell. The per-host cases at the bottom set PLN_HOST themselves.
export PLN_HOST=claude

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

# --- host-specific target resolution (no PLN_ROUTING_TARGET) -----------------
# Claude Code: $HOME/.claude/CLAUDE.md
d="$WORK/host-claude"; mkdir -p "$d/.claude"
out="$(env -u PLN_ROUTING_TARGET -u CODEX_HOME HOME="$d" PLN_HOST=claude "$BIN" --plan)"
grep -q "Would append to: $d/.claude/CLAUDE.md" <<<"$out" \
  || fail "claude host did not target ~/.claude/CLAUDE.md"

# Codex: $CODEX_HOME/AGENTS.md, defaulting to $HOME/.codex when CODEX_HOME is unset.
d="$WORK/host-codex"; mkdir -p "$d/.codex"
out="$(env -u PLN_ROUTING_TARGET -u CODEX_HOME HOME="$d" PLN_HOST=codex "$BIN" --plan)"
grep -q "Would append to: $d/.codex/AGENTS.md" <<<"$out" \
  || fail "codex host did not default to ~/.codex/AGENTS.md"

d2="$WORK/codex-home"; mkdir -p "$d2"
out="$(env -u PLN_ROUTING_TARGET HOME="$d" CODEX_HOME="$d2" PLN_HOST=codex "$BIN" --plan)"
grep -q "Would append to: $d2/AGENTS.md" <<<"$out" \
  || fail "codex host did not honor CODEX_HOME"

# A host whose global dir is absent gets no-target, and nothing is created.
d="$WORK/host-none"; mkdir -p "$d"
out="$(env -u PLN_ROUTING_TARGET -u CODEX_HOME HOME="$d" PLN_HOST=codex "$BIN" --apply)"
grep -q 'RESULT: no-target' <<<"$out" || fail "codex host with no ~/.codex not no-target"
[ -e "$d/.codex" ] && fail "--apply created the codex home dir"
out="$(env -u PLN_ROUTING_TARGET -u CODEX_HOME HOME="$d" PLN_HOST=claude "$BIN" --apply)"
grep -q 'RESULT: no-target' <<<"$out" || fail "claude host with no ~/.claude not no-target"
[ -e "$d/.claude" ] && fail "--apply created the claude dir"

# --- host-specific rule wording ----------------------------------------------
# Claude Code routes via the Skill tool; Codex has no such tool and picks skills
# up by name, so neither block may carry the other's instruction.
d="$WORK/wording"; mkdir -p "$d"

claude_target="$d/CLAUDE.md"
PLN_HOST=claude PLN_ROUTING_TARGET="$claude_target" "$BIN" --apply >/dev/null
grep -qF 'Skill tool' "$claude_target" || fail "claude block lost the Skill tool wording"

codex_target="$d/AGENTS.md"
PLN_HOST=codex PLN_ROUTING_TARGET="$codex_target" "$BIN" --apply >/dev/null
grep -qF 'Skill tool' "$codex_target" && fail "codex block mentions the Skill tool"
grep -qF '`pln-pr` skill' "$codex_target" || fail "codex block does not name the pln-pr skill"

# The Codex block is inlined into every prompt, so it has to stay short.
codex_bytes="$(wc -c < "$codex_target" | tr -d '[:space:]')"
[ "$codex_bytes" -le 700 ] || fail "codex routing block is $codex_bytes bytes; keep it under 700"

# The marker is host-neutral, so --remove strips either block.
for t in "$claude_target" "$codex_target"; do
  h=claude; [ "$t" = "$codex_target" ] && h=codex
  out="$(PLN_HOST="$h" PLN_ROUTING_TARGET="$t" "$BIN" --remove)"
  grep -q 'RESULT: removed' <<<"$out" || fail "--remove failed on the $h block"
  grep -qF "$MARKER" "$t" && fail "--remove left the $h marker behind"
done

echo "OK"
