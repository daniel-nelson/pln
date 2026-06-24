---
name: pln-update
description: Update the pln skill to the latest version from GitHub. Invoke as `/pln-update`, or follow this flow when pln's preamble reports `UPGRADE_AVAILABLE`.
allowed-tools: Bash, Read, Write
---

# /pln-update

Upgrade pln to the latest version and show what's new.

**Never use the `AskUserQuestion` tool** — pln's hard rule. Every question in this flow is plain assistant text; the user answers as a chat message.

## Inline upgrade flow

This section is referenced by pln's main preamble when it detects `UPGRADE_AVAILABLE <old> <new>`. Substitute `{old}` / `{new}` from that output.

### Step 1: Ask the user (or auto-upgrade)

First, check whether auto-upgrade is enabled:
```bash
_SKILL_DIR=""
for d in "${CLAUDE_SKILL_DIR:-}" "${CODEX_SKILL_DIR:-}" "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" "$HOME/.codex/skills/pln" ".agents/skills/pln" ".claude/skills/pln" ".codex/skills/pln"; do
  [ -n "$d" ] && [ -x "$d/bin/pln-config" ] && _SKILL_DIR="$d" && break
done
_AUTO=""
[ -n "$_SKILL_DIR" ] && _AUTO=$("$_SKILL_DIR/bin/pln-config" get auto_upgrade 2>/dev/null || true)
echo "AUTO_UPGRADE=$_AUTO SKILL_DIR=$_SKILL_DIR"
```

**If `AUTO_UPGRADE=true`:** Skip the prompt. Say "Auto-upgrading pln v{old} → v{new}..." and go straight to Step 2. If anything in Step 2–4 fails during an auto-upgrade, restore from backup and warn: "Auto-upgrade failed — restored previous version. Run `/pln-update` to retry."

**Otherwise**, ask in plain text (no `AskUserQuestion`):

> pln v{new} is available (you're on v{old}). Upgrade now?
>
> a) **[recommended] Yes, upgrade now** — fetch and install v{new}
> b) **Always keep me up to date** — upgrade now and auto-upgrade silently from here on
> c) **Not now** — remind me later
> d) **Never ask again** — disable update checks (you can still run `/pln-update` manually)

Wait for the answer, then:

**(a) Yes, upgrade now:** proceed to Step 2.

**(b) Always keep me up to date:**
```bash
"$_SKILL_DIR/bin/pln-config" set auto_upgrade true
```
Say "Auto-upgrade enabled. Future updates install automatically." Then proceed to Step 2.

**(c) Not now:** write snooze state with escalating backoff (first = 24h, second = 48h, third+ = 1 week), then continue with whatever the user was doing. Do not mention the upgrade again this session.
```bash
_SNOOZE_FILE=~/.pln/update-snoozed
_REMOTE_VER="{new}"
_CUR_LEVEL=0
if [ -f "$_SNOOZE_FILE" ]; then
  _SNOOZED_VER=$(awk '{print $1}' "$_SNOOZE_FILE")
  if [ "$_SNOOZED_VER" = "$_REMOTE_VER" ]; then
    _CUR_LEVEL=$(awk '{print $2}' "$_SNOOZE_FILE")
    case "$_CUR_LEVEL" in *[!0-9]*) _CUR_LEVEL=0 ;; esac
  fi
fi
_NEW_LEVEL=$((_CUR_LEVEL + 1))
[ "$_NEW_LEVEL" -gt 3 ] && _NEW_LEVEL=3
mkdir -p ~/.pln
echo "$_REMOTE_VER $_NEW_LEVEL $(date +%s)" > "$_SNOOZE_FILE"
```
Tell the user the snooze duration ("Next reminder in 24h", or 48h, or 1 week, by level). Tip: "Set `auto_upgrade: true` in `~/.pln/config.yaml` to upgrade automatically."

**(d) Never ask again:**
```bash
"$_SKILL_DIR/bin/pln-config" set update_check false
```
Say "Update checks disabled. Run `/pln-update` anytime, or re-enable with `~/.pln/bin/pln-config set update_check true`." Continue with the current task.

### Step 2: Detect install type

```bash
if [ -d "$HOME/.agents/skills/pln/.git" ]; then
  INSTALL_TYPE="global-git"; INSTALL_DIR="$HOME/.agents/skills/pln"
elif [ -d "$HOME/.claude/skills/pln/.git" ]; then
  INSTALL_TYPE="global-git"; INSTALL_DIR="$HOME/.claude/skills/pln"
elif [ -d "$HOME/.codex/skills/pln/.git" ]; then
  INSTALL_TYPE="global-git"; INSTALL_DIR="$HOME/.codex/skills/pln"
elif [ -d ".agents/skills/pln/.git" ]; then
  INSTALL_TYPE="local-git"; INSTALL_DIR=".agents/skills/pln"
elif [ -d ".claude/skills/pln/.git" ]; then
  INSTALL_TYPE="local-git"; INSTALL_DIR=".claude/skills/pln"
elif [ -d ".codex/skills/pln/.git" ]; then
  INSTALL_TYPE="local-git"; INSTALL_DIR=".codex/skills/pln"
elif [ -d "$HOME/.agents/skills/pln" ]; then
  INSTALL_TYPE="vendored-global"; INSTALL_DIR="$HOME/.agents/skills/pln"
elif [ -d "$HOME/.claude/skills/pln" ]; then
  INSTALL_TYPE="vendored-global"; INSTALL_DIR="$HOME/.claude/skills/pln"
elif [ -d "$HOME/.codex/skills/pln" ]; then
  INSTALL_TYPE="vendored-global"; INSTALL_DIR="$HOME/.codex/skills/pln"
elif [ -d ".agents/skills/pln" ]; then
  INSTALL_TYPE="vendored"; INSTALL_DIR=".agents/skills/pln"
elif [ -d ".claude/skills/pln" ]; then
  INSTALL_TYPE="vendored"; INSTALL_DIR=".claude/skills/pln"
elif [ -d ".codex/skills/pln" ]; then
  INSTALL_TYPE="vendored"; INSTALL_DIR=".codex/skills/pln"
else
  echo "ERROR: pln not found"; exit 1
fi
echo "Install type: $INSTALL_TYPE at $INSTALL_DIR"
```

If `INSTALL_DIR` is a symlink (a developer install pointing at a working clone), don't upgrade it — tell the user it's a dev symlink and they should `git pull` in the source repo instead. Detect with `[ -L "$INSTALL_DIR" ]`.

### Step 3: Save old version

```bash
OLD_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
```

### Step 4: Upgrade

**For git installs** (global-git, local-git):
```bash
cd "$INSTALL_DIR"
STASH_OUTPUT=$(git stash 2>&1)
git fetch origin
git reset --hard origin/main
./setup
```
If `$STASH_OUTPUT` contains "Saved working directory", warn: "Local changes were stashed. Run `git stash pop` in $INSTALL_DIR to restore them."

**For vendored installs** (vendored, vendored-global):
```bash
TMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/daniel-nelson/pln.git "$TMP_DIR/pln"
mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
mv "$TMP_DIR/pln" "$INSTALL_DIR"
cd "$INSTALL_DIR" && ./setup
rm -rf "$INSTALL_DIR.bak" "$TMP_DIR"
```
If the clone or `./setup` fails, restore: `rm -rf "$INSTALL_DIR"; mv "$INSTALL_DIR.bak" "$INSTALL_DIR"` and tell the user to retry.

### Step 5: Write marker + clear cache

```bash
mkdir -p ~/.pln
echo "$OLD_VERSION" > ~/.pln/just-upgraded-from
rm -f ~/.pln/last-update-check
rm -f ~/.pln/update-snoozed
```

### Step 6: Show what's new

Read `$INSTALL_DIR/CHANGELOG.md`. Summarize the entries between `{old}` and `{new}` as 3–6 bullets, user-facing changes only. Format:
```
pln v{new} — upgraded from v{old}!

What's new:
- ...
```

### Step 7: Continue

The new files take effect on the next skill load (this session still has the old copy in context). Continue with whatever the user originally asked for.

---

## Standalone usage

When invoked directly as `/pln-update` (not from the preamble):

1. Run Step 2 to find `INSTALL_DIR`. If it's a symlink, tell the user it's a dev install and stop (they should `git pull` in the source repo).

2. Force a fresh check:
```bash
UPDATE_CHECK_OUTPUT=""; UPDATE_CHECK_OK=false
for d in "${CLAUDE_SKILL_DIR:-}" "${CODEX_SKILL_DIR:-}" "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" "$HOME/.codex/skills/pln" ".agents/skills/pln" ".claude/skills/pln" ".codex/skills/pln"; do
  if [ -n "$d" ] && [ -x "$d/bin/pln-update-check" ]; then
    UPDATE_CHECK_OUTPUT=$("$d/bin/pln-update-check" --force 2>/dev/null) && UPDATE_CHECK_OK=true
    break
  fi
done
echo "UPDATE_CHECK_OK=$UPDATE_CHECK_OK"; echo "UPDATE_CHECK_OUTPUT=$UPDATE_CHECK_OUTPUT"
```

3. If `UPGRADE_AVAILABLE <old> <new>` appears: run Steps 2–6.

4. **If `UPDATE_CHECK_OK=false`** (script missing or sandbox-blocked): fall back to a direct compare. No output from the script does NOT mean "up to date" — always confirm against the remote.
```bash
INSTALLED_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
REMOTE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/daniel-nelson/pln/main/VERSION 2>/dev/null | tr -d '[:space:]')
echo "INSTALLED=$INSTALLED_VERSION REMOTE=$REMOTE_VERSION"
```
- Empty `REMOTE_VERSION`: "Could not reach GitHub to check for updates. Verify network access and try again." Stop.
- Differs: treat as `UPGRADE_AVAILABLE` and run Steps 2–6.
- Matches: tell the user "You're already on the latest version (v{version})."
