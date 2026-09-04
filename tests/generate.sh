#!/usr/bin/env bash
# tests/generate.sh — regression check for bin/pln-generate.
#
# The generator is the one piece of real logic the host seam adds, and the
# property the whole design rests on is an *absence*: the copy of a skill a
# model reads must contain its own host's mechanics and nothing addressed to the
# other host. So every case here asserts both directions — what is present and
# what must not be.
#
# Two halves:
#
#   1. Fixtures. A throwaway repo with its own src/ tree exercises the three
#      directives, the src/shared/ fallback for an include, the generated-by
#      banner, nested targets, --list, --clean, and every error path, without
#      depending on the real skill text.
#   2. The real sources. Both hosts are generated into temp dirs and grepped for
#      the other host's mechanics, for leftover directives, and for the
#      placeholder text that means nothing was built.
#
# Needs no network, no Codex install, and never writes to the working tree.
#
# Run:  bash tests/generate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$REPO_DIR/bin/pln-generate"

tracked_target_status_before=""
tracked_target_fingerprint_before=""
if [ -d "$REPO_DIR/.git" ]; then
  tracked_targets_before="$(git -C "$REPO_DIR" ls-files -- $("$BIN" --list))"
  if [ -n "$tracked_targets_before" ]; then
    tracked_target_status_before="$(git -C "$REPO_DIR" status --porcelain -- $tracked_targets_before)"
    while IFS= read -r target; do
      tracked_target_fingerprint_before="$tracked_target_fingerprint_before$target $(git -C "$REPO_DIR" hash-object "$target")
"
    done <<< "$tracked_targets_before"
  fi
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-generate-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

has() { grep -qF -- "$2" "$1" || fail "$3"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3"; return 0; }
appears_before() { # appears_before <file> <first text> <second text> <description>
  local f="$1" first="$2" second="$3" what="$4" first_line second_line
  first_line="$(awk -v needle="$first" 'index($0, needle) { print NR; exit }' "$f")"
  second_line="$(awk -v needle="$second" 'index($0, needle) { print NR; exit }' "$f")"
  [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ] \
    || fail "$what"
}
has_one_trailing_newline() { # has_one_trailing_newline <file> <description>
  local f="$1" what="$2" last penultimate
  [ -s "$f" ] || fail "$what is empty"
  last="$(tail -c 1 "$f" | od -An -t u1 | tr -d '[:space:]')"
  penultimate="$(tail -c 2 "$f" | head -c 1 | od -An -t u1 | tr -d '[:space:]')"
  [ "$last" = "10" ] || fail "$what does not end in a newline"
  [ "$penultimate" != "10" ] || fail "$what ends with an extra blank line"
}

# ─── a throwaway repo the generator can be pointed at ─────────────────────────
# bin/pln-generate resolves its sources relative to its own location, so a copy
# in a fixture tree reads that tree's src/ and nothing of the real one.
new_repo() { # new_repo <dir>
  local d="$1"
  mkdir -p "$d/bin" "$d/src/hosts/claude" "$d/src/hosts/codex"
  cp "$BIN" "$d/bin/pln-generate"
  printf 'TOOL=Workflow\nAMPER=stays & literal\n' > "$d/src/hosts/claude/vars"
  printf 'TOOL=codex exec\nAMPER=stays & literal\n' > "$d/src/hosts/codex/vars"
}

R="$WORK/fixture"
new_repo "$R"

printf 'Claude greeting fragment.\nIt calls {{TOOL}}.\n' > "$R/src/hosts/claude/greeting.md"
printf 'Codex greeting fragment.\nIt calls {{TOOL}}.\n' > "$R/src/hosts/codex/greeting.md"

# src/shared/ holds a fragment whose text is the same on both hosts, so a
# passage two skills share lives in one file. A same-named host fragment wins:
# `greeting` below exists in both places and only the host copy may appear.
mkdir -p "$R/src/shared"
printf 'Shared farewell fragment.\nIt also calls {{TOOL}}.\n' > "$R/src/shared/farewell.md"
printf 'Shared greeting fragment — must never win.\n' > "$R/src/shared/greeting.md"

cat > "$R/src/SKILL.core.md" <<'CORE'
---
name: fixture
---

# Fixture skill

<!-- pln:include greeting -->

<!-- pln:include farewell -->

<!-- pln:only claude -->
Claude-only body: spawn the item agent with the Workflow tool.
<!-- pln:endonly -->
<!-- pln:only codex -->
Codex-only body: spawn the item agent with bin/pln-codex-agent.
<!-- pln:endonly -->

Shared tail, and an ampersand that {{AMPER}}.
CORE

mkdir -p "$R/src/nested"
cat > "$R/src/nested/OTHER.core.md" <<'CORE'
---
name: fixture-nested
---
Nested target for {{TOOL}}.
Generated output root: {{OUTPUT_ROOT}}.
CORE

# ─── --list names every target, relative and sorted ───────────────────────────
list="$("$R/bin/pln-generate" --list)"
[ "$list" = "$(printf 'SKILL.md\nnested/OTHER.md')" ] \
  || fail "--list printed: $list"

# ─── a claude build: own mechanics in, the other host's out ───────────────────
out_c="$WORK/out-claude"
"$R/bin/pln-generate" --host claude --out-dir "$out_c" >/dev/null
f="$out_c/SKILL.md"
has "$f" 'Claude greeting fragment.' "claude build lost its fragment"
has "$f" 'It calls Workflow.' "{{TOOL}} was not substituted inside a fragment"
has "$f" 'Claude-only body' "claude build lost its pln:only block"
has "$f" 'Shared tail' "claude build lost the shared body"
has "$f" 'an ampersand that stays & literal' "a & in a vars value was mangled"
has "$f" 'Shared farewell fragment.' "the shared fragment did not resolve for claude"
has "$f" 'It also calls Workflow.' "{{TOOL}} was not substituted inside a shared fragment"
hasnt "$f" 'must never win' "a shared fragment beat the claude fragment of the same name"
hasnt "$f" 'Codex greeting fragment.' "the codex fragment leaked into the claude build"
hasnt "$f" 'Codex-only body' "the codex pln:only block leaked into the claude build"
hasnt "$f" 'pln-codex-agent' "codex mechanics leaked into the claude build"

# ─── a codex build: the mirror image ──────────────────────────────────────────
out_x="$WORK/out-codex"
"$R/bin/pln-generate" --host codex --out-dir "$out_x" >/dev/null
f="$out_x/SKILL.md"
has "$f" 'Codex greeting fragment.' "codex build lost its fragment"
has "$f" 'It calls codex exec.' "{{TOOL}} was not substituted for codex"
has "$f" 'Codex-only body' "codex build lost its pln:only block"
has "$f" 'Shared tail' "codex build lost the shared body"
has "$f" 'Shared farewell fragment.' "the shared fragment did not resolve for codex"
has "$f" 'It also calls codex exec.' "{{TOOL}} was not substituted inside a shared fragment"
hasnt "$f" 'must never win' "a shared fragment beat the codex fragment of the same name"
hasnt "$f" 'Claude greeting fragment.' "the claude fragment leaked into the codex build"
hasnt "$f" 'Claude-only body' "the claude pln:only block leaked into the codex build"
hasnt "$f" 'Workflow' "claude mechanics leaked into the codex build"

# ─── nested targets land at the same relative path ────────────────────────────
[ -f "$out_x/nested/OTHER.md" ] || fail "a nested target was not written under out-dir"
has "$out_x/nested/OTHER.md" 'Nested target for codex exec.' "nested target not rendered"
out_x_abs="$(cd "$out_x" && pwd -P)"
has "$out_x/nested/OTHER.md" "Generated output root: $out_x_abs." \
  "nested target did not receive the absolute generated output root"

# ─── the banner is stamped, and after the frontmatter ─────────────────────────
for f in "$out_c/SKILL.md" "$out_x/SKILL.md"; do
  [ "$(sed -n 1p "$f")" = "---" ] || fail "$f does not start with YAML frontmatter"
  [ "$(sed -n 3p "$f")" = "---" ] || fail "$f banner displaced the frontmatter"
  has "$f" 'Generated by bin/pln-generate' "$f carries no generated-by banner"
  has "$f" 'Edit src/ and run ./setup' "$f banner does not say where to edit"
done
grep -qF 'for the claude host' "$out_c/SKILL.md" || fail "banner names the wrong host"
grep -qF 'for the codex host' "$out_x/SKILL.md" || fail "banner names the wrong host"

# ─── no directive survives into the output ────────────────────────────────────
for f in "$out_c/SKILL.md" "$out_x/SKILL.md" "$out_x/nested/OTHER.md"; do
  for d in 'pln:include' 'pln:only' 'pln:endonly' '{{'; do
    hasnt "$f" "$d" "unconsumed '$d' left in $f"
  done
done

# ─── error paths: non-zero exit, and the target left untouched ────────────────
# Each case gets its own single-target repo so the failure is unambiguous.
bad_repo() { # bad_repo <name> <core-body...>  → prints the repo dir
  local d="$WORK/bad-$1"
  new_repo "$d"
  printf 'Codex greeting fragment.\n' > "$d/src/hosts/codex/greeting.md"
  printf 'Claude greeting fragment.\n' > "$d/src/hosts/claude/greeting.md"
  cat > "$d/src/SKILL.core.md"
  printf '%s' "$d"
}

expect_fail() { # expect_fail <repo> <description> <args...>
  local d="$1" what="$2"; shift 2
  local target="$d/SKILL.md" rc=0
  printf 'sentinel\n' > "$target"
  "$d/bin/pln-generate" "$@" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || fail "$what exited 0 (expected non-zero)"
  [ "$(cat "$target")" = "sentinel" ] || fail "$what overwrote the target file"
}

d="$(bad_repo missing-fragment <<'CORE'
---
name: x
---
<!-- pln:include nowhere -->
CORE
)"
expect_fail "$d" "an include of a fragment that does not exist" --host codex --out-dir "$d"

# A name absent from both folders fails loudly, and the message names both, so
# the reader knows the shared fallback was tried too.
err="$("$d/bin/pln-generate" --host codex --out-dir "$d" 2>&1 >/dev/null || true)"
case "$err" in
  *"src/hosts/codex"*) ;;
  *) fail "the missing-fragment error does not name the host folder: $err" ;;
esac
case "$err" in
  *"src/shared"*) ;;
  *) fail "the missing-fragment error does not name the shared folder: $err" ;;
esac

d="$(bad_repo unclosed <<'CORE'
---
name: x
---
<!-- pln:only codex -->
body
CORE
)"
expect_fail "$d" "an unclosed pln:only block" --host codex --out-dir "$d"

d="$(bad_repo stray-end <<'CORE'
---
name: x
---
<!-- pln:endonly -->
CORE
)"
expect_fail "$d" "a pln:endonly with no pln:only" --host codex --out-dir "$d"

d="$(bad_repo nested-only <<'CORE'
---
name: x
---
<!-- pln:only codex -->
<!-- pln:only claude -->
<!-- pln:endonly -->
<!-- pln:endonly -->
CORE
)"
expect_fail "$d" "a nested pln:only block" --host codex --out-dir "$d"

d="$(bad_repo malformed <<'CORE'
---
name: x
---
<!-- pln:include two words -->
CORE
)"
expect_fail "$d" "a pln:include with a malformed argument" --host codex --out-dir "$d"

d="$(bad_repo no-frontmatter <<'CORE'
# A core file with no YAML frontmatter
CORE
)"
expect_fail "$d" "a core file with nowhere to stamp the banner" --host codex --out-dir "$d"

# An unknown host, and no host at all, are both refused before anything is read.
d="$(bad_repo no-host <<'CORE'
---
name: x
---
body
CORE
)"
expect_fail "$d" "an unknown host" --host solaris --out-dir "$d"
expect_fail "$d" "no host at all" --out-dir "$d"
rm -rf "$d/src/hosts/codex"
expect_fail "$d" "a host with no fragment directory" --host codex --out-dir "$d"

# ─── --clean puts the tracked placeholders back ───────────────────────────────
# This is what keeps an upgrade's `git stash` from seeing a permanently-modified
# tracked file, so it is worth a real git checkout rather than a mock.
G="$WORK/gitrepo"
new_repo "$G"
printf 'Claude greeting fragment.\n' > "$G/src/hosts/claude/greeting.md"
cat > "$G/src/SKILL.core.md" <<'CORE'
---
name: x
---
<!-- pln:include greeting -->
CORE
printf -- '---\nname: x\n---\nplaceholder, run ./setup\n' > "$G/SKILL.md"
git -C "$G" init -q
git -C "$G" add -A
git -C "$G" -c user.name=t -c user.email=t@example.com commit -qm init
"$G/bin/pln-generate" claude >/dev/null
grep -qF 'placeholder, run ./setup' "$G/SKILL.md" && fail "generate did not overwrite the placeholder"
[ -n "$(git -C "$G" status --porcelain SKILL.md)" ] || fail "generate left SKILL.md unmodified in git"
"$G/bin/pln-generate" --clean
grep -qF 'placeholder, run ./setup' "$G/SKILL.md" || fail "--clean did not restore the placeholder"
[ -z "$(git -C "$G" status --porcelain SKILL.md)" ] || fail "--clean left a dirty tree"
has_one_trailing_newline "$G/SKILL.md" "--clean fixture placeholder"

# Exercise the real recursive target list and tracked placeholders in an
# isolated checkout. This catches malformed shipped stubs that a one-target
# fixture cannot: --clean restores the committed bytes, so every real target
# must itself carry exactly one trailing newline.
GC="$WORK/real-clean"
mkdir -p "$GC/bin"
cp "$BIN" "$GC/bin/pln-generate"
cp -R "$REPO_DIR/src" "$GC/src"
while IFS= read -r target; do
  mkdir -p "$GC/$(dirname "$target")"
  cp "$REPO_DIR/$target" "$GC/$target"
done < <("$BIN" --list)
git -C "$GC" init -q
git -C "$GC" add -A
git -C "$GC" -c user.name=t -c user.email=t@example.com commit -qm init
"$GC/bin/pln-generate" codex >/dev/null
"$GC/bin/pln-generate" --clean
while IFS= read -r target; do
  has_one_trailing_newline "$GC/$target" "--clean real placeholder $target"
done < <("$GC/bin/pln-generate" --list)

# Outside a git checkout --clean has nothing to restore, and says so rather than
# failing the install that called it.
N="$WORK/nogit"
new_repo "$N"
cat > "$N/src/SKILL.core.md" <<'CORE'
---
name: x
---
body
CORE
"$N/bin/pln-generate" --clean 2>/dev/null || fail "--clean outside a git checkout exited non-zero"

# ─── the real sources, both hosts ─────────────────────────────────────────────
# The fixtures above prove the mechanism; these prove the shipped text actually
# splits. Generated into temp dirs — the working tree is never written to.
real_c="$WORK/real-claude"
real_x="$WORK/real-codex"
"$BIN" --host claude --out-dir "$real_c" >/dev/null
"$BIN" --host codex --out-dir "$real_x" >/dev/null

targets="$("$BIN" --list)"
[ -n "$targets" ] || fail "the real sources declare no targets"
printf '%s\n' "$targets" | grep -qxF 'pln-simplify/SKILL.md' \
  || fail 'the real target list omits pln-simplify/SKILL.md'

while IFS= read -r t; do
  for f in "$real_c/$t" "$real_x/$t"; do
    [ -f "$f" ] || fail "$t was not generated"
    has_one_trailing_newline "$f" "generated target $f"
    has "$f" 'Generated by bin/pln-generate' "$f carries no generated-by banner"
    hasnt "$f" 'not built yet' "$f still holds the placeholder text"
    for d in 'pln:include' 'pln:only' 'pln:endonly' '{{'; do
      hasnt "$f" "$d" "unconsumed '$d' left in $f"
    done
  done

  # Claude mechanics that must never reach a Codex build.
  for term in Workflow PushNotification ToolSearch resumeFromRunId agentType \
    CLAUDE_SKILL_DIR 'Skill tool'; do
    hasnt "$real_x/$t" "$term" "'$term' leaked into the codex build of $t"
  done

  # Codex mechanics that must never reach a Claude build. `codex exec` itself is
  # not on this list: pln-pr's opt-in cross-model review pass calls it on Claude
  # too, deliberately and read-only.
  for term in pln-codex-agent CODEX_HOME 'codex exec resume' workspace-write; do
    hasnt "$real_c/$t" "$term" "'$term' leaked into the claude build of $t"
  done
done <<< "$targets"

# Each build must actually carry its own host's spawn mechanism, or the absence
# checks above would pass on an empty file.
has "$real_c/SKILL.md" 'Workflow' "the claude build has no Workflow mechanics"
has "$real_x/SKILL.md" 'pln-codex-agent' "the codex build has no Codex agent mechanics"
for host_out in "$real_c" "$real_x"; do
  host_out="$(cd "$host_out" && pwd -P)"
  simplify="$host_out/pln-simplify/SKILL.md"
  has "$simplify" 'name: pln-simplify' 'pln-simplify frontmatter name/path disagree'
  has "$simplify" 'architecture decluttering' 'pln-simplify trigger metadata lost natural-language requests'
  has "$simplify" 'nothing worth changing' 'pln-simplify lost the valid clean-assessment outcome'
  has "$simplify" "$host_out/SKILL.md" 'pln-simplify duplicated the root lifecycle router'
  has "$simplify" 'phases/pln/implementation.md' 'pln-simplify duplicated the implementation lifecycle'
  has "$simplify" 'phases/pln/blocker.md' 'pln-simplify duplicated blocker handling'
  has "$simplify" 'phases/pln-simplify/map-synthesize.md' 'pln-simplify lost its mapping specialization'
  has "$simplify" 'phases/pln-simplify/verify-record.md' 'pln-simplify lost success recording'
  behavior_owner="$host_out/src/workers/behavior-preservation.md"
  has "$simplify" "$behavior_owner" 'pln-simplify lost the absolute installed behavior-preservation owner'
  has "$simplify" 'complete canonical `Safety disposition` is `admit`' \
    'pln-simplify lost its canonical pre-outline admission boundary'
  has "$simplify" 'every required conjunct is `pass`' \
    'pln-simplify admits an incompletely proven simplification'
  has "$simplify" 'Missing, unknown, incomplete, malformed, or non-`admit` proof retains the surface.' \
    'pln-simplify lost its fail-closed retention rule'
  has "$simplify" 'If no candidate clears that gate, `nothing worth changing` is a successful outcome.' \
    'pln-simplify lost its no-churn success outcome'
  hasnt "$simplify" '- Baseline suite/outcome:' \
    'pln-simplify duplicated the detailed behavior-preservation policy'
  appears_before "$simplify" '## Simplification admission gate' '## Phase router' \
    'pln-simplify does not load the admission gate before phase routing'
done
has "$real_c/phases/pln/implementation.md" 'commit owner: coordinator' \
  "the claude build lost coordinator-owned item checkpoints"
has "$real_x/phases/pln/implementation.md" 'commit owner: coordinator' \
  "the codex build lost coordinator-owned item commits"

# Native orchestration contracts are deliberately tested by current surface,
# not by historical feature flags or tool names. Claude's sequential item loop
# needs an addressable background Agent so a blocker can continue through
# SendMessage; Workflow stays for true fan-out. Codex continuation starts a new
# turn on the same idle agent with followup_task. Nested CLI helpers remain only
# as the old/disabled-host fallback and the cross-provider peer boundary.
has "$real_c/phases/pln/implementation.md" 'directly addressable Agents rather than Workflow' \
  "the claude build does not use addressable background Agents for item work"
has "$real_c/phases/pln/implementation.md" 'SendMessage' \
  "the claude build lost native blocker continuation"
has "$real_c/phases/pln-pr/review.md" 'pipeline(' \
  "the claude build lost current Workflow fan-out mechanics"
has "$real_x/phases/pln/implementation.md" 'followup_task' \
  "the codex build lost current native blocker continuation"
has "$real_x/SKILL.md" 'send_message' \
  "the codex build lost current running-agent steering"
for f in "$real_x/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" 'A quiet `wait_agent` timeout is not evidence that the child is still running' \
    "$f does not require mailbox reconciliation after quiet waits"
  has "$f" 'A child completion cannot start a new coordinator turn after you send the final response' \
    "$f does not explain why a running coordinator may not end its turn"
  has "$f" 'explicitly asks for persistence across turns' \
    "$f does not recognize an explicit durable-goal request"
  has "$f" '`create_goal`' \
    "$f does not use the native durable goal when it is exposed"
  has "$f" 'the manifest and wait loop remain the fallback' \
    "$f lets a missing goal tool become a user-facing blocker"
done
for f in "$real_c/SKILL.md" "$real_c/pln-pr/SKILL.md"; do
  hasnt "$f" 'create_goal' "$f received Codex-only durable-goal mechanics"
  has "$f" 'Never launch idle Bash merely to keep the parent turn open' \
    "$f permits synthetic shell keepalives while native Claude work runs"
  has "$f" 'run the Agent or Workflow in the foreground or sequence the work' \
    "$f has no native fallback when background work cannot be awaited"
  has "$f" 'do not synthesize a shell keepalive' \
    "$f can still invent an idle wait loop"
done
for f in "$real_x/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  hasnt "$f" 'Never launch idle Bash merely to keep the parent turn open' \
    "$f received Claude-specific waiting mechanics"
done

# Every recursively loaded phase carries one shared terminal-state invariant.
# Native host activity is the progress surface; status prose never detaches
# accepted work into a future turn. Keeping this in the phase contracts avoids
# bloating the thin routers while covering /pln and /pln-pr on both hosts.
# The loop covers all 26 files the fragment reaches, /pln-simplify's two phases
# included: a clause added here has to be true in every skill it lands in, and
# leaving one skill out of the loop is how a clause ships unenforced there.
lifecycle_files=0
for f in "$real_c"/phases/pln/*.md "$real_x"/phases/pln/*.md \
  "$real_c"/phases/pln-pr/*.md "$real_x"/phases/pln-pr/*.md \
  "$real_c"/phases/pln-simplify/*.md "$real_x"/phases/pln-simplify/*.md; do
  has "$f" 'Host-native activity is the progress surface' \
    "$f does not prefer the host activity UI over chat heartbeats"
  has "$f" 'Before any final response, run the terminal-state audit' \
    "$f has no shared pre-final reconciliation boundary"
  has "$f" 'A status update is commentary, never a terminal response' \
    "$f can still end a turn by describing nonterminal work"
  has "$f" 'peer subprocess' \
    "$f does not account for an in-flight peer at the terminal boundary"
  # A decided-but-unperformed hand-off to another skill is nonterminal work.
  # Phrased with no skill and no plan field named, because this fragment lands
  # in all three skills and the clause has to be true in every one of them.
  has "$f" 'a hand-off to another skill that durable state records as decided but not yet performed' \
    "$f lets a turn end on a hand-off that durable state says was never made"
  [ "$(grep -cF '## Active-turn lifecycle' "$f")" = "1" ] \
    || fail "$f does not carry exactly one shared active-turn lifecycle"
  lifecycle_files=$((lifecycle_files + 1))
done
[ "$lifecycle_files" = "26" ] \
  || fail "the active-turn lifecycle loop read $lifecycle_files files, expected 26"

# A Codex CI watch must remain attached to the current native turn through a
# resumable exec session. A disowned process recreates the exact invisible-work
# failure that the parent-turn contract prevents.
codex_watch="$real_x/phases/pln-pr/ship-watch.md"
has "$codex_watch" 'resumable exec session' \
  'the Codex CI watch does not use a native tracked command session'
has "$codex_watch" 'keep the same parent turn active' \
  'the Codex CI watch can still end its parent turn while checks run'
hasnt "$codex_watch" '& disown' \
  'the Codex CI watch still detaches from the native lifecycle'
hasnt "$codex_watch" 'Whenever this step next gets a turn' \
  'the Codex CI watch still relies on a future user turn for recovery'
has "$real_c/phases/pln-pr/ship-watch.md" 'keep the same parent turn active' \
  'the Claude CI monitor can still be mistaken for detached work'

has "$real_x/phases/pln/implementation.md" 'pln-scheduler finish-check' \
  "the codex implementation phase has no manifest-backed finish gate"
has "$real_x/phases/pln/implementation.md" '`list_agents` after every quiet timeout' \
  "the codex implementation phase can miss a completion between waits"
has "$real_x/phases/pln/implementation.md" 'Never send a final response from `Phase: implementation`' \
  "the codex implementation phase can still end while work is active"
for f in "$real_c/SKILL.md" "$real_c/pln-pr/SKILL.md"; do
  hasnt "$f" 'resumeFromRunId' "$f still uses the removed Workflow resume input"
  hasnt "$f" 'JSON.parse' "$f still treats Workflow args as a string"
  hasnt "$f" 'agentType' "$f still uses the historical Workflow agent option"
done
for f in "$real_x/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  hasnt "$f" 'resume_agent' "$f still names the historical Codex resume tool"
  hasnt "$f" 'send_input' "$f still names the historical Codex input tool"
  hasnt "$f" 'close_agent' "$f still names the historical Codex close tool"
  hasnt "$f" 'multi_agent_v2' "$f still pins a superseded Codex feature generation"
  hasnt "$f" 'Pin to V1' "$f still pins Codex multi-agent V1"
done
has "$real_c/phases/pln-pr/fix.md" 'coordinator stages explicit paths and commits each completed cluster' \
  "the claude fix fan-out has no executable commit ownership"
has "$real_x/phases/pln-pr/review.md" 'Start independent slots concurrently' \
  "the codex build does not use native concurrency for independent review slots"
has "$real_x/phases/pln-pr/review.md" 'before entering the shared `wait_agent` mailbox loop' \
  "the codex review invocation still serializes native independent slots"
has "$real_x/phases/pln-pr/review.md" 'nested CLI processes share the login boundary' \
  "the codex build lost fallback-only serialization"

# A regression ceiling on the always-resident coordinator prompt, not a target.
# The router is the one file a run holds for its whole length; phase files
# rotate in and out beside it, and the worker-owned contracts below are
# deliberately outside it. So this caps accretion where accretion is paid for
# on every turn, and hitting it is meant to send content into a phase file or
# out of the build rather than to move the number.
#
# It governs the smaller half of what a phase actually holds: `finish-ship.md`
# is larger than this ceiling and `outline.md` is close to it, both uncapped,
# so a phase carries roughly twice this figure. That is a known gap, recorded
# here rather than left for the next reader to rediscover — and not an argument
# for raising the ceiling, which is the only thing currently holding the
# resident half down.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  bytes="$(LC_ALL=C wc -c < "$f")"
  bytes="${bytes//[[:space:]]/}"
  [ "$bytes" -le 60000 ] \
    || fail "$f is $bytes bytes; phase router ceiling is 60000"
done

# The public skills are routers. Every detailed phase is generated one level
# below phases/, carries only its host's mechanics, and is addressed by the
# absolute output root baked into the router at generation time.
pln_phases='outline interview review-approval implementation blocker finish-ship'
pr_phases='scope-baseline review fix blocker ship-watch'
for host_out in "$real_c" "$real_x"; do
  host_out="$(cd "$host_out" && pwd -P)"
  router="$host_out/SKILL.md"
  pr_router="$host_out/pln-pr/SKILL.md"
  for phase in $pln_phases; do
    phase_file="$host_out/phases/pln/$phase.md"
    [ -s "$phase_file" ] || fail "missing /pln phase $phase"
    has "$router" "$phase_file" "the /pln router does not use the absolute $phase path"
  done
  for phase in $pr_phases; do
    phase_file="$host_out/phases/pln-pr/$phase.md"
    [ -s "$phase_file" ] || fail "missing /pln-pr phase $phase"
    has "$pr_router" "$phase_file" "the /pln-pr router does not use the absolute $phase path"
  done
done

# Always-active invariants stay in the routers; phase details do not leak back
# into them. First actions, cursor transitions, recovery, and conflict handling
# are explicit state-machine contracts rather than remembered sequencing.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  has "$f" 'Initial outline checkpoint is mandatory' "$f lost the outline invariant"
  has "$f" 'Master-plan adoption is mandatory' "$f lost the adoption invariant"
  has "$f" 'Auto is not advance authorization' "$f lets auto imply advance authorization"
  has "$f" 'grants neither outline-checkpoint confirmation nor master-plan adoption' \
    "$f does not define the narrow meaning of auto mode"
  has "$f" 'No inline feature work before adoption' "$f lost the no-inline invariant"
  has "$f" "before the phase's first action" "$f does not require first-action phase loading"
  has "$f" 'write durable state first, then advance `Phase`, then read the new phase file' \
    "$f lost write-then-advance semantics"
  has "$f" 'fail closed' "$f lost conflict-safe restart behavior"
  hasnt "$f" '### Step 3. Interview phase' "$f still embeds the interview phase"
  hasnt "$f" '### Step 5. Implementation phase' "$f still embeds the implementation phase"
done
for f in "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" "before the phase's first action" "$f does not require first-action phase loading"
  has "$f" 'write durable state first, then advance `Phase`, then read the new phase file' \
    "$f lost write-then-advance semantics"
  has "$f" 'fail closed' "$f lost conflict-safe restart behavior"
  hasnt "$f" '### Step 3. Review army' "$f still embeds the review phase"
  hasnt "$f" '### Step 4. Fix pass' "$f still embeds the fix phase"
done

# Invariants and native mechanics each have one generated home.
has "$real_c/phases/pln/implementation.md" 'directly addressable Agents rather than Workflow' \
  "the Claude implementation phase lost item 2 native mechanics"
has "$real_x/phases/pln/implementation.md" 'followup_task' \
  "the Codex implementation phase lost item 2 native mechanics"
for f in "$real_c/phases/pln/implementation.md" "$real_x/phases/pln/implementation.md"; do
  has "$f" 'run-manifest.tsv' "$f lost durable execution state"
  # Same-context reuse is still bounded — by where the work stops being the
  # same work, which is what every other boundary in that sentence already is.
  has "$f" 'A cohort ends where the work stops being the same work' \
    "$f lost bounded same-context reuse"
  hasnt "$f" 'provisional cohort cap is three' \
    "$f still bounds a cohort by an unexplained count"
  # Linear execution, in the tree the run was launched in.
  has "$f" 'Items run one at a time, in the working tree the coordinator was given' \
    "$f no longer runs items serially in the given tree"
  has "$f" 'no worktree for the coordinator to create' \
    "$f still lets the coordinator hand a worker a bare checkout"
  has "$f" 'no worker ever builds one' \
    "$f does not stop a worker provisioning its own environment"
  has "$f" 'Whoever moves the tree re-syncs it' \
    "$f leaves a lockfile change with no owner to reconcile it"
  has "$f" 'Unknown dependencies or leases serialize' "$f no longer fails closed on scheduling uncertainty"
  has "$f" 'coordinator alone updates `PLAN.md`' "$f lets item workers race the plan ledger"
done
has "$real_c/phases/pln/implementation.md" 'isolation: "worktree"' \
  'the Claude implementation phase lost native worktree isolation'
has "$real_x/phases/pln/implementation.md" 'git worktree add --detach' \
  'the Codex implementation phase lost orchestrator-created worktrees'
has "$real_c/phases/pln-pr/fix.md" 'coordinator stages explicit paths and commits each completed cluster' \
  "the Claude fix phase lost coordinator commit ownership"
has "$real_x/phases/pln-pr/review.md" 'Start independent slots concurrently' \
  "the Codex fix phase lost native concurrency semantics"
for f in "$real_c/phases/pln-pr/fix.md" "$real_x/phases/pln-pr/fix.md"; do
  has "$f" 'fix-manifest.tsv' "$f lost dependency-aware fix scheduling"
  has "$f" 'cohorts/context reuse are forbidden' "$f may reuse a PR fix worker across clusters"
  has "$f" 'workers touch neither git nor `REVIEW.md`' "$f lets fix workers race shared ledgers"
done

# Repository discovery is shared planning discipline: both coordinators must
# delegate it, while the detailed worker contracts remain outside the generated
# coordinator prompt.
for host_out in "$real_c" "$real_x"; do
  f="$host_out/SKILL.md"
  outline_file="$host_out/phases/pln/outline.md"
  review_file_peer="$host_out/phases/pln/review-approval.md"
  interview_file="$host_out/phases/pln/interview.md"
  has "$f" '## Coordinator context firewall' "$f lost the shared context firewall"
  has "$outline_file" 'src/workers/preflight-research.md' "$outline_file does not mandate a pre-flight research worker"
  has "$outline_file" '8192-byte ceiling' "$outline_file lost the pre-flight envelope budget"
  has "$interview_file" 'src/workers/interview-research.md' "$interview_file does not mandate per-item research"
  # The all-items-first shape, in the words that replaced the ambiguous
  # "Before the first proposal for every active item".
  has "$interview_file" 'Every active item is researched before the walk begins' \
    "$interview_file makes per-item research optional"
  has "$interview_file" 'decision-record-query mode' "$interview_file lost query-scoped prior-decision checks"
  has "$outline_file" '.git/info/exclude' "$outline_file does not keep local plans out of .gitignore"
  has "$outline_file" 'Outside a git worktree' "$outline_file does not allocate an external non-git run directory"
  hasnt "$f" 'WORKER_ONLY_SENTINEL_' "$f embedded worker-only runtime instructions"
  has "$outline_file" 'outside one, the external temporary run directory allocated in Step 1' \
    "$outline_file contradicts pre-flight's non-git plan location"
  # The named-location leg sits above both defaults: a project that keeps plans
  # outside the repository on purpose otherwise reads as "not ./plans/" and lands
  # in the temporary directory, which is the one place the work is least safe.
  # A same-model substitution in the adversarial slot is a loss of coverage, so
  # it is reported in the turn rather than only in the plan file nobody re-reads.
  has "$review_file_peer" 'A substitution in the adversarial slot is said out loud, in the turn it happens' \
    "$review_file_peer lets a peer substitution stay silent"
  ship_file="$host_out/phases/pln-pr/ship-watch.md"
  scope_file="$host_out/phases/pln-pr/scope-baseline.md"
  # Local verification buys the static checks; the behavior suite is CI's, which
  # parallelizes it across jobs a single machine cannot match.
  has "$scope_file" 'Split what you find into static checks and the behavior suite' \
    "$scope_file lost the two-tier gauntlet split"
  has "$ship_file" 'The static checks always run here. The behavior suite runs only under an exception' \
    "$ship_file lets the final gauntlet run the behavior suite unconditionally"
  has "$ship_file" 'The behavior suite does not re-run here' \
    "$ship_file re-runs the behavior suite after a CI fix"
  has "$ship_file" 'Running the whole suite locally has exactly two justifications' \
    "$ship_file lost the bar on running the whole suite locally"
  has "$ship_file" "The project's own instructions say to" \
    "$ship_file dropped the project's instructions as the whole-suite escape hatch"
  has "$ship_file" 'There is no CI that will run it' \
    "$ship_file lost the no-CI justification, where the local run is the only run"
  # Touching tests buys those tests, never the suite — feature specs least of all.
  has "$ship_file" 'argues for **targeted tests instead**' \
    "$ship_file lets a test-touching change escalate to the whole suite"
  has "$ship_file" 'Changing four specs is a reason to run four specs' \
    "$ship_file lost the targeted-run rule in concrete terms"
  hasnt "$ship_file" 'not exactly subsumed by the required CI checks before pushing' \
    "$ship_file kept the subsumption bar that never fired"
  review_file="$host_out/phases/pln/review-approval.md"
  # A bounded re-review bounds its roster too: the tier is a property of the
  # plan, but a round's readers come from what the rewritten items carry.
  has "$review_file" 'The roster is bounded by the same change the items are' \
    "$review_file lets a one-item rewrite re-run the whole tier roster"
  has "$review_file" 'The broad reader always runs' \
    "$review_file lost the reader a bounded re-review always keeps"
  has "$review_file" 'never on the tier or on the first pass' \
    "$review_file lets a bounded roster shrink the tier or the first review pass"
  has "$outline_file" "A location the project's own instructions name wins over both defaults" \
    "$outline_file lost the instruction-named plan location"
  has "$outline_file" 'In a git worktree, and with no such location named' \
    "$outline_file lets the worktree default outrank an instruction-named plan location"
  has "$outline_file" 'Outside a git worktree, and with no such location named' \
    "$outline_file lets the temporary directory outrank an instruction-named plan location"
done
hasnt "$real_c/SKILL.md" "Codex's native path" \
  "the claude build explains its blocker mechanics through the other host"
hasnt "$real_x/SKILL.md" "Claude path's behavior" \
  "the codex build explains its blocker mechanics through the other host"
hasnt "$real_x/SKILL.md" 'where Claude was launched' \
  "the codex build carries a Claude-specific plan-path rule"

# The Style section is one shared source read by both skills. Every build of
# both targets carries it whole, host voice fragment included — a rule added to
# it must never reach one skill and not the other.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" '## Style' "$f carries no Style section"
  has "$f" '### Message shape' "$f lost the shared message shapes"
  has "$f" '### Conversational voice' "$f lost the host voice fragment inside Style"
  has "$f" '### Echoing recorded decisions' "$f lost the shared formatting rules"
  has "$f" 'never an action not yet taken' "$f lost the shared forward-tense rule"
done

for host_out in "$real_c" "$real_x"; do
  host_out="$(cd "$host_out" && pwd -P)"
  router="$host_out/pln-simplify/SKILL.md"
  for phase in map-synthesize verify-record; do
    phase_file="$host_out/phases/pln-simplify/$phase.md"
    [ -s "$phase_file" ] || fail "missing /pln-simplify phase $phase"
    has "$router" "$phase_file" "the /pln-simplify router does not use the absolute $phase path"
  done
  has "$host_out/phases/pln-simplify/map-synthesize.md" "$host_out/phases/pln/outline.md" \
    'pln-simplify duplicated plan placement or the outline checkpoint'
  has "$router" 'bin/pln-simplify status --repo <root>' \
    'pln-simplify router lost its cadence-status consumer'
  verify_record="$host_out/phases/pln-simplify/verify-record.md"
  has "$verify_record" 'unpublished candidate ref' \
    'pln-simplify verification no longer isolates failed candidates'
  has "$verify_record" 'candidate HEAD still equals the tested commit' \
    'pln-simplify verification lost its unchanged-branch integration boundary'
  has "$verify_record" 'bin/pln-simplify marker' \
    'pln-simplify verification lost deterministic marker construction'
done

# The to-do-location flow is one source per host, included by both skills — a
# follow-up recorded by one and only offered by the other would be the same bug
# the write-by-default rule exists to fix. The global instructions file it reads
# is the one host-specific part, so each build must name its own path.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md" "$real_c/phases/pln-pr/ship-watch.md" "$real_x/phases/pln-pr/ship-watch.md"; do
  has "$f" 'The to-do-location flow' "$f lost the to-do-location flow"
  has "$f" 'without asking' "$f does not record follow-ups without asking"
done
# The end-of-run sweep is the other half of that flow, shared the same way: a
# close that never looks at the run's own record reports whatever it happens to
# remember, and the to-do-location flow then has nothing to write.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md" "$real_c/phases/pln-pr/ship-watch.md" "$real_x/phases/pln-pr/ship-watch.md"; do
  has "$f" "Sweep the run's own record" "$f lost the end-of-run sweep"
  has "$f" 'nothing outstanding says so' "$f does not report an empty sweep"
done

has "$real_c/phases/pln/finish-ship.md" '~/.claude/CLAUDE.md' "the claude build reads no global instructions file"
has "$real_x/phases/pln/finish-ship.md" '$CODEX_HOME/AGENTS.md' "the codex build reads no global instructions file"

# The flow's own ship clause. It used to read "in `/pln`, the Step 8 ship ask is
# a separate turn" — true of the branch that asks, false of the two PR-bearing
# branches, which contain no ask at all, and read as a turn boundary in front of
# every hand-off. The replacement names what the ask is separate from and states
# the PR-bearing case outright.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md" \
  "$real_c/phases/pln-pr/ship-watch.md" "$real_x/phases/pln-pr/ship-watch.md"; do
  # The command token is the host's own: `/pln` on Claude Code, `$pln` on Codex.
  case "$f" in *real-codex*) pcmd='$pln' ;; *) pcmd='/pln' ;; esac
  has "$f" "In \`$pcmd\` the only ship ask is the one the \`implement only\`, absent and legacy branches make." \
    "$f does not say which branch the ship ask belongs to"
  has "$f" 'there is no ask at all: the hand-off is an action, not a question' \
    "$f still implies the PR-bearing branches ask before handing off"
  hasnt "$f" 'the Step 8 ship ask is a separate turn' \
    "$f still puts a turn boundary in front of every hand-off"
done
# And no bare step number in the fragment itself: it lands inside /pln-pr too,
# where Step 8 is a different step entirely, so "Step 8" there names the wrong
# one in two of the four generated targets. Asserted on the sources, because the
# generated files legitimately carry their own Step 8 headings.
for f in "$REPO_DIR/src/hosts/claude/todo-location.md" "$REPO_DIR/src/hosts/codex/todo-location.md"; do
  hasnt "$f" 'Step 8' "$f names a bare Step 8 that resolves to the wrong step inside /pln-pr"
done
# The two host copies differ in exactly one line — line 1, the host's own
# instruction-file paths. An edit that lands in one and not the other makes the
# two skills disagree about the same flow.
diff <(tail -n +2 "$REPO_DIR/src/hosts/claude/todo-location.md") \
     <(tail -n +2 "$REPO_DIR/src/hosts/codex/todo-location.md") >/dev/null \
  || fail "the two todo-location fragments have drifted apart below line 1"

# The same presupposition sat a second time in the host-neutral core, where one
# edit covers both hosts.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md"; do
  has "$f" 'Under either PR-bearing value there is no ask to be separate from' \
    "$f still asserts a Step 8 ask on the paths that have none"
  hasnt "$f" 'never folded into Step 8' "$f still folds the to-do flow into an ask that may not exist"
done

# The ship hand-off fires from durable state rather than from a position in the
# step sequence: a to-do question, a compaction, a restart or an interruption
# all leave a positional trigger behind with the PR still unopened. Both bounds
# are asserted — without the start bound a resumed run ships past its own
# verification, and without the end bound every turn of the review cycle the
# hand-off launched is told to hand off again.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md"; do
  has "$f" 'False until Steps 6 and 7 are recorded done' \
    "$f has no start bound on the ship hand-off"
  has "$f" 'True from there until PR identity is durable' \
    "$f has no end bound on the ship hand-off"
  has "$f" 'the hand-off is the first action of the turn' \
    "$f lets a message go out in place of the hand-off"
  hasnt "$f" 'Hand off immediately at the end of Step 7' \
    "$f still triggers the hand-off from a position in the step sequence"
done

# ─── the to-do-list close, and the declaration it reads ───────────────────────
# Step 7's to-do-list close has the same defect the hand-off above was repaired for,
# and one the hand-off does not: it leaves no durable mark, so a close that
# never ran reads exactly like one that did. Its trigger is therefore a
# condition over durable state with both bounds and a turn rule of its own —
# and the close runs *before* the wrap-up message, the opposite of the hand-off.
#
# Each of the last four assertions pins a paragraph a later edit could delete
# with every other assertion here still passing: the archive-falsification read,
# the bound's subject noun, the refusal state, and the third state where a
# declared id carries no claim result at all.
for f in "$real_c/phases/pln/finish-ship.md" "$real_x/phases/pln/finish-ship.md"; do
  has "$f" 'False until the sweep has filed' \
    "$f has no start bound on the to-do-list close"
  has "$f" 'True from there until every id this run claimed carries an outcome' \
    "$f has no end bound on the to-do-list close"
  has "$f" "the close is the turn's first action and precedes the wrap-up message" \
    "$f lets the wrap-up message go out ahead of the to-do-list close"
  hasnt "$f" 'Close the to-do list at the end of Step 7' \
    "$f still triggers the to-do-list close from a position in the step sequence"
  # The close has to survive a restart, and the hand-off must not fire on a turn
  # where it never ran: one list entry and one clause, in two other passages.
  has "$f" 'Persist verification results, follow-ups, the to-do-list close, Ship choice, PR base' \
    "$f does not persist the to-do-list close before reporting completion"
  has "$f" 'the to-do-list close below has run' \
    "$f lets the ship hand-off fire on a turn where the close never ran"
  # A plan that lies about its own id is the one direction the to-do list can
  # falsify: a genuinely archived record is gone from items/, so its presence there
  # under this run's holder contradicts the plan's prose.
  has "$f" 'Also true while any id the plan records as archived still has a live record' \
    "$f does not falsify a plan's archive claim against the live to-do list"
  # The bound is stated over the claimed set, never the declared set — the two
  # are the same extension only until a refusal, and a refused id must not hold
  # the run short of Phase: complete.
  has "$f" "The claimed set is the ids the dashboard's \`## To-do items\` section records as claimed." \
    "$f does not name the claimed set as the to-do-list close's subject"
  hasnt "$f" 'until every declared id carries' \
    "$f states the to-do-list close's bound over the declared set"
  # Three states, not two: recorded success, recorded refusal, and no record at
  # all. The third is reachable — the helper writes the holder under its lock
  # and returns before the plan-side write — and nothing recovers it.
  has "$f" 'An id whose record there is a refusal' \
    "$f does not exempt a refused id from the to-do-list close's bound"
  has "$f" 'An id carrying no recorded claim result at all has not been shown to be outside it either' \
    "$f lets a declared id with no recorded claim result reach Phase: complete"
  has "$f" 'Neither state is read off the absence of the other.' \
    "$f infers a refusal from a missing claim result, or the reverse"
done

# The declaration the close reads is written in three phases, and only one of
# them is reached by the dashboard-skeleton section list further down. The other
# two land here: the write ordered at adoption, and the claim-time result write
# that is the close's only durable input. Delete either and every assertion
# above still passes while the close gates on a field nothing fills in.
for f in "$real_c/phases/pln/outline.md" "$real_x/phases/pln/outline.md"; do
  has "$f" '- **To-do items** — the ids from the project to-do list this run takes' \
    "$f does not define the To-do items field under Tracker contents"
  has "$f" "amended at claim time with each id's claim result, and amended again at the close" \
    "$f defines To-do items as set once, like Ship, rather than amended three times"
done
for f in "$real_c/phases/pln/review-approval.md" "$real_x/phases/pln/review-approval.md"; do
  has "$f" '`- none taken` when it takes none' \
    "$f does not give a run taking no to-do items an explicit none value to write"
  # The create-when-missing clause, not a bare Record line: it is the section's
  # only origin for a plan upgrading into the field, and what narrows the
  # close's absent-section escape to plans adopted before the field existed.
  has "$f" 'Create the section above `## Ship` when the plan does not carry one.' \
    "$f does not create the To-do items section when the plan carries none"
  has "$f" 'Adoption is not recorded while the section still reads `- (not yet declared)`' \
    "$f records adoption with the To-do items field left unanswered"
done
for f in "$real_c/phases/pln/implementation.md" "$real_x/phases/pln/implementation.md"; do
  has "$f" "The dashboard's \`## To-do items\` section names what this run takes" \
    "$f does not read the declared set from the dashboard field"
  # todo-format is not included into this file, so this clause is the claim
  # rule's only statement anywhere in the implementation phase for a plan
  # adopted before the field existed.
  has "$f" 'A plan adopted before that section existed carries no field to read; declare the items in this turn and claim them the same way.' \
    "$f leaves the per-item claim rule unstated for a plan carrying no field"
  has "$f" "Write each attempt's result back beside its declared id as the attempt is made, not later" \
    "$f does not anchor the claim-result write to the attempt"
  has "$f" 'the holder from `HELD_BY`, or, when the refusal names no holder, the collision the check reported' \
    "$f records a refusal in only one of the helper's two refusal forms"
done

# ─── a plan directory outside the repository gets a writable artifact root ───
# A native subagent inherits the coordinator's write boundary, and neither host
# extends it for a child. So a project whose instructions put plans in
# ~/Documents left native reviewers able to read the plan and unable to write
# beside it, and the run improvised a location per worker.
for f in "$real_c/phases/pln/outline.md" "$real_x/phases/pln/outline.md"; do
  has "$f" 'not writable by a worker, so allocate an artifact directory that is' \
    "$f sends workers at a plan directory they cannot write"
  has "$f" 'pln-artifacts-' "$f names no writable artifact root"
  has "$f" 'the plan directory remains the record' \
    "$f lets the artifact directory hold something durable"
done
for f in "$real_c/phases/pln/implementation.md" "$real_x/phases/pln/implementation.md"; do
  has "$f" 'the directory the worker could actually write' \
    "$f validates envelopes against a root the worker may not have reached"
done

# ─── an optional review field is omitted, never abbreviated ──────────────────
for f in "$real_c/phases/pln-pr/review.md" "$real_x/phases/pln-pr/review.md"; do
  has "$f" 'Omit either object entirely rather than emitting a partial one' \
    "$f lets a partial optional object take its whole artifact down"
done

# ─── the ask lane is about who can answer, not only what is at stake ─────────
# A real /pln run put its own verification bookkeeping to the user as an a)/b)/c)
# question — whether a carried-forward shell check should be annotated, edited or
# dropped — and got back "I don't understand any of this." The fork test asked
# whether the consequence was material, which it looked, and never whether the
# user was better placed to answer than the agent, which they were not.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  has "$f" "rules out this run's own apparatus" \
    "$f still lets a question about the run's own bookkeeping reach the user"
  has "$f" 'they cannot answer it better than you can' \
    "$f does not test who is better placed to answer"
  has "$f" "I don't understand any of this" \
    "$f lost the strongest tell that the ask lane is miscalibrated"
done

# ─── a wait with no news produces no message ─────────────────────────────────
# The lifecycle fragment already forbade manufactured heartbeats, and a real run
# sent 77 of them at a median 1.1 minutes apart anyway — each a full turn over
# the whole session context to report that nothing had happened. A prohibition
# with no test for the case that triggers it is a prohibition that loses.
for f in "$real_c/phases/pln/implementation.md" "$real_x/phases/pln/implementation.md" \
         "$real_c/phases/pln/interview.md" "$real_x/phases/pln-pr/review.md"; do
  has "$f" 'A wait that returns nothing new earns no message' \
    "$f lets a quiet wait produce a status message"
  has "$f" 'wait again' "$f does not say what to do instead of narrating"
done

# ─── how wide the interview's research fan-out goes ───────────────────────────
# Item research is read-only and per-item independent, so it is dispatched in
# waves rather than one worker at a time. The width is a host fact — Claude Code
# admits 20 concurrent subagents, Codex caps spawned threads per session with a
# default that is documented two ways — so each build carries its own number and
# never the other's, and the shared reason lives in the core.
has "$real_c/phases/pln/interview.md" 'Wave width: up to 15 item workers at once' \
  "the claude build lost its own research fan-out width"
hasnt "$real_c/phases/pln/interview.md" 'up to 3 item workers' \
  "the claude build carries Codex's narrower research fan-out width"
has "$real_c/phases/pln/interview.md" 'CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS' \
  "the claude build does not honour a user-configured subagent cap"
has "$real_x/phases/pln/interview.md" 'Wave width: up to 3 item workers at once' \
  "the codex build lost its own research fan-out width"
hasnt "$real_x/phases/pln/interview.md" 'up to 15 item workers' \
  "the codex build carries Claude Code's wider research fan-out width"
has "$real_x/phases/pln/interview.md" 'max_concurrent_threads_per_session' \
  "the codex build does not honour a user-configured thread cap"
for f in "$real_c/phases/pln/interview.md" "$real_x/phases/pln/interview.md"; do
  has "$f" 'Dispatch the item workers together in waves, await the wave' \
    "$f does not dispatch item research concurrently"
  has "$f" 'is dispatched after the wave that raised it' \
    "$f does not keep a premise-changing follow-up worker after its wave"
done

# ─── a plan wider than one wave still asks its first question early ───────────
# The held-output rule releases when the work quiesces, and waves made "the
# work" bigger than the items the walk has reached: a plan needing four waves
# would hold every question until the last one landed, restoring the whole
# delay the waves were added to remove.
for f in "$real_c/phases/pln/interview.md" "$real_x/phases/pln/interview.md"; do
  has "$f" 'the walk begins when the first wave lands' \
    "$f waits for every wave before the walk begins"
  has "$f" 'does not hold back a question about an item already researched' \
    "$f lets a wave for unreached items hold back an answered item's question"
  has "$f" 'What is never split is a single item' \
    "$f does not keep one item's own research ahead of its own question"
  has "$f" 'Every active item is researched before the walk begins' \
    "$f no longer says plainly that research is all-items-first"
done

# The coordinator's pre-flight step may read the root instruction file that
# governs its own conduct. Forbidding that outright produced a rule the model
# correctly broke, in any repository whose AGENTS.md says to read CLAUDE.md.
for f in "$real_c/phases/pln/outline.md" "$real_x/phases/pln/outline.md"; do
  has "$f" 'The exception is the root instruction file that governs the coordinator' \
    "$f forbids the coordinator the instruction file that binds it"
  has "$f" 'reading *further* on the strength of what it found there' \
    "$f does not draw the line at exploring beyond the root instruction file"
done

# ─── how each host is told to invoke pln ──────────────────────────────────────
# Claude Code invokes a skill as a slash command; Codex has none, and invokes a
# skill by name with a `$` prefix, so `/pln` is an error there. A build that
# tells its own host the wrong token is wrong in the way that costs most: the
# Step 8 hand-off names the command the user is supposed to type next, and an
# explicit invocation the skill cannot recognize gets re-derived as an inferred
# one. So the four command names travel as `{{PLN_*_CMD}}` vars, and neither
# host's build may carry the other's spelling of any of them.
for f in "$real_c/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_c/pln-simplify/SKILL.md" \
         "$real_c/phases/pln/finish-ship.md" "$real_c/phases/pln-pr/ship-watch.md"; do
  has "$f" '`/pln' "$f does not carry Claude Code's slash-command spelling"
  hasnt "$f" '`$pln' "the claude build carries Codex's \$-prefixed spelling: $f"
done
for f in "$real_x/SKILL.md" "$real_x/pln-pr/SKILL.md" "$real_x/pln-simplify/SKILL.md" \
         "$real_x/phases/pln/finish-ship.md" "$real_x/phases/pln-pr/ship-watch.md"; do
  has "$f" '`$pln' "$f does not carry Codex's \$-prefixed spelling"
  hasnt "$f" '`/pln`' "the codex build tells Codex to type \`/pln\`, which errors there: $f"
  hasnt "$f" '`/pln-pr`' "the codex build tells Codex to type \`/pln-pr\`: $f"
  hasnt "$f" '`/pln-simplify`' "the codex build tells Codex to type \`/pln-simplify\`: $f"
  hasnt "$f" '`/pln <task>`' "the codex build tells Codex to type \`/pln <task>\`: $f"
done
# The router's own description is what a host reads when deciding to load the
# skill at all, so the trigger sentence carries the host's token too.
has "$real_c/SKILL.md" 'Trigger explicitly via `/pln <task>`' \
  "the claude router description does not name its own explicit invocation"
has "$real_x/SKILL.md" 'Trigger explicitly via `$pln <task>`' \
  "the codex router description does not name its own explicit invocation"

# ─── the project to-do list, and where its format is allowed to land ──────────
# One shared fragment, and its reach is a decision rather than an accident. The
# three cores that render or explain the list carry the whole format; every
# other core a door can fire in carries one sentence naming the helper, which
# fits where the fragment would not; and no router carries either, because the
# routers are always resident and the ceiling above is what pays for that.
#
# Anchored on the section heading and a whole sentence, never on `## Everything
# else` — the list's ungrouped catch-all heading is also ordinary prose in
# ship-watch, so that phrase alone proves nothing about which file it came from.
todo_marker='## The project to-do list'
todo_sentence='Work that is found and not done now reaches the to-do list'
door_pointer='is filed in the turn it is named'
for host_out in "$real_c" "$real_x"; do
  host_out="$(cd "$host_out" && pwd -P)"
  for rel in phases/pln/outline.md phases/pln/finish-ship.md phases/pln-pr/ship-watch.md; do
    has "$host_out/$rel" "$todo_marker" "$host_out/$rel lost the to-do-list format"
    has "$host_out/$rel" "$todo_sentence" "$host_out/$rel lost the list's standing invariant"
    # The whole precedence chain, stated in the one place that defines it. An
    # earlier wording named only date/undated/id, which skips the group level
    # `pln-todo` actually sorts on and reads as a contradiction of it — the
    # kind of drift only an assertion catches, since prose fails silently.
    has "$host_out/$rel" \
      'the flag, then the group, then date opened, then the items carrying no `opened` date, then `id`' \
      "$host_out/$rel does not state the index's full sort precedence"
  done
  # Every remaining core a door can fire in: the sentence, and not the format.
  for rel in phases/pln/interview.md phases/pln/implementation.md phases/pln/blocker.md \
    phases/pln/review-approval.md phases/pln-pr/scope-baseline.md phases/pln-pr/review.md \
    phases/pln-pr/fix.md phases/pln-pr/blocker.md phases/pln-simplify/map-synthesize.md; do
    has "$host_out/$rel" "$door_pointer" \
      "$host_out/$rel cannot file a follow-up named in the turn it is named"
    has "$host_out/$rel" 'bin/pln-todo add' "$host_out/$rel names no helper call to file with"
    hasnt "$host_out/$rel" "$todo_marker" "$host_out/$rel duplicated the whole to-do-list format"
  done
  hasnt "$host_out/phases/pln-simplify/verify-record.md" "$todo_marker" \
    "the to-do-list format reached a phase no door fires in"
  # Not in any router, on any host. The 60000-byte ceiling above is the reason
  # this is a rule and not a preference.
  for router in SKILL.md pln-pr/SKILL.md pln-simplify/SKILL.md; do
    hasnt "$host_out/$router" "$todo_marker" "$host_out/$router carries the to-do-list format"
    hasnt "$host_out/$router" "$todo_sentence" "$host_out/$router carries the list's intake rules"
  done
  # The helper is named through the absolute output root baked in at generation
  # time, never through {{SKILL_DIR}}: on Codex that substitutes to $_PLN_DIR, a
  # shell variable /pln-simplify's router never sets — so a bare SKILL_DIR would
  # break door 4 in the very skill this fragment brings into scope.
  todo_callers=0
  while IFS= read -r f; do
    has "$f" "$host_out/bin/pln-todo" \
      "$f names the to-do-list helper by an unresolved or relative path"
    hasnt "$f" '_PLN_DIR/bin/pln-todo' "$f reaches the to-do-list helper through a Codex shell variable"
    hasnt "$f" 'CLAUDE_SKILL_DIR}/bin/pln-todo' "$f reaches the to-do-list helper through a Claude variable"
    todo_callers=$((todo_callers + 1))
  done < <(grep -rlF 'bin/pln-todo' "$host_out")
  [ "$todo_callers" = "12" ] \
    || fail "$host_out names the to-do-list helper in $todo_callers files, expected 12"
  # The implementation phase's pre-message readiness check has the same hazard
  # and the same answer: the absolute output root, never {{SKILL_DIR}}, since
  # /pln-simplify routes into this phase document and never sets $_PLN_DIR.
  # Scoped to the `ready` invocation, because the snapshot/build/finish-check
  # calls in this file are deliberately SKILL_DIR-relative.
  has "$host_out/phases/pln/implementation.md" "$host_out/bin/pln-scheduler ready" \
    "$host_out/phases/pln/implementation.md names the readiness check by an unresolved or relative path"
  hasnt "$host_out/phases/pln/implementation.md" '_PLN_DIR/bin/pln-scheduler ready' \
    "$host_out/phases/pln/implementation.md reaches the readiness check through a Codex shell variable"
  hasnt "$host_out/phases/pln/implementation.md" 'CLAUDE_SKILL_DIR}/bin/pln-scheduler ready' \
    "$host_out/phases/pln/implementation.md reaches the readiness check through a Claude variable"
done

# The peer ladder is one shared source both skills read, and the property that
# matters is that neither carries probe logic of its own: every build of both
# targets reaches the peer through the same helper, behind the same one-time
# consent key.
for f in "$real_c/phases/pln/review-approval.md" "$real_x/phases/pln/review-approval.md" "$real_c/phases/pln-pr/review.md" "$real_x/phases/pln-pr/review.md"; do
  has "$f" '## Consulting a peer model' "$f carries no peer section"
  has "$f" 'pln-peer' "$f does not reach the peer through the picker"
  has "$f" 'peer_consent' "$f names no consent key in front of the peer"
done
for f in "$real_c/SKILL.md" "$real_x/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" '## Model and effort routing' "$f lost semantic model routing"
  has "$f" '`inherit`' "$f lost the ordinary inherited profile"
  has "$f" '`judgment`' "$f lost the judgment profile"
  has "$f" '`evidence`' "$f lost the bounded evidence profile"
  has "$f" 'actual profile, model, and effort' "$f does not require actual routing attribution"
  has "$f" 'always inherits the hosting model' "$f does not make judgment inheritance unconditional"
  hasnt "$f" 'ask whether to inherit for this run' "$f retains the late model-inheritance gate"
  hasnt "$f" 'frontier-capability floor' "$f still claims model names are a capability test"
  has "$f" 'Start-of-invocation readiness sweep' "$f lost the early configuration sweep"
  has "$f" 'before any repository research, phase action, or long-running dispatch' \
    "$f can defer predictable configuration until work is underway"
  has "$f" 'Never raise either configuration question later in the run' \
    "$f can still block an unattended run on late peer configuration"
  has "$f" 'Before every turn that waits for user input' \
    "$f does not notify before every user-input wait"
done
has "$real_c/SKILL.md" '`sonnet`' "the Claude build lost its economy alias"
hasnt "$real_c/SKILL.md" 'gpt-5.6-sol' "the Claude build contains Codex model mechanics"
has "$real_x/SKILL.md" '`gpt-5.6-luna`' "the Codex build lost its economy model"
hasnt "$real_x/SKILL.md" '`fable`' "the Codex build contains Claude model mechanics"
hasnt "$REPO_DIR/src/SKILL.core.md" 'gpt-5.6-sol' "the shared /pln core hardcodes an aging Codex model"
hasnt "$REPO_DIR/src/pln-pr/SKILL.core.md" 'gpt-5.6-sol' "the shared /pln-pr core hardcodes an aging Codex model"
# The line 1.15.0 shipped on the Codex side — that there is no second model to
# consult from here — was replaced, not kept: rung 2 reaches for `claude` from
# Codex exactly as it reaches for `codex` from Claude.
hasnt "$real_x/pln-pr/SKILL.md" 'no second one to consult' \
  "the codex build still says a peer cannot be consulted from this host"
for f in "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" 'Start-of-invocation readiness sweep' "$f lost the early PR configuration sweep"
  has "$f" 'Before every turn that waits for user input' "$f does not notify before every PR input wait"
done

# ─── the dashboard skeleton ───────────────────────────────────────────────────
# The skeleton in Step 2 is the shape every later step addresses items by: the
# number is the list's own marker so a client can reference it, and the status
# trails. Nothing else in either build pins it, so a row that drifts back to a
# checkbox — where the number is text nested inside a bullet, and some renderers
# relabel it a) b) c) — would ship silently. The sections are asserted here for
# the same reason: each is written by one step and read by another.
has "$real_c/phases/pln/outline.md" '1. <one-line summary> — ⬜ pending' \
  "the claude build's dashboard row is not number-first with a trailing status"
has "$real_x/phases/pln/outline.md" '1. <one-line summary> — ⬜ pending' \
  "the codex build's dashboard row is not number-first with a trailing status"
for f in "$real_c/phases/pln/outline.md" "$real_x/phases/pln/outline.md"; do
  hasnt "$f" '- [ ] 1.' "$f still writes the dashboard as checkbox bullets"
  has "$f" '5. <one-line summary> — 🚫 dropped' "$f lost a dashboard state from the skeleton"
  has "$f" 'Status legend: ⬜ pending · 🟦 in progress · ✅ done · ⏸ deferred · 🚫 dropped' \
    "$f lost the status legend, or its icons no longer match the rows"
  has "$f" 'Rows are never removed and numbers are never reused' \
    "$f does not say item numbers are permanent"
  for section in '## Status' '## Pre-flight findings' '## Open questions' '## Plan review' \
    '## To-do items' '## Ship' '## Reversals' '## Verification' '## Spinoffs' \
    '## Cross-item notes'; do
    has "$f" "$section" "$f lost '$section' from the dashboard skeleton"
  done

  # The outline is a turn boundary, not only a file shape. It gives the user a
  # cheap scope-editing pass before any item-level question or implementation,
  # and edits loop through the displayed dashboard until the current outline is
  # accepted. Delegated mode keeps the display but uses its advance adoption;
  # auto mode has no effect on this checkpoint.
  has "$f" "This checkpoint is the user's scope-editing surface" \
    "$f does not explain the initial outline checkpoint's purpose"
  has "$f" 'ask no item-level interview question in that turn, and perform no implementation' \
    "$f does not preserve the post-skeleton turn boundary"
  has "$f" 'update the skeleton before the interview starts, re-show the complete dashboard, and ask again' \
    "$f does not apply checkpoint edits before the interview"
  has "$f" 'In delegated mode there is nothing to ask: show the dashboard and go straight into Step 3' \
    "$f lost the delegated-mode outline display and advance adoption"
  has "$f" 'Auto mode is not advance authorization' \
    "$f lets auto mode bypass the initial outline checkpoint"
  has "$f" 'missing confirmation leaves `Phase: outline`' \
    "$f does not keep auto/normal runs durably in outline without confirmation"
  has "$f" 'do not infer confirmation from auto mode or start the interview, review, scheduling, or implementation' \
    "$f does not enumerate the forbidden pre-confirmation transitions"
done

# ─── the plan review, as skill text ───────────────────────────────────────────
# Step 3.5 keeps coordinator policy in the generated skill while the detailed
# reviewer and merge rubrics remain in installed worker contracts.
for f in "$real_c/phases/pln/review-approval.md" "$real_x/phases/pln/review-approval.md"; do
  has "$f" '### Step 3.5. Plan review' "$f lost the plan review step"
  has "$f" '## The plan review switch' "$f lost the plan review switch"
  has "$f" 'plan_review' "$f names no config key for the switch"
  has "$f" 'The size of the plan never does' "$f lost the rule that plan size changes nothing"
  has "$f" '## Plan review ownership' "$f lost review ownership policy"
  has "$f" 'src/workers/plan-review.md' "$f lost the reviewer contract pointer"
  has "$f" 'src/workers/plan-review-merge.md' "$f lost the merge contract pointer"
  has "$f" 'pln-build-review-brief' "$f no longer assembles one on-disk brief"
  has "$f" 'Never open raw findings in this context' "$f may read raw findings inline"
  has "$f" 'A finding on a user-made decision is protected from repair' \
    "$f lost coordinator-facing user-decision protection"
  has "$f" 'pln-assurance classify' "$f lost semantic assurance classification"
  has "$f" 'at most four pre-fix readers' "$f lost the R3 reader cap"
  has "$f" 'peer_egress' "$f lost the separate peer-egress policy"
  has "$f" 'without asking again' "$f does not explain that consent is a standing policy"
  hasnt "$f" '### Rejected' "$f embeds worker-only rejection detail"
  hasnt "$f" 'Judge by substance, never by phrasing' "$f embeds worker-only merge detail"
done

# Assurance is phase-local and risk-calibrated. Tiny critical diffs never take
# a shortcut, reviewers provide evidence state rather than self-scored
# confidence, and every reusable gauntlet is tied to an exact candidate.
for root in "$real_c" "$real_x"; do
  review="$root/phases/pln-pr/review.md"
  scope="$root/phases/pln-pr/scope-baseline.md"
  fix="$root/phases/pln-pr/fix.md"
  ship="$root/phases/pln-pr/ship-watch.md"
  finish="$root/phases/pln/finish-ship.md"
  has "$review" '### Step 3. Risk-calibrated review roster' "$review lost semantic assurance tiers"
  has "$review" 'at most four pre-fix readers' "$review lost the R3 pre-fix cap"
  has "$review" '"verified"|"unverified"' "$review lost evidence-state findings"
  has "$review" 'structural_evidence?' "$review lost backward-compatible structural evidence"
  has "$review" 'direct callers or consumers' "$review lost changed-responsibility consumer traversal"
  hasnt "$review" 'DIFF_LINES < 30' "$review retained the line-count shortcut"
  hasnt "$review" 'confidence: 1-10' "$review retained reviewer self-scoring"
  has "$fix" 'R1 narrowly verifies' "$fix lost tiered post-fix assurance"
  has "$fix" 'separate from the four-reader pre-fix cap' "$fix counts red team in the pre-fix roster"
  has "$fix" 'already-authorized repair work' "$fix asks permission for another repair round"
  has "$fix" 'bin/pln-assurance repair-action' "$fix does not use the deterministic repair decision"
  has "$fix" 'three consecutive failed repair attempts' "$fix has no per-defect stuck threshold"
  has "$fix" 'A different verified reproduction is a new finding' "$fix confuses new findings with looping"
  has "$fix" 'repository-native discovery' "$fix lost private-removal discovery proof"
  has "$fix" 'rerun the structural reference check and consumer map' "$fix lost post-fix structural assurance"
  hasnt "$fix" 'second blocking round means stop' "$fix retains the global repair-round cap"
  has "$ship" '`infrastructure`, `flaky`, `permission`, or `code`' "$ship edits before classifying CI failure"
  has "$ship" 'not exactly subsumed by the required CI checks' "$ship lost local gauntlet complement coverage"
  has "$ship" 'tree/command/environment/candidate hashes' "$ship lost exact-final-candidate evidence"
  has "$scope" 'bin/pln-simplify' "$scope lost the cadence enforcement consumer"
  has "$scope" 'consume it when the run reaches `complete` or deliberately stops' \
    "$scope lost freshness-bypass lifetime enforcement"
  has "$ship" 'pln-simplify" propagate' "$ship lost PR-body marker propagation"
  has "$ship" 'requires its content fingerprint to prove the resolved HEAD' \
    "$ship can propagate a marker invalidated by candidate mutation"
  has "$ship" 'consume any recorded simplification freshness bypass' \
    "$ship can reuse a completed run's freshness bypass"
  has "$finish" 'bin/pln-assurance fingerprint' "$finish lost exact pln verification identity"
  case "$root" in *real-codex*) prcmd='$pln-pr' ;; *) prcmd='/pln-pr' ;; esac
  has "$finish" "self-hosts \`$prcmd\`" "$finish lost the narrow self-hosting exception for pln-pr"
done

for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  has "$f" '### The fork test — what spends the user'"'"'s attention' "$f lost the fork test"
  has "$f" 'you can name two answers you would honestly implement' "$f lost the fork half of the fork test"
  has "$f" 'The consequence is theirs, and material' "$f lost the consequence half of the fork test"
  has "$f" 'anything landing on a decision the user made' "$f lost protected decision handling"
  has "$f" 'a channel to the user' "$f lost the rule that the plan record is not how the user is told"
done
for f in "$real_c/phases/pln/interview.md" "$real_x/phases/pln/interview.md"; do
  has "$f" 'How a decision is recorded' "$f lost the rule that makes the plan readable alone"
done

# The same-model reviewer is spawned on this host, so that block — and only that
# block — differs between the builds. Each must carry its own spawn, point at the
# same brief file the peer would have been handed, and say how to run it
# alongside the peer rather than after it.
spawn_of() { # spawn_of <file>
  awk '/^\*\*Spawning same-model reviewers/,/^The review runs once/' "$1"
}
spawn_c="$(spawn_of "$real_c/phases/pln/review-approval.md")"
spawn_x="$(spawn_of "$real_x/phases/pln/review-approval.md")"
[ -n "$spawn_c" ] || fail "the claude build has no same-model spawn block"
[ -n "$spawn_x" ] || fail "the codex build has no same-model spawn block"
grep -qF 'general-purpose` `Agent' <<<"$spawn_c" \
  || fail "the claude build's reviewer is not a current harness Agent"
grep -qF 'pln-codex-agent' <<<"$spawn_x" || fail "the codex build's reviewer is not a codex spawn"
grep -qF 'read-only' <<<"$spawn_x" || fail "the codex build's reviewer is not read-only"
grep -qF "points at that role's brief" <<<"$spawn_c" \
  || fail "the claude build's reviewer is not pointed at its roster brief"
grep -qF "points at that role's brief" <<<"$spawn_x" \
  || fail "the codex build's reviewer is not handed its roster brief"
grep -qF 'start its shell call in the background' <<<"$spawn_c" \
  || fail "the claude build does not say how to run the reviewer alongside the peer"
grep -qF 'Alongside the peer' <<<"$spawn_x" \
  || fail "the codex build does not say how to run the reviewer alongside the peer"
grep -qF 'wait_agent' <<<"$spawn_x" \
  || fail "the codex build's concurrency seam is not the native wait loop"

# ─── and nothing above touched the working tree ───────────────────────────────
if [ -d "$REPO_DIR/.git" ]; then
  tracked_targets="$(git -C "$REPO_DIR" ls-files -- $targets)"
  dirty="" fingerprint=""
  if [ -n "$tracked_targets" ]; then
    dirty="$(git -C "$REPO_DIR" status --porcelain -- $tracked_targets)"
    while IFS= read -r target; do
      fingerprint="$fingerprint$target $(git -C "$REPO_DIR" hash-object "$target")
"
    done <<< "$tracked_targets"
  fi
  [ "$dirty" = "$tracked_target_status_before" ] \
    || fail "the test changed tracked skill-file status: before=[$tracked_target_status_before] after=[$dirty]"
  [ "$fingerprint" = "$tracked_target_fingerprint_before" ] \
    || fail "the test changed tracked skill-file bytes"
fi

echo "OK"
