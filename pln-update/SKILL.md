---
name: pln-update
description: Update the pln skill to the latest version from GitHub. Invoke it by name — `/pln-update` in Claude Code, `$pln-update` in Codex, which has no slash commands — or follow this flow when pln's preamble reports `UPGRADE_AVAILABLE`.
allowed-tools: Bash, Read, Write
---

# pln-update

Upgrade pln to the latest version and show what's new.

**Never use the `AskUserQuestion` tool** — pln's hard rule. Every question in this flow is plain assistant text; the user answers as a chat message.

## Inline upgrade flow

This section is referenced by pln's main preamble when it detects `UPGRADE_AVAILABLE <old> <new>`. Substitute `{old}` / `{new}` from that output.

### Step 1: Ask the user (or auto-upgrade)

First, check whether auto-upgrade is enabled:
```bash
_SKILL_DIR=""
for d in "${CLAUDE_SKILL_DIR:-}" "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" ".agents/skills/pln" ".claude/skills/pln"; do
  [ -n "$d" ] && [ -x "$d/bin/pln-config" ] && _SKILL_DIR="$d" && break
done
_AUTO=""
[ -n "$_SKILL_DIR" ] && _AUTO=$("$_SKILL_DIR/bin/pln-config" get auto_upgrade 2>/dev/null || true)
echo "AUTO_UPGRADE=$_AUTO SKILL_DIR=$_SKILL_DIR"
```

**If `AUTO_UPGRADE=true`:** Skip the prompt. Say "Auto-upgrading pln v{old} → v{new}..." and go straight to Step 2. If Step 2 fails, follow **If an upgrade fails** there.

**Otherwise**, ask in plain text (no `AskUserQuestion`):

> pln v{new} is available (you're on v{old}). Upgrade now?
>
> a) **[recommended] Yes, upgrade now** — fetch and install v{new}
> b) **Always keep me up to date** — upgrade now and auto-upgrade silently from here on
> c) **Not now** — remind me later
> d) **Never ask again** — disable update checks (you can still invoke pln-update manually)

Wait for the answer, then:

Answers (b), (c) and (d) write to `~/.pln`, which is outside the workspace, so run their commands as **Sandboxed hosts** in Step 2 says.

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
Say "Update checks disabled. Invoke pln-update anytime, or re-enable with `~/.pln/bin/pln-config set update_check true`." Continue with the current task.

### Step 2: Reconcile every installed copy

pln can be installed in more than one root at once (`~/.agents`, `~/.claude`,
plus project-local `.agents`/`.claude`). The host may load a
different copy than the one that sorts first, so the upgrade must bring **every**
copy to the remote version, not just the first one found. `bin/pln-update-apply`
does that in a single pass and prints per-copy results.

Find a copy that ships the script (prefer the newest, since a stale copy may
predate it), then run it:

**Sandboxed hosts.** The apply step writes the install directories, which sit
outside the workspace, and fetches from the network. Where the host sandboxes
commands and offers a way to request escalation, request it on the first
attempt instead of waiting for a failure. On Codex that is
`sandbox_permissions: "require_escalated"`, with a `justification` such as "Do
you want to let pln-update write its installed skill copies outside this
workspace?". Where the host offers no escalation (Codex under approval policy
`never`, for one), run the command as it is.

```bash
APPLY=""
for d in "${CLAUDE_SKILL_DIR:-}" "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" ".agents/skills/pln" ".claude/skills/pln"; do
  [ -n "$d" ] && [ -x "$d/bin/pln-update-apply" ] && APPLY="$d/bin/pln-update-apply" && break
done
if [ -n "$APPLY" ]; then
  "$APPLY"
else
  echo "NO_APPLY_SCRIPT"   # every copy predates the reconcile-all updater; use the fallback below
fi
```

**Optional preview:** run `"$APPLY" --plan` first to show the user what will
change without mutating anything (lists each copy, its version, and whether it
would upgrade). Skip the preview during an auto-upgrade.

Read the script's output and relay it:

- `REMOTE <version>` — the target version.
- One `COPY <dir> <old> -> <new> <status>` line per copy. Statuses: `upgraded`,
  `unchanged` (already current), `stashed` (upgraded, but local git changes were
  stashed — tell the user to `git stash pop` in that dir), `dev-symlink-skipped`
  (a developer install; leave it, they `git pull` the source clone),
  `failed:<reason>` (the copy did not upgrade; `failed:not-writable` means a
  write into it was refused before anything changed — a read-only install, or a
  sandbox that confines writes to the workspace).
- `SUMMARY <oldmin> -> <new> (<u> upgraded, <c> unchanged, <s> skipped, <f> failed)`.

**If an upgrade fails** — the script exits 2 (remote unreachable, before any
copy is tried) or any copy is `failed:<reason>`:

1. Retry once, escalated, if this run was not already escalated, the host
   sandboxes commands and offers escalation, and the failure is one the sandbox
   can cause: exit 2, `failed:not-writable`, `failed:fetch-failed` or
   `failed:clone-failed`. Rerun `"$APPLY"` as **Sandboxed hosts** above says.
   One retry per invocation, never a loop.
2. Otherwise — any other reason, an escalated run that failed, or a host with no
   sandbox — tell the user in one line which copy failed and why. The remedy is
   to invoke pln-update again, except `setup-failed` on a git copy (its `COPY`
   line shows the new version, so the check will not offer the upgrade again):
   name `./setup` in that directory, plus `git stash pop` there if
   `git stash list` shows the upgrade stashed local changes.

Then carry on: Step 3 if any copy upgraded, then Step 4. A failed upgrade never
stops the run. The script writes the just-upgraded marker and clears the update
cache itself when at least one copy was upgraded.

**Fallback (only if `NO_APPLY_SCRIPT`):** every installed copy predates this
updater, so reconcile the git copies inline, run as **Sandboxed hosts** above says:

```bash
for d in "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" ".agents/skills/pln" ".claude/skills/pln"; do
  [ -d "$d/.git" ] || continue
  [ -L "$d" ] && { echo "$d: dev symlink, skipped"; continue; }
  OLD=$(cat "$d/VERSION" 2>/dev/null || echo unknown)
  ( cd "$d" && git stash >/dev/null 2>&1; git fetch origin >/dev/null 2>&1 && git reset --hard origin/main >/dev/null 2>&1 && ./setup >/dev/null 2>&1 )
  echo "$d: $OLD -> $(cat "$d/VERSION" 2>/dev/null || echo unknown)"
done
mkdir -p ~/.pln && rm -f ~/.pln/last-update-check ~/.pln/update-snoozed
```

### Step 3: Show what's new

Read `CHANGELOG.md` from any upgraded copy (e.g. the `$APPLY` dir). Summarize the
entries between `{old}` (the `SUMMARY` `oldmin`) and `{new}` as 3–6 bullets,
user-facing changes only. Format:
```
pln v{new} — upgraded from v{old}!

What's new:
- ...
```

### Step 4: Continue

The new files take effect on the next skill load (this session still has the old
copy in context). Continue with whatever the user originally asked for.

---

## Standalone usage

When invoked directly by name (not from the preamble):

1. Force a fresh check. The checker scans every installed copy and reports the lowest version, so this catches a stale copy in a root the host doesn't load first:
```bash
UPDATE_CHECK_OUTPUT=""; UPDATE_CHECK_OK=false
for d in "${CLAUDE_SKILL_DIR:-}" "$HOME/.agents/skills/pln" "$HOME/.claude/skills/pln" ".agents/skills/pln" ".claude/skills/pln"; do
  if [ -n "$d" ] && [ -x "$d/bin/pln-update-check" ]; then
    UPDATE_CHECK_OUTPUT=$("$d/bin/pln-update-check" --force 2>/dev/null) && UPDATE_CHECK_OK=true
    break
  fi
done
echo "UPDATE_CHECK_OK=$UPDATE_CHECK_OK"; echo "UPDATE_CHECK_OUTPUT=$UPDATE_CHECK_OUTPUT"
```

2. If `UPGRADE_AVAILABLE <old> <new>` appears: run the inline flow (Step 2 reconcile onward). The `--plan` preview is a good idea here so the user sees which copies are behind before anything changes.

3. **If `UPDATE_CHECK_OK=false`** (script missing or sandbox-blocked): don't trust silence. Run the reconcile directly — `bin/pln-update-apply` fetches the remote version itself and is a no-op for copies already current, so it's safe to run even when the check couldn't confirm. Locate it as in Step 2 and run `"$APPLY" --plan` then `"$APPLY"`, running `"$APPLY"` as **Sandboxed hosts** in Step 2 says and handling a failure as **If an upgrade fails** there says. If no copy ships the script either, use the Step 2 fallback loop.
