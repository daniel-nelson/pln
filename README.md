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
Install pln: run `git clone https://github.com/daniel-nelson/pln.git ~/.agents/skills/pln && cd ~/.agents/skills/pln && ./setup`
```

### Install via `npx skills`

```bash
npx skills add daniel-nelson/pln
```

It will prompt you for which agent to install to. For more details, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

### What gets installed

- `pln` skill in `~/.claude/skills/pln/`
- `/pln-pr` slash command (symlinked from `pln/pln-pr/`) for reviewing a branch and opening a pull request
- `/plnify` slash command (symlinked from `pln/plnify/`) for installing pln's discipline into gstack
- `/pln-update` slash command (symlinked from `pln/pln-update/`) for updating pln

Everything lives inside your assistant's skills directory. Nothing touches your PATH or runs in the background.

## What you get

| Skill | How to invoke | Description |
|-------|--------------|-------------|
| `/pln` | `/pln` or `/pln <details of what you want to plan>` | Two-phase planning: overview bullet list followed by detailed back and forth with a peer for each item; implementation only after the plan is written |
| `/pln-pr` | `/pln-pr` or "put up a PR" | Review the current branch with a fresh-context review army, fix findings under one durable ledger, verify once, and open the pull request |
| `/plnify` | `/plnify gstack` | One-time setup — adds pln's discipline to `~/.claude/CLAUDE.md` for gstack planning skills |
| `/pln-update` | `/pln-update` | Update pln to the latest version (pln also offers this automatically when a new release appears) |

## How it works

**`/pln`** runs a complete interview phase before writing a single line of code. For each item it proposes an approach, asks one question at a time, and records every decision into a `PLAN.md`. Once you approve the master plan, the main session becomes a thin orchestrator and implements the whole plan autonomously: it spawns a fresh subagent for each item in turn, with `PLAN.md` as the spec, so the plan runs to completion without per-item intervention. If a subagent hits something the plan didn't settle, it hands off — leaving its work uncommitted with a handoff note — and the orchestrator surfaces a single question, records your answer, and resumes from where it stopped. Plans are saved to `./plans/<date>-<slug>/PLAN.md` relative to wherever you launched Claude.

The peer posture is built in: during the interview phase, pln will disagree with your framing if it sees a problem, bring up considerations you didn't name, and stop after one question rather than overwhelming you with options. The goal is a plan *you* shaped, not one that was handed to you.

**`/pln-pr`** is the ship half of a plan. After a `/pln` run (or on any branch ahead of its base), it reviews the diff, fixes what the review finds, verifies once, and opens the pull request. A review army of fresh-context subagents runs in parallel — six lenses (correctness, security, data, testing, maintainability, performance) plus an adversarial pass, and an optional Codex cross-model pass if you have it installed. Every finding has to quote the exact line that proves it, which keeps false positives out. Findings land in a durable `REVIEW.md` beside the plan, fixes run as subagents clustered by file so they never collide, decisions come to you one at a time, and the full test suite runs **once** at the end instead of after every fix — the loop that makes a naive review-and-fix pass thrash. It depends only on git, the harness tools, and optionally the GitHub/GitLab CLI and Codex; there's no external service and nothing to configure. So that a compound request like "bump the version and open the PR" still routes through the review instead of bypassing it, install offers a small opt-in routing rule for your global instructions — previewed, and written only if you say yes.

**`/plnify gstack`** is a one-time setup step for [gstack](https://github.com/daniel-nelson/gstack) users. It appends two sections to your `~/.claude/CLAUDE.md` — interaction rules and an exploratory-mode posture — that apply pln's discipline to gstack planning skills like `/office-hours`, `/plan-ceo-review`, and `/plan-eng-review`. It shows you exactly what will be written and asks for approval before touching anything. The rules only fire when a gstack planning skill is active; they don't affect general conversation.

## Upgrading

pln checks for a new release each time it runs (throttled, no background process). When one is available it offers to upgrade and remembers your choice — upgrade once, always auto-upgrade silently, snooze, or turn checks off. You can also update explicitly anytime:

```
/pln-update
```

To opt into silent auto-upgrades without being asked, set `auto_upgrade: true` in `~/.pln/config.yaml` (or choose "always keep me up to date" when prompted). To stop update checks, set `update_check: false` there.

If you prefer to do it by hand:

```bash
# Claude Code
cd ~/.claude/skills/pln && git fetch origin && git reset --hard origin/main && ./setup

# Codex
cd ~/.agents/skills/pln && git fetch origin && git reset --hard origin/main && ./setup
```

## Notifications

An implementation run can take a while, and you'll often step away from it. pln notifies you at the three moments it needs you back — an interview question is waiting, a subagent is blocked on a decision, or the plan finished — over two independent channels, both on by default:

- **Phone push** — through your agent's own notification (no account or third-party service). Reaches your phone when you're away and stays quiet when you're watching the terminal.
- **Local desktop notification** — a native macOS or Linux notification, so you're notified when you're at the computer, where the phone push stays silent.

Each toggles independently in `~/.pln/config.yaml`:

- `notify_push: false` — turn off the phone push.
- `notify_desktop: false` — turn off the local desktop notification.
- `notify_desktop_persist: true` — make the desktop notification stay on screen until you dismiss it, instead of vanishing on its own (handy if you tend to miss auto-disappearing banners).

## Uninstalling

```bash
# Claude Code
rm -rf ~/.claude/skills/pln && rm -f ~/.claude/skills/plnify ~/.claude/skills/pln-update

# Codex
rm -rf ~/.agents/skills/pln && rm -f ~/.agents/skills/plnify ~/.agents/skills/pln-update
```

To also remove update-check state: `rm -rf ~/.pln`.

If you ran `/plnify gstack`, the two sections it added to `~/.claude/CLAUDE.md` are not automatically removed — delete them manually if you no longer want them.

## License

MIT
