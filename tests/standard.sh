#!/usr/bin/env bash
# tests/standard.sh — bin/pln-skill-standard and the vendored standard it seals.
#
# The corpus under reference/agent-skills/ is only worth carrying if something
# reads the sha256 column, and CLAUDE.md's source list is only worth keeping if
# it cannot drift away from what was vendored. Both are checked here.
#
# `check` and the failure cases run against scratch copies of the real corpus,
# not against a synthetic fixture: a fixture would leave the tracked bytes
# unchecked and the hashes produced-and-never-read. Nothing here writes into
# the repository, and PLN_STANDARD_URL_BASE is pinned to a dead loopback port
# on every invocation so no subcommand can reach the network even by mistake.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin/pln-skill-standard"
CORPUS="$ROOT/reference/agent-skills"
CLAUDE_MD="$ROOT/CLAUDE.md"
MANIFEST='SOURCES.tsv'
UNREACHABLE='http://127.0.0.1:9'

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-standard-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
fail() { printf 'FAIL: %s\n' "$1"; FAILED=1; }
said() { case "$OUT" in *"$1"*) ;; *) fail "$2"$'\n'"  output was: $OUT" ;; esac; }

scratch() { # scratch <name> — a private copy of the real corpus
  local d="$WORK/$1"
  mkdir -p "$d"
  cp "$CORPUS"/* "$d"/ || { fail "could not copy the corpus into $d"; return 1; }
  printf '%s' "$d"
}

run() { # run <corpus-dir> <subcommand...> — sets OUT and RC
  local d="$1"
  shift
  OUT="$(PLN_STANDARD_DIR="$d" PLN_STANDARD_URL_BASE="$UNREACHABLE" "$BIN" "$@" 2>&1)"
  RC=$?
}

faults() { # faults <dir> <subcommand> <expected STATUS> <what it should catch>
  run "$1" "$2"
  [ "$RC" -ne 0 ] || fail "$2 exited 0 on $4"$'\n'"  output was: $OUT"
  said "STATUS=$3" "$2 did not report STATUS=$3 on $4"
}

# ─── an intact corpus passes, and it is the tracked one ──────────────────────
D="$(scratch intact)" || D=""
if [ -n "$D" ]; then
  run "$D" check
  [ "$RC" -eq 0 ] || fail "check rejected the repository's own corpus"$'\n'"  output was: $OUT"
  said 'STATUS=ok' "check did not report STATUS=ok for an intact corpus"

  # paths is the subcommand the load rule in CLAUDE.md sends an agent to, so a
  # line per row with a resolvable absolute path is its contract.
  run "$D" paths
  [ "$RC" -eq 0 ] || fail "paths failed on an intact corpus"$'\n'"  output was: $OUT"
  ROWS="$(LC_ALL=C tail -n +2 "$CORPUS/$MANIFEST" | grep -c .)"
  LINES="$(printf '%s\n' "$OUT" | grep -c '^FETCHED=.* FILE=/')"
  [ "$LINES" -eq "$ROWS" ] \
    || fail "paths printed $LINES absolute FILE= lines for $ROWS manifest rows"
fi

# ─── the four corpus faults ──────────────────────────────────────────────────
D="$(scratch mutated)" && printf 'x' >> "$D/llms.txt" \
  && faults "$D" check drift "a mutated byte"

D="$(scratch absent)" && rm -f "$D/llms.txt" \
  && faults "$D" check missing "a file named by a row and not present"

D="$(scratch extra)" && printf 'stray\n' > "$D/unclaimed.md" \
  && faults "$D" check extra "a file no manifest row claims"

# The counterpart: the extra-file pass skips dotfiles on purpose, because
# Finder writes .DS_Store into any directory a user opens and a gauntlet that
# goes red on that teaches people to loosen the check.
D="$(scratch dotfile)"
if [ -n "$D" ]; then
  printf '\0\0' > "$D/.DS_Store"
  run "$D" check
  [ "$RC" -eq 0 ] || fail "check went red on a .DS_Store"$'\n'"  output was: $OUT"
fi

# ─── a path column that is not a plain filename ──────────────────────────────
# refresh writes through this column and check reads through it, so a row
# reading ../../bin/pln-generate would have a fetch overwrite an executable.
# Both subcommands must refuse it before doing anything, which is the one
# refresh property an offline script can pin.
D="$(scratch escaping-path)"
if [ -n "$D" ]; then
  awk -F'\t' 'BEGIN { OFS = "\t" } NR == 2 { $2 = "../../bin/pln-generate" } { print }' \
    "$CORPUS/$MANIFEST" > "$D/$MANIFEST"
  faults "$D" check invalid "a row whose path escapes the corpus directory"
  faults "$D" refresh invalid "a row whose path escapes the corpus directory"
fi

D="$(scratch symlinked-path)"
if [ -n "$D" ]; then
  rm -f "$D/llms.txt"
  ln -s specification.md "$D/llms.txt"
  faults "$D" check invalid "a row whose path is a symlink"
  faults "$D" refresh invalid "a row whose path is a symlink"
fi

# ─── refresh cannot reach its sources, so it writes nothing ──────────────────
# This is the helper's one corrupting operation. A partial rewrite would leave
# files sealed against hashes derived from a different fetch.
PRISTINE="$(scratch pristine-before)"
D="$(scratch unreachable)"
if [ -n "$PRISTINE" ] && [ -n "$D" ]; then
  run "$D" refresh
  [ "$RC" -ne 0 ] || fail "refresh exited 0 with every source unreachable"
  diff -r "$PRISTINE" "$D" >/dev/null 2>&1 \
    || fail "an unreachable refresh changed the corpus"$'\n'"  $(diff -r "$PRISTINE" "$D" 2>&1 | head -5)"
  if command -v curl >/dev/null 2>&1; then
    said 'STATUS=unreachable' "an unreachable refresh did not report STATUS=unreachable"
    said "$UNREACHABLE" "an unreachable refresh did not name the source it could not reach"
  fi
  # And the corpus it could not rewrite still passes its own seal.
  run "$D" check
  [ "$RC" -eq 0 ] || fail "the corpus no longer verifies after a failed refresh"
fi

# ─── the source list and the manifest cannot drift apart ─────────────────────
# Normalized both ways: the manifest records the raw-markdown URL that refresh
# fetches, and CLAUDE.md names the page a human opens.
LIST_URLS="$(grep -E '^- `https://' "$CLAUDE_MD" | grep -oE 'https://[^`]+' \
  | sed 's/\.md$//' | LC_ALL=C sort -u)"
SRC_URLS="$(LC_ALL=C tail -n +2 "$CORPUS/$MANIFEST" | grep . | cut -f1 \
  | sed 's/\.md$//' | LC_ALL=C sort -u)"
[ -n "$LIST_URLS" ] || fail "no source bullets found in $CLAUDE_MD"
[ -n "$SRC_URLS" ] || fail "no urls found in $MANIFEST"

UNLISTED="$(comm -23 <(printf '%s\n' "$SRC_URLS") <(printf '%s\n' "$LIST_URLS"))"
[ -z "$UNLISTED" ] \
  || fail "vendored but absent from CLAUDE.md's source list:"$'\n'"$UNLISTED"

# The other direction has exactly one sanctioned exception, and it is named
# rather than filtered out: the two code.claude.com pages are deliberately not
# vendored — 177 KB of general product documentation of which ~3 KB bears on
# pln — so a third unvendored URL appearing here is drift, not an exception.
UNVENDORED="$(comm -13 <(printf '%s\n' "$SRC_URLS") <(printf '%s\n' "$LIST_URLS"))"
EXPECTED_UNVENDORED="$(printf '%s\n%s\n' \
  'https://code.claude.com/docs/en/context-window' \
  'https://code.claude.com/docs/en/skills' | LC_ALL=C sort)"
[ "$UNVENDORED" = "$EXPECTED_UNVENDORED" ] \
  || fail "the unvendored source URLs are no longer exactly the two code.claude.com pages:"$'\n'"$UNVENDORED"

# ─── nothing under reference/ may look like a skill ──────────────────────────
# setup globs one directory level, so the file that would make it link the
# reference tree as a skill named `reference` is reference/SKILL.md, not
# reference/agent-skills/SKILL.md. The any-depth form covers both.
FOUND="$(find "$ROOT/reference" -name SKILL.md -print 2>/dev/null)"
[ -z "$FOUND" ] \
  || fail "reference/ contains a SKILL.md, which setup would link as a skill:"$'\n'"$FOUND"
grep -qF '[ -f "$subdir/SKILL.md" ] || continue' "$ROOT/setup" \
  || fail "setup no longer selects skills by <subdir>/SKILL.md — recheck what the assertion above must cover"

# ─── the helper's surface ────────────────────────────────────────────────────
OUT="$("$BIN" --help 2>&1)"; RC=$?
[ "$RC" -eq 0 ] || fail "--help exited $RC"
for sub in check paths refresh; do
  said "pln-skill-standard $sub" "--help does not document the $sub subcommand"
  grep -qE "^  $sub\)" "$BIN" || fail "the $sub subcommand is not dispatched"
done
OUT="$("$BIN" nonsense 2>&1)"; RC=$?
[ "$RC" -eq 2 ] || fail "an unknown subcommand exited $RC, not 2"

# ─── CLAUDE.md's load rule ───────────────────────────────────────────────────
# The label is the part of item 9 that addresses the failure no path trigger
# reaches: an agent answered a question about the standard out of the digest
# and could not tell from the inside that it had.
grep -q 'This section is a digest, not the standard' "$CLAUDE_MD" \
  || fail "CLAUDE.md's Agent Skills section no longer labels itself a digest"
grep -q 'not a claim from the standard' "$CLAUDE_MD" \
  || fail "the digest label no longer says a claim read from it is not a claim from the standard"
grep -q 'reference/agent-skills' "$CLAUDE_MD" \
  || fail "the digest label no longer says where the sources actually are"
grep -q 'pln-skill-standard paths' "$CLAUDE_MD" \
  || fail "CLAUDE.md no longer points at bin/pln-skill-standard paths"
grep -q 'pln-skill-standard refresh' "$CLAUDE_MD" \
  || fail "CLAUDE.md no longer names refresh as the way to find out what upstream changed"
grep -q 're-stamp the date above' "$CLAUDE_MD" \
  && fail "the re-stamp instruction is back; it is what made the date attest to a check nobody ran"

# ─── the Testing section lists the gauntlet it claims to ─────────────────────
COUNT=0
for t in "$ROOT"/tests/*.sh; do
  b="$(basename "$t")"
  COUNT=$((COUNT + 1))
  grep -qF "bash tests/$b" "$CLAUDE_MD" \
    || fail "tests/$b is not listed in CLAUDE.md's Testing section"
done
case "$COUNT" in
  13) WORD=thirteen ;; 14) WORD=fourteen ;; 15) WORD=fifteen ;;
  16) WORD=sixteen ;; 17) WORD=seventeen ;; 18) WORD=eighteen ;;
  19) WORD=nineteen ;; 20) WORD=twenty ;;
  *) WORD='' ; fail "extend the number words in tests/standard.sh: there are now $COUNT scripts" ;;
esac
[ -z "$WORD" ] || grep -qF "All $WORD must print" "$CLAUDE_MD" \
  || fail "CLAUDE.md's Testing section does not say \"All $WORD must print\" for $COUNT scripts"

[ "$FAILED" -eq 0 ] && echo OK
exit "$FAILED"
