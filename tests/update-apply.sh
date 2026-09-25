#!/usr/bin/env bash
# tests/update-apply.sh — bin/pln-update-apply, run end to end.
#
# The property under test is that a copy which fails to upgrade says why, and
# is left as it was. Every failure used to print a bare `failed`, and git's
# stderr went to /dev/null, so a model could not tell a sandbox that refused a
# write from an unreachable remote — and several failure paths damaged the copy
# they failed on: a failed fetch left a git install as the unbuilt placeholder,
# a failed backup emptied a vendored install, and a stale `.bak` it could not
# remove was restored over a working one.
#
# No network and no real install: the origin is a scratch git repository read
# by path, the remote VERSION is a `file://` URL, and HOME, the cwd and the
# state dir are all scratch. HOME matters beyond hygiene — the .codex → .agents
# migration hard-codes `$HOME/.codex/skills/pln` and `.codex/skills/pln`, which
# PLN_SKILL_DIRS does not override, so a run under the real HOME would move the
# developer's own copy.
#
# The not-writable cases use chmod, which root ignores, so they are skipped
# under uid 0 (precedent: tests/todo.sh). chmod is also not the mechanism a
# host sandbox uses; that a real write attempt catches a sandbox denial is
# checked by hand (see the plan's manual criteria), not here.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPLY="$ROOT/bin/pln-update-apply"
WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$WORK/cwd"

FAILED=0
fail() { printf 'FAIL: %s\n' "$1"; FAILED=1; }
said() { case "$OUT" in *"$1"*) ;; *) fail "$2"$'\n'"  output was: $OUT" ;; esac; }
didnt_say() { case "$OUT" in *"$1"*) fail "$2"$'\n'"  output was: $OUT" ;; *) ;; esac; }
is() { [ "$1" = "$2" ] || fail "$3 (got '$1', wanted '$2')"; }

AS_ROOT=false
[ "$(id -u)" = "0" ] && AS_ROOT=true

g() { git -c user.name=pln-test -c user.email=pln-test@example.invalid -c commit.gpgsign=false "$@"; }

# ─── an origin shaped like pln ───────────────────────────────────────────────
# Tracked SKILL.md is the placeholder; `setup` builds it; `pln-generate --clean`
# puts the placeholder back — the same three moves a real install makes.
make_origin() { # make_origin <path> <new-setup-exit>
  local o="$1"
  mkdir -p "$o/bin"
  printf 'not built yet — run ./setup\n' > "$o/SKILL.md"
  cat > "$o/setup" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
printf 'BUILT %s\n' "$(cat VERSION)" > SKILL.md
EOF
  cat > "$o/bin/pln-generate" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--clean" ] || exit 0
cd "$(dirname "$0")/.." && git checkout -- SKILL.md
EOF
  chmod +x "$o/setup" "$o/bin/pln-generate"
  printf '1.0.0\n' > "$o/VERSION"
  git init -q "$o"
  g -C "$o" checkout -q -b main 2>/dev/null || true
  g -C "$o" add -A && g -C "$o" commit -qm 1.0.0 && g -C "$o" tag v1
  printf '1.1.0\n' > "$o/VERSION"
  [ "$2" = 0 ] || printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "$o/setup"
  g -C "$o" add -A && g -C "$o" commit -qm 1.1.0
}
ORIGIN="$WORK/origin"; make_origin "$ORIGIN" 0
BADSETUP="$WORK/origin-bad-setup"; make_origin "$BADSETUP" 1
printf '1.1.0\n' > "$WORK/remote-version"

git_install() { # git_install <dir> [origin] — a built 1.0.0 clone whose origin is at 1.1.0
  mkdir -p "$(dirname "$1")"
  git clone -q "${2:-$ORIGIN}" "$1" && g -C "$1" reset -q --hard v1 && (cd "$1" && ./setup)
}
vendored_install() { # vendored_install <dir> — a built 1.0.0 copy with no .git
  mkdir -p "$1"
  g -C "$ORIGIN" archive v1 | tar -x -C "$1" && (cd "$1" && ./setup)
  printf 'mine\n' > "$1/user-file"
}
snapshot() { (cd "$1" && find . -print | LC_ALL=C sort && cat VERSION SKILL.md) 2>&1; }

STATE="$WORK/state"
apply() { # apply <skill-dirs> [--plan]; extra env via APPLY_ENV
  rm -rf "$STATE"
  OUT="$(cd "$WORK/cwd" && env PLN_STATE_DIR="$STATE" PLN_SKILL_DIRS="$1" \
         PLN_REMOTE_URL="file://$WORK/remote-version" PLN_SOURCE_REPO="$ORIGIN" \
         PLN_NO_SETUP=1 ${APPLY_ENV:+$APPLY_ENV} "$APPLY" ${2:+"$2"} 2>&1)"
  RC=$?
}
APPLY_ENV=""

# ─── the output contract names every reason the script can print ─────────────
HEADER="$(sed -n '1,/^set -uo pipefail/p' "$APPLY")"
case "$HEADER" in *'failed:<reason>'*) ;; *) fail "the output contract does not name failed:<reason>" ;; esac
for r in $(sed '1,/^set -uo pipefail/d' "$APPLY" | grep -oE '[a-z]+-failed|not-writable' | sort -u); do
  case "$HEADER" in *"$r"*) ;; *) fail "the output contract does not list the reason '$r' the script prints" ;; esac
done

# ─── git: a writable copy upgrades and is built ──────────────────────────────
D="$WORK/g-ok/skills/pln"; git_install "$D"
APPLY_ENV="PLN_NO_SETUP=0" apply "$D"
is "$RC" 0 "a writable git copy did not upgrade cleanly"
said "COPY $D 1.0.0 -> 1.1.0 upgraded" "a writable git copy was not reported upgraded"
is "$(cat "$D/SKILL.md")" "BUILT 1.1.0" "an upgraded git copy was not rebuilt"
[ -f "$STATE/just-upgraded-from" ] || fail "an upgrade did not write the just-upgraded marker"

# ─── git: an unreachable origin fails as a fetch and leaves the copy built ───
D="$WORK/g-fetch/skills/pln"; git_install "$D"
g -C "$D" remote set-url origin "$WORK/no-such-origin"
apply "$D"
is "$RC" 3 "a failed fetch did not exit 3"
said "COPY $D 1.0.0 -> 1.0.0 failed:fetch-failed" "a failed fetch was not reported as fetch-failed"
is "$(cat "$D/SKILL.md")" "BUILT 1.0.0" "a failed fetch left the git copy unbuilt"
[ -f "$STATE/just-upgraded-from" ] && fail "a failed upgrade wrote the just-upgraded marker"

# ─── git: a failing setup is reported, with the version now on disk ──────────
D="$WORK/g-setup/skills/pln"; git_install "$D" "$BADSETUP"
APPLY_ENV="PLN_NO_SETUP=0" apply "$D"
is "$RC" 3 "a failed setup did not exit 3"
said "COPY $D 1.0.0 -> 1.1.0 failed:setup-failed" "a failed setup was not reported, or not with the on-disk version"
didnt_say "1.1.0 upgraded" "a failed setup was still reported as upgraded"

# ─── vendored: a writable copy upgrades and leaves no backup ─────────────────
D="$WORK/v-ok/skills/pln"; vendored_install "$D"
APPLY_ENV="PLN_NO_SETUP=0" apply "$D"
is "$RC" 0 "a writable vendored copy did not upgrade cleanly"
said "COPY $D 1.0.0 -> 1.1.0 upgraded" "a writable vendored copy was not reported upgraded"
[ -e "$D.bak" ] && fail "a successful vendored upgrade left its backup behind"

# ─── vendored: an unreachable source fails as a clone and touches nothing ────
D="$WORK/v-clone/skills/pln"; vendored_install "$D"; BEFORE="$(snapshot "$D")"
APPLY_ENV="PLN_SOURCE_REPO=$WORK/no-such-origin" apply "$D"
is "$RC" 3 "a failed clone did not exit 3"
said "COPY $D 1.0.0 -> 1.0.0 failed:clone-failed" "a failed clone was not reported as clone-failed"
is "$(snapshot "$D")" "$BEFORE" "a failed clone changed the vendored copy"

# ─── migrate: a legacy copy that cannot be removed is not called dropped ─────
if ! $AS_ROOT; then
  mkdir -p "$HOME/.codex/skills/pln" "$HOME/.agents/skills"
  printf '0.9.0\n' > "$HOME/.codex/skills/pln/VERSION"
  ln -s "$WORK/origin" "$HOME/.agents/skills/pln"
  chmod a-w "$HOME/.codex/skills"
  apply "$HOME/.agents/skills/pln"
  said "MIGRATE ~/.codex/skills/pln drop-failed" "a legacy copy that survived rm was not reported drop-failed"
  didnt_say "dropped" "a legacy copy that survived rm was reported dropped"
  chmod u+w "$HOME/.codex/skills"; rm -rf "$HOME/.codex" "$HOME/.agents"
fi

if $AS_ROOT; then
  echo "SKIP: chmod-based not-writable cases (running as root, which ignores mode bits)"
else
  # ─── git: a read-only copy is refused before anything changes ──────────────
  D="$WORK/g-ro/skills/pln"; git_install "$D"; BEFORE="$(snapshot "$D")"
  chmod -R a-w "$D"
  apply "$D" --plan
  is "$RC" 0 "--plan over a read-only git copy did not exit 0"
  said "COPY $D 1.0.0 -> 1.1.0 plan:git:would-fail-not-writable" "--plan did not name a git copy that would fail the write probe"
  apply "$D"
  is "$RC" 3 "a read-only git copy did not exit 3"
  said "COPY $D 1.0.0 -> 1.0.0 failed:not-writable" "a read-only git copy was not reported not-writable"
  chmod -R u+w "$D"
  is "$(snapshot "$D")" "$BEFORE" "a read-only git copy was modified"

  # ─── vendored: a read-only copy is refused before anything changes ─────────
  D="$WORK/v-ro/skills/pln"; vendored_install "$D"; BEFORE="$(snapshot "$D")"
  chmod -R a-w "$D"
  apply "$D"
  is "$RC" 3 "a read-only vendored copy did not exit 3"
  said "COPY $D 1.0.0 -> 1.0.0 failed:not-writable" "a read-only vendored copy was not reported not-writable"
  chmod -R u+w "$D"
  is "$(snapshot "$D")" "$BEFORE" "a read-only vendored copy was modified"

  # ─── vendored: a read-only parent keeps the copy's files ───────────────────
  # The backup lives beside the copy, so the parent must be writable too. This
  # shape used to fail the backup and then delete the copy's contents.
  D="$WORK/v-parent/skills/pln"; vendored_install "$D"; BEFORE="$(snapshot "$D")"
  chmod a-w "$(dirname "$D")"
  apply "$D" --plan
  said "plan:vendored:would-fail-not-writable" "--plan did not name a vendored copy whose parent is read-only"
  apply "$D"
  is "$RC" 3 "a vendored copy with a read-only parent did not exit 3"
  said "COPY $D 1.0.0 -> 1.0.0 failed:not-writable" "a vendored copy with a read-only parent was not reported not-writable"
  chmod u+w "$(dirname "$D")"
  is "$(snapshot "$D")" "$BEFORE" "a vendored copy with a read-only parent lost its files"

  # ─── vendored: a stale backup that cannot be removed is never restored ─────
  # Restoring someone else's .bak over a working copy replaces it with stale
  # files; the run may restore only a backup it made itself.
  D="$WORK/v-stale/skills/pln"; vendored_install "$D"; BEFORE="$(snapshot "$D")"
  mkdir -p "$D.bak/locked"; printf 'stale\n' > "$D.bak/locked/f"; chmod a-w "$D.bak/locked"
  apply "$D"
  is "$RC" 3 "an unremovable stale backup did not exit 3"
  said "COPY $D 1.0.0 -> 1.0.0 failed:backup-failed" "an unremovable stale backup was not reported backup-failed"
  is "$(snapshot "$D")" "$BEFORE" "an unremovable stale backup replaced the working copy"
  chmod u+w "$D.bak/locked"
fi

[ "$FAILED" -eq 0 ] && echo OK
exit "$FAILED"
