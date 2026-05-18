# pln

**Claude Code skill for human-paced planning — one question at a time — with a peer that pushes back.**

Instead of dumping a complete plan and waiting for you to react, pln interviews you first: one question per item, all design decisions settled, master plan approved — then implements without stopping to ask more questions. During the interview phase it acts as a thinking peer, not a task executor: it'll push back on a bad approach before any code is written.

Ships with **`/plnify gstack`** to extend pln's discipline to [gstack](https://github.com/daniel-nelson/gstack) planning skills.

## Install

### Install via your agent

Requires [Git](https://git-scm.com/).

#### Claude Code

**1. Install on your machine** — open Claude Code and paste:

```
Install pln: run `git clone https://github.com/daniel-nelson/pln.git ~/.claude/skills/pln && cd ~/.claude/skills/pln && ./setup`
```

**2. Add to your project (optional):**

```
Add pln to this project: run `cp -Rf ~/.claude/skills/pln .claude/skills/pln && rm -rf .claude/skills/pln/.git && cd .claude/skills/pln && ./setup`
```

Real files get committed to your repo (not a submodule), so `git clone` just works for teammates. They just need to run `cd .claude/skills/pln && ./setup` once.

#### Codex

**1. Install on your machine** — open Codex and paste:

```
Install pln: run `git clone https://github.com/daniel-nelson/pln.git ~/.codex/skills/pln && cd ~/.codex/skills/pln && ./setup`
```

**2. Add to your project (optional):**

```
Add pln to this project: run `cp -Rf ~/.codex/skills/pln .codex/skills/pln && rm -rf .codex/skills/pln/.git && cd .codex/skills/pln && ./setup`
```

### Install via `npx skills`

```bash
npx skills add daniel-nelson/pln
```

It will prompt you for which agent to install to. For more details, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

### What gets installed

- `pln` skill in `~/.claude/skills/pln/` (or project-local at `.claude/skills/pln/`)
- `/plnify` slash command (symlinked from `pln/plnify/`) for installing pln's discipline into gstack

Everything lives inside your assistant's skills directory. Nothing touches your PATH or runs in the background.

## What you get

| Skill | How to invoke | Description |
|-------|--------------|-------------|
| `/pln` | `/pln <task>` or say "make a plan" | Two-phase planning: interview all items, then implement one at a time |
| `/plnify` | `/plnify gstack` | One-time setup — adds pln's discipline to `~/.claude/CLAUDE.md` for gstack planning skills |

## How it works

**`/pln`** runs a complete interview phase before writing a single line of code. For each item it proposes an approach, asks one question at a time, and records every decision into a `PLAN.md`. Once you approve the master plan, it implements items silently — no further design questions unless something unexpected surfaces. Plans are saved to `./plans/<date>-<slug>/PLAN.md` relative to wherever you launched Claude.

The peer posture is built in: during the interview phase, pln will disagree with your framing if it sees a problem, bring up considerations you didn't name, and stop after one question rather than overwhelming you with options. The goal is a plan *you* shaped, not one that was handed to you.

**`/plnify gstack`** is a one-time setup step for [gstack](https://github.com/daniel-nelson/gstack) users. It appends two sections to your `~/.claude/CLAUDE.md` — interaction rules and an exploratory-mode posture — that apply pln's discipline to gstack planning skills like `/office-hours`, `/plan-ceo-review`, and `/plan-eng-review`. It shows you exactly what will be written and asks for approval before touching anything. The rules only fire when a gstack planning skill is active; they don't affect general conversation.

## Upgrading

```bash
# Claude Code — personal install
cd ~/.claude/skills/pln && git fetch origin && git reset --hard origin/main && ./setup

# Claude Code — project install
rm -rf .claude/skills/pln
cp -Rf ~/.claude/skills/pln .claude/skills/pln
rm -rf .claude/skills/pln/.git
cd .claude/skills/pln && ./setup

# Codex — personal install
cd ~/.codex/skills/pln && git fetch origin && git reset --hard origin/main && ./setup

# Codex — project install
rm -rf .codex/skills/pln
cp -Rf ~/.codex/skills/pln .codex/skills/pln
rm -rf .codex/skills/pln/.git
cd .codex/skills/pln && ./setup
```

## Uninstalling

```bash
# Claude Code
rm -rf ~/.claude/skills/pln
rm -f ~/.claude/skills/plnify
rm -rf .claude/skills/pln
rm -f .claude/skills/plnify

# Codex
rm -rf ~/.codex/skills/pln
rm -f ~/.codex/skills/plnify
rm -rf .codex/skills/pln
rm -f .codex/skills/plnify
```

If you ran `/plnify gstack`, the two sections it added to `~/.claude/CLAUDE.md` are not automatically removed — delete them manually if you no longer want them.

## License

MIT
