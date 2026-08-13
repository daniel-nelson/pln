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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-generate-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

has() { grep -qF -- "$2" "$1" || fail "$3"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3"; return 0; }

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
has "$real_c/SKILL.md" 'commit owner: worker' \
  "the claude build lost worker-owned item commits"
has "$real_x/SKILL.md" 'commit owner: coordinator' \
  "the codex build lost coordinator-owned item commits"
has "$real_c/SKILL.md" 'resumeFromRunId' \
  "the claude build lost Workflow blocker resume"
has "$real_x/SKILL.md" 'resume_agent' \
  "the codex build lost native blocker resume"

# This is a regression ceiling on the always-resident coordinator prompt, not a
# target. The worker-owned contracts below are deliberately outside it. The
# ceiling leaves a narrow allowance over this release's 133–137 KB builds while
# preventing a return to the prior 152–156 KB coordinator.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  bytes="$(LC_ALL=C wc -c < "$f")"
  bytes="${bytes//[[:space:]]/}"
  [ "$bytes" -le 138000 ] \
    || fail "$f is $bytes bytes; coordinator ceiling is 138000"
done

# Repository discovery is shared planning discipline: both coordinators must
# delegate it, while the detailed worker contracts remain outside the generated
# coordinator prompt.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  has "$f" '## Coordinator context firewall' "$f lost the shared context firewall"
  has "$f" 'src/workers/preflight-research.md' "$f does not mandate a pre-flight research worker"
  has "$f" '8192-byte ceiling' "$f lost the pre-flight envelope budget"
  has "$f" 'src/workers/interview-research.md' "$f does not mandate per-item research"
  has "$f" 'Before the first proposal for every active item' "$f makes per-item research optional"
  has "$f" 'decision-record-query mode' "$f lost query-scoped prior-decision checks"
  has "$f" '.git/info/exclude' "$f does not keep local plans out of .gitignore"
  has "$f" 'Outside a git worktree' "$f does not allocate an external non-git run directory"
  hasnt "$f" 'WORKER_ONLY_SENTINEL_' "$f embedded worker-only runtime instructions"
  has "$f" 'Outside a git worktree, use the external temporary run directory' \
    "$f contradicts pre-flight's non-git plan location"
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
for f in "$real_c/SKILL.md" "$real_x/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" 'The to-do-location flow' "$f lost the to-do-location flow"
  has "$f" 'without asking' "$f does not record follow-ups without asking"
done
# The end-of-run sweep is the other half of that flow, shared the same way: a
# close that never looks at the run's own record reports whatever it happens to
# remember, and the to-do-location flow then has nothing to write.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" "Sweep the run's own record" "$f lost the end-of-run sweep"
  has "$f" 'nothing outstanding says so' "$f does not report an empty sweep"
done

has "$real_c/SKILL.md" '~/.claude/CLAUDE.md' "the claude build reads no global instructions file"
has "$real_x/SKILL.md" '$CODEX_HOME/AGENTS.md' "the codex build reads no global instructions file"

# The peer ladder is one shared source both skills read, and the property that
# matters is that neither carries probe logic of its own: every build of both
# targets reaches the peer through the same helper, behind the same one-time
# consent key.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md" "$real_c/pln-pr/SKILL.md" "$real_x/pln-pr/SKILL.md"; do
  has "$f" '## Consulting a peer model' "$f carries no peer section"
  has "$f" 'pln-peer' "$f does not reach the peer through the picker"
  has "$f" 'peer_consent' "$f names no consent key in front of the peer"
done
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
has "$real_c/SKILL.md" '1. <one-line summary> — ⬜ pending' \
  "the claude build's dashboard row is not number-first with a trailing status"
has "$real_x/SKILL.md" '1. <one-line summary> — ⬜ pending' \
  "the codex build's dashboard row is not number-first with a trailing status"
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
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
done

# ─── the plan review, as skill text ───────────────────────────────────────────
# Step 3.5 keeps coordinator policy in the generated skill while the detailed
# reviewer and merge rubrics remain in installed worker contracts.
for f in "$real_c/SKILL.md" "$real_x/SKILL.md"; do
  has "$f" '### Step 3.5. Plan review' "$f lost the plan review step"
  has "$f" '## The plan review switch' "$f lost the plan review switch"
  has "$f" 'plan_review' "$f names no config key for the switch"
  has "$f" 'The size of the plan never does' "$f lost the rule that plan size changes nothing"
  has "$f" '## Plan review ownership' "$f lost review ownership policy"
  has "$f" 'src/workers/plan-review.md' "$f lost the reviewer contract pointer"
  has "$f" 'src/workers/plan-review-merge.md' "$f lost the merge contract pointer"
  has "$f" 'pln-build-review-brief' "$f no longer assembles one on-disk brief"
  has "$f" 'Never open raw findings in this context' "$f may read raw findings inline"
  # One test decides what spends the user's attention, and both surfaces run it.
  # Two separately-worded batteries is what filled the gate with a log of the
  # agent's own work.
  has "$f" '### The fork test — what spends the user'"'"'s attention' \
    "$f lost the fork test"
  has "$f" 'you can name two answers you would honestly implement' \
    "$f lost the fork half of the fork test"
  has "$f" 'The consequence is theirs, and material' \
    "$f lost the consequence half of the fork test — where proportionality lives"
  has "$f" 'anything landing on a decision the user made' \
    "$f lost the override that sends a protected decision to the user regardless"
  # The record is not a channel. Every silent lane below rests on this being
  # said out loud, because a user who never opens PLAN.md cannot be told by it.
  has "$f" 'a channel to the user' \
    "$f lost the rule that the plan record is not how the user is told"
  has "$f" 'A finding on a user-made decision is always protected from repair' \
    "$f lost coordinator-facing user-decision protection"
  has "$f" 'Flagging is reserved for material user-owned forks' \
    "$f lost coordinator-facing outcome policy"
  has "$f" 'How a decision is recorded' "$f lost the rule that makes the plan readable alone"
  hasnt "$f" '### Rejected' "$f embeds worker-only rejection detail"
  hasnt "$f" 'Judge by substance, never by phrasing' "$f embeds worker-only merge detail"
done

# The same-model reviewer is spawned on this host, so that block — and only that
# block — differs between the builds. Each must carry its own spawn, point at the
# same brief file the peer would have been handed, and say how to run it
# alongside the peer rather than after it.
spawn_of() { # spawn_of <file>
  awk '/^\*\*Spawning the same-model reviewer/,/^The review runs once/' "$1"
}
spawn_c="$(spawn_of "$real_c/SKILL.md")"
spawn_x="$(spawn_of "$real_x/SKILL.md")"
[ -n "$spawn_c" ] || fail "the claude build has no same-model spawn block"
[ -n "$spawn_x" ] || fail "the codex build has no same-model spawn block"
grep -qF 'agentType' <<<"$spawn_c" || fail "the claude build's reviewer is not a harness agent"
grep -qF 'pln-codex-agent' <<<"$spawn_x" || fail "the codex build's reviewer is not a codex spawn"
grep -qF 'read-only' <<<"$spawn_x" || fail "the codex build's reviewer is not read-only"
grep -qF 'plan-review.brief.md' <<<"$spawn_c" \
  || fail "the claude build's reviewer is not pointed at the brief file"
grep -qF 'plan-review.brief.md' <<<"$spawn_x" \
  || fail "the codex build's reviewer is not handed the brief the peer would have had"
grep -qF 'run_in_background' <<<"$spawn_c" \
  || fail "the claude build does not say how to run the reviewer alongside the peer"
grep -qF 'Alongside the peer' <<<"$spawn_x" \
  || fail "the codex build does not say how to run the reviewer alongside the peer"
grep -qF 'wait_agent' <<<"$spawn_x" \
  || fail "the codex build's concurrency seam is not the native wait loop"

# ─── and nothing above touched the working tree ───────────────────────────────
if [ -d "$REPO_DIR/.git" ]; then
  dirty="$(git -C "$REPO_DIR" status --porcelain -- $targets)"
  [ -z "$dirty" ] || fail "the test modified tracked skill files: $dirty"
fi

echo "OK"
