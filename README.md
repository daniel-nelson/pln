# pln

**Human-paced planning — one question at a time — with a peer that pushes back.**

Instead of dumping a complete plan and waiting for you to react, pln interviews you first: one question per item, all design decisions settled, master plan approved — then implements without stopping to ask more questions. During the interview phase it acts as a thinking peer, not a task executor: it'll push back on a bad approach before any code is written.

Ships with **`/plnify gstack`** to extend pln's discipline to [gstack](https://github.com/daniel-nelson/gstack) planning skills.

## Install

### Install via your agent

Requires [Git](https://git-scm.com/).

#### Claude Code

Open Claude Code and paste:

```
Install pln: run `git clone https://github.com/daniel-nelson/pln.git ~/.claude/skills/pln && cd ~/.claude/skills/pln && ./setup`
```

#### Codex

Open Codex and paste:

```
Install pln: run `git clone https://github.com/daniel-nelson/pln.git ~/.codex/skills/pln && cd ~/.codex/skills/pln && ./setup`
```

### Install via `npx skills`

```bash
npx skills add daniel-nelson/pln
```

It will prompt you for which agent to install to. For more details, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

### What gets installed

- `pln` skill in `~/.claude/skills/pln/`
- `/plnify` slash command (symlinked from `pln/plnify/`) for installing pln's discipline into gstack

Everything lives inside your assistant's skills directory. Nothing touches your PATH or runs in the background.

## What you get

| Skill | How to invoke | Description |
|-------|--------------|-------------|
| `/pln` | `/pln` or `/pln <details of what you want to plan>` | Two-phase planning: overview bullet list followed by detailed back and forth with a peer for each item; implementation only after the plan is written |
| `/plnify` | `/plnify gstack` | One-time setup — adds pln's discipline to `~/.claude/CLAUDE.md` for gstack planning skills |

## How it works

**`/pln`** runs a complete interview phase before writing a single line of code. For each item it proposes an approach, asks one question at a time, and records every decision into a `PLAN.md`. Once you approve the master plan, the main session becomes a thin orchestrator and implements the whole plan autonomously: it spawns a fresh subagent for each item in turn, with `PLAN.md` as the spec, so the plan runs to completion without per-item intervention. If a subagent hits something the plan didn't settle, it hands off — leaving its work uncommitted with a handoff note — and the orchestrator surfaces a single question, records your answer, and resumes from where it stopped. Plans are saved to `./plans/<date>-<slug>/PLAN.md` relative to wherever you launched Claude.

The peer posture is built in: during the interview phase, pln will disagree with your framing if it sees a problem, bring up considerations you didn't name, and stop after one question rather than overwhelming you with options. The goal is a plan *you* shaped, not one that was handed to you.

**`/plnify gstack`** is a one-time setup step for [gstack](https://github.com/daniel-nelson/gstack) users. It appends two sections to your `~/.claude/CLAUDE.md` — interaction rules and an exploratory-mode posture — that apply pln's discipline to gstack planning skills like `/office-hours`, `/plan-ceo-review`, and `/plan-eng-review`. It shows you exactly what will be written and asks for approval before touching anything. The rules only fire when a gstack planning skill is active; they don't affect general conversation.

## Upgrading

```bash
# Claude Code
cd ~/.claude/skills/pln && git fetch origin && git reset --hard origin/main && ./setup

# Codex
cd ~/.codex/skills/pln && git fetch origin && git reset --hard origin/main && ./setup
```

## Uninstalling

```bash
# Claude Code
rm -rf ~/.claude/skills/pln && rm -f ~/.claude/skills/plnify

# Codex
rm -rf ~/.codex/skills/pln && rm -f ~/.codex/skills/plnify
```

If you ran `/plnify gstack`, the two sections it added to `~/.claude/CLAUDE.md` are not automatically removed — delete them manually if you no longer want them.

## License

MIT
