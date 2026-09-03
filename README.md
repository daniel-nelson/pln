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

Codex loads skills from both `~/.agents/skills/` and `~/.codex/skills/`. `~/.agents/skills/pln` is the path to use — it is the one Codex documents, and it is where pln-update looks.

### Install via `npx skills`

```bash
npx skills add daniel-nelson/pln
```

It will prompt you for which agent to install to. For more details, see [vercel-labs/skills](https://github.com/vercel-labs/skills).

Then run `./setup` in the directory it installed to. `npx skills` copies files; it doesn't run a repo's install script, and pln's `setup` is what builds the skill files for your host (see below). Running it twice is harmless, so run it either way if you're unsure.

### What gets installed

- `pln` skill in `~/.claude/skills/pln/` (Claude Code) or `~/.agents/skills/pln/` (Codex)
- `pln-pr` (symlinked from `pln/pln-pr/`) for reviewing a branch and opening a pull request
- `pln-simplify` (symlinked from `pln/pln-simplify/`) for recurring concept and ownership simplification
- `pln-update` (symlinked from `pln/pln-update/`) for updating pln

`./setup` also builds the skill files for the host it was installed under, working the host out from the install path. Claude Code and Codex drive agents differently, so each build carries only its own host's mechanics rather than a page of "if you are on the other host, ignore this". That is the one reason the clone alone isn't enough: without `./setup` the skill files are placeholders that say so. If you cloned somewhere the path doesn't name a host, run `PLN_HOST=codex ./setup` (or `PLN_HOST=claude ./setup`).

Everything lives inside your assistant's skills directory. Nothing touches your PATH or runs in the background.

## What you get

Claude Code invokes a skill as a slash command; Codex has no slash commands and invokes one by name with a `$` prefix, so `/pln` is an error there. Both spellings are given below.

| Skill | How to invoke (Claude Code) | How to invoke (Codex) | Description |
|-------|--------------|--------------|-------------|
| `pln` | `/pln` or `/pln <details of what you want to plan>` | `$pln` or `$pln <details of what you want to plan>` | Two-phase planning: overview bullet list followed by detailed back and forth with a peer for each item; implementation only after the plan is written |
| `pln-pr` | `/pln-pr` or "put up a PR" | `$pln-pr` or "put up a PR" | Review the current branch with a fresh-context review army, fix findings under one durable ledger, verify once, and open the pull request |
| `pln-simplify` | `/pln-simplify` or a deliberate codebase-simplification request | `$pln-simplify` or a deliberate codebase-simplification request | Map concepts and owners, adopt bounded consolidation or retirement, verify an unpublished exact candidate, and record the successful assessment |
| `pln-update` | `/pln-update` | `$pln-update` | Update pln to the latest version (pln also offers this automatically when a new release appears) |

## How it works

**`/pln`** runs a complete interview phase before writing a single line of code. It first shows an editable chapter-outline view, then asks one question at a time and records every decision into `PLAN.md`. Once you approve the master plan, the main session becomes a thin orchestrator: it derives a conservative dependency graph, runs independent items in isolated worktrees in waves of at most three, and keeps uncertain or overlapping work serial. A durable manifest, item-level checkpoints, and retained blocker worktrees let a restarted session continue without trusting conversational memory or a surviving agent handle. On Codex, every quiet subagent wait is reconciled against the native agent list and a manifest finish check prevents the coordinator from ending its turn while implementation remains. If you explicitly ask Codex to persist across turns to a verifiable endpoint—“I am going to sleep; work through completion and open the green PR,” for example—pln also uses a native durable goal when that session exposes one, without making it a new permission gate. Plans are saved to `./plans/<date>-<slug>/PLAN.md` relative to wherever you launched your agent.

The peer posture is built in: during the interview phase, pln will disagree with your framing if it sees a problem, bring up considerations you didn't name, and stop after one question rather than overwhelming you with options. The goal is a plan *you* shaped, not one that was handed to you.

**`/pln-pr`** is the ship half of a plan. After a `/pln` run (or on any branch ahead of its base), it classifies semantic risk, reviews the exact candidate, fixes verified findings, verifies the final tree once, and opens the pull request. R1 routine work gets a fresh broad reviewer; R2 adds up to two applicable specialists; R3 adds an adversarial slot, filled by a permitted cross-model peer or a truthfully attributed same-model substitute. Findings cite exact evidence and are recorded as verified, unverified, or disproved in a durable `REVIEW.md`. Newly verified, unambiguous, in-scope defects continue through repair and fresh assurance without another permission prompt. The unattended flow stops only after three failed repairs of the same reproduced defect or at a genuine user-owned boundary. Disjoint fix clusters may run in isolated worktrees, while the coordinator alone owns the ledger, commits, and integration. Native workers, peers, and CI watches remain attached to the current parent turn until their terminal state, so the host's own activity UI stays authoritative. Any fix creates a new candidate fingerprint, so stale gauntlet evidence is never reused. It depends only on git, native host agents, and optionally the GitHub/GitLab CLI and a peer CLI.

**`/pln-simplify`** is recurring counter-pressure to cumulative additions. Fresh workers map concepts, owners, dependencies, duplicated policy, compatibility paths, and obsolete surfaces, then propose only bounded behavior-preserving consolidation. It reuses `/pln` for interviewing, approval, scheduling, implementation, blockers, and assurance. `nothing worth changing` is a valid verified result. Success is recorded by one exact marker-bearing commit on an unpublished ref; the full gauntlet must pass before the working branch fast-forwards to that unchanged commit. A later `/pln-pr` copies the still-valid marker into the PR description on a best-effort basis.

Cadence is advisory by default. V1 treats changed content as due at 100 visible commits or 90 days and overdue at 250 commits or 180 days; unchanged content remains fresh, and missing or stripped history is `unknown`, never fabricated staleness. A repository can commit `.pln-simplify-policy` with `schema=1`, `mode=advisory|required|disabled`, `minimum-client=1`, `protocol=1`, and optional `due-commits`, `overdue-commits`, `due-days`, and `overdue-days` overrides. Required mode affects policy-aware `/pln-pr` clients; true repository-wide enforcement remains an optional repository-owned CI/branch-protection check.

## Hosts

pln runs on **Claude Code** and **Codex**. `./setup` works out which from the install path and builds the skill files for it, so what your agent reads is the mechanics of the host it is actually on.

The plan is the same on both hosts, and so is the `PLAN.md` and the review ledger. What changes is the machinery underneath:

| | Claude Code | Codex |
|---|---|---|
| Fresh-context agents | native `Agent`; `Workflow` for genuine fan-out | native multi-agent collaboration tools |
| `/pln` implementation | coordinator-scheduled isolated Agent worktrees | coordinator-created git worktrees plus native agents |
| Continuing a blocked item | named Agent + `SendMessage` | durable manifest + `followup_task`, or a fresh recovery agent |
| Who commits and integrates | the coordinator | the coordinator |
| `/pln-pr` review | risk-capped Workflow fan-out | risk-capped native reviewer fan-out |
| Unattended liveness | tracked native workers/monitors remain attached to the parent turn | tracked native workers/command sessions remain attached; mailbox reconciliation + manifest finish gate; native goal for explicit across-turn requests when available |
| Cross-model pass | reaches for `codex`, or whatever `peer_command` names | reaches for `claude`, or whatever `peer_command` names |
| Notifications | phone push + desktop | desktop |

Both hosts preserve the same invariants: uncertainty serializes, write leases cannot overlap, no partial item is integrated, and `PLAN.md` / `REVIEW.md` stay coordinator-owned. Nested `claude` or `codex exec` processes are guarded fallbacks for older or policy-disabled hosts, not the normal orchestration path.

## Model routing and behavioral evals

Same-host workers, including judgment-bearing planning, implementation, and review work, inherit the model you selected. pln does not classify capability from an alias, silently replace a lower-tier selection, or stop on an unfamiliar model name. `judgment` remains the semantic profile for decision-bearing work and requests high effort. An optional `evidence_profile: economy` lane is limited to mechanically closed facts and citations; because it deliberately selects a different model, that exact host/model route remains version-qualified, and anything requiring interpretation escalates before it can recommend or decide.

The release corpus under `evals/corpus/` is synthetic and sanitized. `bin/pln-eval validate` and `bash tests/evals.sh` are deterministic, offline checks; they never call an agent CLI. Real comparisons are explicit through `bin/pln-eval run-live`, record the actual selected profile/model/effort, CLI and skill versions, commit and fixture hashes, reported tokens/cost where available, latency, fallbacks, and artifacts, and keep the untouched holdout sealed until calibration freezes a variance-derived benefit threshold. A failing or undersized host/class result disables that economy route in `evals/economy-qualification.tsv` rather than weakening a correctness or privacy floor; an opted-in but unqualified route falls back to the inherited model with the reason recorded.

## The plan review

Before you're asked to adopt a master plan, the plan itself goes under review: a reader that never saw the interview goes through it cold, argues with it, and checks its factual claims against the files it names. Plain mistakes are corrected in the plan, and only when the correction quotes the file and line it rests on; anything that turns on your taste or your call arrives at the approval gate flagged, numbered alongside everything else you can reopen there. A decision you made in the interview is never one of the things it corrects — a review that disagrees with one flags it, with what it found, for you to reopen. Where you have a second agent CLI it's a different model doing the reading (see [Second opinions](#second-opinions)); where you don't, it's a fresh agent of the same one.

What the reviewer gets is the plan and nothing else — never the conversation that produced it, and never anything you typed that didn't end up in the plan. A reviewer that would have needed the transcript has found something about the plan worth telling you.

It runs on every plan — there's no shortcut for a short one, because a two-item plan that changes how everything afterwards behaves is often the riskier one. Two ways to switch it off:

- **For good**, in `~/.pln/config.yaml`:

  ```bash
  ~/.claude/skills/pln/bin/pln-config set plan_review false
  ```

- **For one plan**, by saying so before the gate: "skip the review". You can switch off just part of it, too — "skip the cross-model pass" keeps the review but keeps the plan on your machine, and "flag everything" runs it without letting it change the plan. Saying so never changes the config setting, and it works in the other direction as well: "review this one" on a machine where the key is off.

## Second opinions

Where a second model is worth more than another run of the same one — the plan review above, `/pln-pr`'s cross-model pass — pln reaches for an agent CLI that isn't the one running your session, in this order:

1. **A command you named.** `peer_command` in `~/.pln/config.yaml` is your whole invocation, so it can be a tool pln has never heard of. The contract is a pipe: it reads its prompt on stdin and writes its answer on stdout.

   ```bash
   ~/.claude/skills/pln/bin/pln-config set peer_command "gemini -p"
   ```

2. **A known CLI on your `PATH`** — `claude` or `codex`, whichever isn't hosting the session, and only when it is signed in. Under Codex it asks Claude; under Claude it asks Codex. Probes ship only for CLIs whose invocation pln has actually reproduced; anything else goes through the first rung, where you supply the invocation.
3. **Nothing at all**, which is a supported answer and not a broken install. The work still happens — on a fresh same-model agent where a fresh reading is the point, or skipped with a note where a different model was the whole point.

The first two rungs hand the material to another vendor's CLI: it leaves your machine, and the call can spend your quota there. At the beginning of the first `/pln` or `/pln-pr` invocation where a usable peer exists, pln asks once for global cross-provider consent and remembers the answer. On the next invocation it asks once for a standing egress policy. With `consent`, pln sends any material not marked sensitive or local-only without asking again. With `approved-only`, it sends only material explicitly approved for peer egress; other material stays local without prompting. A suppressed, unavailable, malformed, or failed R3 peer is replaced by one fresh same-model adversarial reader and attributed as such; it is never counted as a clean peer result.

Change your mind later, in either direction:

```bash
~/.claude/skills/pln/bin/pln-config set peer_consent false
~/.claude/skills/pln/bin/pln-config set peer_egress approved-only
```

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

An implementation run can take a while, and you'll often step away from it. pln notifies you before every turn that waits for your input—including first-use configuration, outline/adoption gates, recovery questions, and blockers—and when the plan finishes. Predictable peer configuration is checked at the very beginning of every `/pln` or `/pln-pr` invocation; it never appears for the first time after long-running work has begun. Channels are on by default:

- **Phone push** (Claude Code only) — through your agent's own notification (no account or third-party service). Reaches your phone when you're away and stays quiet when you're watching the terminal. Codex has no equivalent a skill can fire at a chosen moment — its `notify` hook is user-configured and fires on turn completion — so on Codex the desktop notification is the whole story.
- **Local desktop notification** — a native macOS or Linux notification, so you're notified when you're at the computer, where the phone push stays silent. Works on both hosts.

Each toggles independently in `~/.pln/config.yaml`:

- `notify_push: false` — turn off the phone push. Claude Code only; ignored on Codex.
- `notify_desktop: false` — turn off the local desktop notification.
- `notify_desktop_persist: true` — make the desktop notification stay on screen until you dismiss it, instead of vanishing on its own (handy if you tend to miss auto-disappearing banners).

## Uninstalling

pln never edits your global instructions or anything else outside its own install and `~/.pln`, so uninstalling is deleting those:

```bash
# Claude Code
rm -rf ~/.claude/skills/pln && rm -f ~/.claude/skills/pln-update ~/.claude/skills/pln-pr

# Codex
rm -rf ~/.agents/skills/pln && rm -f ~/.agents/skills/pln-update ~/.agents/skills/pln-pr
```

To also remove update-check state: `rm -rf ~/.pln`.

## License

MIT
