**Resolve pln's helpers**: this skill's `bin/` scripts sit next to this file, but Codex does not hand a skill its own directory, so find the install once and reuse the path everywhere below. Run this first:

```bash
_PLN_DIR=""
for d in "$HOME/.agents/skills/pln" "$HOME/.codex/skills/pln" ".agents/skills/pln" ".codex/skills/pln"; do
  [ -x "$d/bin/pln-config" ] && _PLN_DIR="$d" && break
done
echo "PLN_DIR: ${_PLN_DIR:-none}"
```

Every command below written as `$_PLN_DIR/bin/...` means that path — substitute the value you just resolved, since each shell call starts fresh and the variable does not persist. If it printed `none`, the helpers aren't installed: skip the update check and the notification setup, and treat notifications as off. The skill still works end to end.

**Update check**: run `"$_PLN_DIR/bin/pln-update-check" 2>/dev/null` and read the output. If it says `UPGRADE_AVAILABLE <old> <new>`, follow the inline upgrade flow in `{{PLN_UPDATE_CMD}}` before continuing with the planning task. The check scans every installed copy and reports the lowest version, so a second indented line may list each copy and mark the stale ones `(behind)`; relay that to the user so they can see which install is out of date. If it says `JUST_UPGRADED <old> <new>`, tell the user "pln upgraded from v{old} to v{new}!" and continue. If there is no such line, say nothing about updates.
