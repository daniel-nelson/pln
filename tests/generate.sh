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

# This is a regression ceiling on the always-resident coordinator prompt, not a
# target. The worker-owned contracts below are deliberately outside it. The
# ceiling leaves a narrow allowance over this release's 133–137 KB builds while
# preventing a return to the prior 152–156 KB coordinator.
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
  has "$f" 'provisional cohort cap is three' "$f lost bounded same-context reuse"
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
  interview_file="$host_out/phases/pln/interview.md"
  has "$f" '## Coordinator context firewall' "$f lost the shared context firewall"
  has "$outline_file" 'src/workers/preflight-research.md' "$outline_file does not mandate a pre-flight research worker"
  has "$outline_file" '8192-byte ceiling' "$outline_file lost the pre-flight envelope budget"
  has "$interview_file" 'src/workers/interview-research.md' "$interview_file does not mandate per-item research"
  has "$interview_file" 'Before the first proposal for every active item' "$interview_file makes per-item research optional"
  has "$interview_file" 'decision-record-query mode' "$interview_file lost query-scoped prior-decision checks"
  has "$outline_file" '.git/info/exclude' "$outline_file does not keep local plans out of .gitignore"
  has "$outline_file" 'Outside a git worktree' "$outline_file does not allocate an external non-git run directory"
  hasnt "$f" 'WORKER_ONLY_SENTINEL_' "$f embedded worker-only runtime instructions"
  has "$outline_file" 'Outside a git worktree, use the external temporary run directory' \
    "$outline_file contradicts pre-flight's non-git plan location"
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
  has "$f" '`judgment`' "$f lost the frontier capability floor"
  has "$f" '`evidence`' "$f lost the bounded evidence profile"
  has "$f" 'actual profile, model, and effort' "$f does not require actual routing attribution"
done
has "$real_c/SKILL.md" '`fable`' "the Claude build lost its current frontier alias"
has "$real_c/SKILL.md" '`sonnet`' "the Claude build lost its economy alias"
hasnt "$real_c/SKILL.md" 'gpt-5.6-sol' "the Claude build contains Codex model mechanics"
has "$real_x/SKILL.md" '`gpt-5.6-sol`' "the Codex build lost its current frontier model"
has "$real_x/SKILL.md" '`gpt-5.6-luna`' "the Codex build lost its economy model"
hasnt "$real_x/SKILL.md" '`fable`' "the Codex build contains Claude model mechanics"
hasnt "$REPO_DIR/src/SKILL.core.md" 'gpt-5.6-sol' "the shared /pln core hardcodes an aging Codex model"
hasnt "$REPO_DIR/src/pln-pr/SKILL.core.md" 'gpt-5.6-sol' "the shared /pln-pr core hardcodes an aging Codex model"
# The line 1.15.0 shipped on the Codex side — that there is no second model to
# consult from here — was replaced, not kept: rung 2 reaches for `claude` from
# Codex exactly as it reaches for `codex` from Claude.
hasnt "$real_x/pln-pr/SKILL.md" 'no second one to consult' \
  "the codex build still says a peer cannot be consulted from this host"

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
    '## Ship' '## Reversals' '## Verification' '## Spinoffs' '## Cross-item notes'; do
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
  fix="$root/phases/pln-pr/fix.md"
  ship="$root/phases/pln-pr/ship-watch.md"
  finish="$root/phases/pln/finish-ship.md"
  has "$review" '### Step 3. Risk-calibrated review roster' "$review lost semantic assurance tiers"
  has "$review" 'at most four pre-fix readers' "$review lost the R3 pre-fix cap"
  has "$review" '"verified"|"unverified"' "$review lost evidence-state findings"
  hasnt "$review" 'DIFF_LINES < 30' "$review retained the line-count shortcut"
  hasnt "$review" 'confidence: 1-10' "$review retained reviewer self-scoring"
  has "$fix" 'R1 narrowly verifies' "$fix lost tiered post-fix assurance"
  has "$fix" 'separate from the four-reader pre-fix cap' "$fix counts red team in the pre-fix roster"
  has "$ship" '`infrastructure`, `flaky`, `permission`, or `code`' "$ship edits before classifying CI failure"
  has "$ship" 'not exactly subsumed by the required CI checks' "$ship lost local gauntlet complement coverage"
  has "$ship" 'tree/command/environment/candidate hashes' "$ship lost exact-final-candidate evidence"
  has "$finish" 'bin/pln-assurance fingerprint' "$finish lost exact pln verification identity"
  has "$finish" 'self-hosts `/pln-pr`' "$finish lost the narrow self-hosting exception for pln-pr"
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
