---
name: pln-pr
description: Review a branch and put up a pull request, the pln way — a fresh-context review army finds issues, a fix pass clears them under one durable ledger, and the gauntlet runs once before the PR opens. Six self-contained review lenses plus an adversarial pass (and a cross-model pass when available) run as fresh-context agents; findings land in `REVIEW.md`; fixes run as clustered fix agents; verification happens once at the end, not per fix cycle. Universal — depends only on git, the harness's own agents, and optionally the GitHub/GitLab CLI. No external service, no server, no gstack. Trigger explicitly via `/pln-pr`, or when the user asks to put up / open / create / make a PR or "ship it" — including when that ask is embedded in a larger instruction like "bump the version and open the PR", "and open the PR", or "push this up". Typically right after a `/pln` run, but works standalone on any branch with commits ahead of its base. A larger imperative that ends in opening a PR still routes here; do not push and run `gh pr create` directly for it unless the user explicitly says to skip the review.
---

# pln-pr — not built yet

This is the placeholder that ships in git. The real skill is generated per host from the sources in `src/`, so that the copy you read contains the mechanics for *your* agent host and nothing addressed to the other one.

Run the `setup` script in the pln directory one level up from this file. You know where this file lives, so run it yourself rather than handing the command to the user; invoking it by its full path works from any directory, since it works out its own. Then tell the user to restart the agent, which is the one part of this you can't do for them.

`setup` works out the host from the install path (`~/.claude/skills/pln` → Claude Code, `~/.agents/skills/pln` → Codex) and writes the real `SKILL.md` over this file. If this copy sits somewhere the path doesn't name a host, pass your own host in the environment: `PLN_HOST=claude` or `PLN_HOST=codex`.

Do not review a branch or open a PR from this file. It has none of the workflow.
