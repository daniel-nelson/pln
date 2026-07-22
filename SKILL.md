---
name: pln
description: Human-paced planning — one question at a time — with a peer that pushes back. Two distinct phases — first an interview that resolves every per-item question into a complete master plan, then (only after the master plan is approved as a whole) an implementation phase that walks the items one at a time. Implementation runs autonomously: a thin orchestrator spawns a fresh subagent per item, with `PLAN.md` as the durable source of truth, so the whole plan executes without per-item intervention. No interleaving: implementation never begins while questions are still open. Plans live at `./plans/<YYYY-MM-DD>-<slug>/PLAN.md` relative to the session CWD. Trigger explicitly via `/pln <task>`, or auto-engage when the user says things like "make a plan", "let's tackle this in steps", "work through these", or pastes a numbered list of items to address. Universal — works in any repo. NEVER use the AskUserQuestion tool.
---

# pln — not built yet

This is the placeholder that ships in git. The real skill is generated per host from the sources in `src/`, so that the copy you read contains the mechanics for *your* agent host and nothing addressed to the other one.

Tell the user to run `./setup` in the directory this file is in, then restart the agent. Give them that directory's real path, which you know — don't make them work it out. It is normally one of these:

```bash
cd ~/.claude/skills/pln && ./setup   # Claude Code
cd ~/.agents/skills/pln && ./setup   # Codex
```

`setup` works out the host from the install path (`~/.claude/skills/pln` → Claude Code, `~/.agents/skills/pln` → Codex) and writes the real `SKILL.md` over this file. If the path carries no such marker — a clone somewhere else, symlinked into place — set the host explicitly: `PLN_HOST=codex ./setup`.

Do not plan a task from this file. It has none of the workflow.
