# pln

**Human-paced planning — one question at a time — with a peer that pushes back.**

Instead of dumping a complete plan and waiting for you to react, pln interviews you first: one question per item, all design decisions settled, master plan approved — then implements without stopping to ask more questions. During the interview phase it acts as a thinking peer, not a task executor: it'll push back on a bad approach before any code is written.

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

Codex loads skills from both `~/.agents/skills/` and `~/.codex/skills/`. `~/.agents/skills/pln` is the path to use — it is the one Codex documents, and it is where `/pln-update` looks.

### Install via `npx skills`

```bash
npx skills add daniel-nelson/pln
```

It will prompt you for which agent to install to. For more details, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

Then run `./setup` in the directory it installed to. `npx skills` copies files; it doesn't run a repo's install script, and pln's `setup` is what builds the skill files for your host (see below). Running it twice is harmless, so run it either way if you're unsure.

### What gets installed

- `pln` skill in `~/.claude/skills/pln/` (Claude Code) or `~/.agents/skills/pln/` (Codex)
- `/pln-pr` slash command (symlinked from `pln/pln-pr/`) for reviewing a branch and opening a pull request
- `/pln-update` slash command (symlinked from `pln/pln-update/`) for updating pln

`./setup` also builds the skill files for the host it was installed under, working the host out from the install path. Claude Code and Codex drive agents differently, so each build carries only its own host's mechanics rather than a page of "if you are on the other host, ignore this". That is the one reason the clone alone isn't enough: without `./setup` the skill files are placeholders that say so. If you cloned somewhere the path doesn't name a host, run `PLN_HOST=codex ./setup` (or `PLN_HOST=claude ./setup`).

Everything lives inside your assistant's skills directory. Nothing touches your PATH or runs in the background.

## What you get

| Skill | How to invoke | Description |
|-------|--------------|-------------|
| `/pln` | `/pln` or `/pln <details of what you want to plan>` | Two-phase planning: overview bullet list followed by detailed back and forth with a peer for each item; implementation only after the plan is written |
| `/pln-pr` | `/pln-pr` or "put up a PR" | Review the current branch with a fresh-context review army, fix findings under one durable ledger, verify once, and open the pull request |
| `/pln-update` | `/pln-update` | Update pln to the latest version (pln also offers this automatically when a new release appears) |

## How it works

**`/pln`** runs a complete interview phase before writing a single line of code. For each item it proposes an approach, asks one question at a time, and records every decision into a `PLAN.md`. Once you approve the master plan, the main session becomes a thin orchestrator and implements the whole plan autonomously: it spawns a fresh subagent for each item in turn, with `PLAN.md` as the spec, so the plan runs to completion without per-item intervention. If a subagent hits something the plan didn't settle, it hands off — leaving its work uncommitted with a handoff note — and the orchestrator surfaces a single question, records your answer, and resumes from where it stopped. Plans are saved to `./plans/<date>-<slug>/PLAN.md` relative to wherever you launched your agent.

The peer posture is built in: during the interview phase, pln will disagree with your framing if it sees a problem, bring up considerations you didn't name, and stop after one question rather than overwhelming you with options. The goal is a plan *you* shaped, not one that was handed to you.

**`/pln-pr`** is the ship half of a plan. After a `/pln` run (or on any branch ahead of its base), it reviews the diff, fixes what the review finds, verifies once, and opens the pull request. A review army of fresh-context agents covers six lenses (correctness, security, data, testing, maintainability, performance) plus an adversarial pass. On Claude Code they all run in parallel, plus an optional Codex cross-model pass if you have it installed; on Codex the army is `codex review` for the broad ground followed by the lenses it underweights, one at a time (see [Hosts](#hosts)). Every finding has to quote the exact line that proves it, which keeps false positives out. Findings land in a durable `REVIEW.md` beside the plan, fixes run as agents clustered by file so they never collide, decisions come to you one at a time, and the full test suite runs **once** at the end instead of after every fix — the loop that makes a naive review-and-fix pass thrash. It depends only on git, your agent's own tools, and optionally the GitHub/GitLab CLI; there's no external service and nothing to configure. So that a compound request like "bump the version and open the PR" still routes through the review instead of bypassing it, install offers a small opt-in routing rule for your global instructions — previewed, and written only if you say yes.

## Hosts

pln runs on **Claude Code** and **Codex**. `./setup` works out which from the install path and builds the skill files for it, so what your agent reads is the mechanics of the host it is actually on.

The plan is the same on both hosts, and so is the `PLAN.md` and the review ledger. What changes is the machinery underneath:

| | Claude Code | Codex |
|---|---|---|
| Fresh-context agents | the harness `Workflow` / `Agent` tools | `codex exec`, one process per agent |
| `/pln` implementation loop | one Workflow script drives every item | the orchestrator drives the loop from the shell |
| Resuming a blocked item | `resumeFromRunId` | `codex exec resume <thread-id>` |
| Who commits | the item agent | the orchestrator — a sandboxed Codex agent has `.git` read-only |
| `/pln-pr` review army | seven reviewers in parallel, plus an optional Codex cross-model pass | `codex review`, then a subset of lenses one at a time |
| Notifications | phone push + desktop | desktop |

Two of those need a sentence. Codex reviewers run one at a time because concurrent `codex` processes race on the shared OAuth token file; that costs wall-clock and buys correctness. And a Codex agent runs sandboxed with `.git` read-only, so it writes files and reports back while the session that spawned it does the committing. The invariant is the same on both hosts: no partial item is ever committed.

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

An implementation run can take a while, and you'll often step away from it. pln notifies you at the three moments it needs you back — an interview question is waiting, a subagent is blocked on a decision, or the plan finished — over these channels, all on by default:

- **Phone push** (Claude Code only) — through your agent's own notification (no account or third-party service). Reaches your phone when you're away and stays quiet when you're watching the terminal. Codex has no equivalent a skill can fire at a chosen moment — its `notify` hook is user-configured and fires on turn completion — so on Codex the desktop notification is the whole story.
- **Local desktop notification** — a native macOS or Linux notification, so you're notified when you're at the computer, where the phone push stays silent. Works on both hosts.

Each toggles independently in `~/.pln/config.yaml`:

- `notify_push: false` — turn off the phone push. Claude Code only; ignored on Codex.
- `notify_desktop: false` — turn off the local desktop notification.
- `notify_desktop_persist: true` — make the desktop notification stay on screen until you dismiss it, instead of vanishing on its own (handy if you tend to miss auto-disappearing banners).

## Uninstalling

If you added the `/pln-pr` routing rule to your global instructions, strip it first, while the helper is still on disk — it removes the block from whichever file it wrote to (`~/.claude/CLAUDE.md` on Claude Code, `$CODEX_HOME/AGENTS.md` on Codex):

```bash
# Claude Code
~/.claude/skills/pln/bin/pln-routing-rule --remove

# Codex
~/.agents/skills/pln/bin/pln-routing-rule --remove
```

It's idempotent, so it's safe to run whether or not you ever added the rule. Then remove the skill:

```bash
# Claude Code
rm -rf ~/.claude/skills/pln && rm -f ~/.claude/skills/pln-update ~/.claude/skills/pln-pr

# Codex
rm -rf ~/.agents/skills/pln && rm -f ~/.agents/skills/pln-update ~/.agents/skills/pln-pr
```

To also remove update-check state: `rm -rf ~/.pln`.

## License

MIT
