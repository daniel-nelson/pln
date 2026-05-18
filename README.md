# pln

Personal multi-item planning workflow for Claude Code. Two strict phases — interview then implement — so you never end up answering question 2 while half of item 1 is already built.

Ships with **`/plnify gstack`** to extend pln's discipline to [gstack](https://github.com/daniel-nelson/gstack) planning skills.

## Install

Ask Claude Code to install it:

> Install the pln skill from github.com/daniel-nelson/pln

Or manually:

```bash
git clone git@github.com:daniel-nelson/pln.git ~/.claude/skills/pln
~/.claude/skills/pln/setup
```

For a project-local install (applies only in this repo):

```bash
git clone git@github.com:daniel-nelson/pln.git .claude/skills/pln
.claude/skills/pln/setup
```

## What you get

| Skill | How to invoke | Description |
|-------|--------------|-------------|
| `/pln` | `/pln <task>` or say "make a plan" | Two-phase planning: interview all items, then implement one at a time |
| `/plnify` | `/plnify gstack` | One-time installer — adds pln's discipline to your `~/.claude/CLAUDE.md` for gstack planning skills |

## How it works

**`/pln`** runs a complete interview phase to resolve every open question across all items before a single line of code is written. Once you approve the master plan, it implements items one at a time without revisiting design questions. Plans are saved to `./plans/<date>-<slug>/PLAN.md` in whatever directory you launched Claude from.

**`/plnify gstack`** is a one-time setup step for [gstack](https://github.com/daniel-nelson/gstack) users. It appends two sections to your `~/.claude/CLAUDE.md`:

- **Interaction rules** — enforces one question per turn and a consistent option format across all skill interactions.
- **Exploratory mode** — when a planning-flavored gstack skill is active (`/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, etc.), Claude behaves like a thinking peer rather than a deliverable factory: explores first, produces artifacts only when you signal readiness.

`/plnify` shows you exactly what will be written and asks for your approval before touching anything.

## Upgrade

```bash
cd ~/.claude/skills/pln && git pull
```

Project-local install:

```bash
cd .claude/skills/pln && git pull
```

No restart required — skills are loaded fresh each session.

## Uninstall

```bash
rm -rf ~/.claude/skills/pln ~/.claude/skills/plnify
```

Project-local:

```bash
rm -rf .claude/skills/pln .claude/skills/plnify
```

If you ran `/plnify gstack`, the two sections it added to `~/.claude/CLAUDE.md` are not automatically removed. Delete them manually if you no longer want them.
