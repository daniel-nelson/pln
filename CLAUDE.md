# pln development workflow

## Audience — this is open source

`/pln` is an open-source skill installed by many people across different setups (Claude Code and Codex, macOS and Linux, solo and team repos). It is not tuned for the maintainer's machine. Design every feature for the general user.

- **No feature may depend on the maintainer's personal accounts, services, hardware, or environment.** No hardcoded keys, personal push channels, private endpoints, or "works because I happen to have X." If a capability isn't present on a fresh install, the skill must still work without it.
- **Prefer capabilities every user already has:** the agent harness's own tools and standard OS commands. Reach for a third-party service only when it's optional and the user configures it themselves.
- **Environment-specific behavior is opt-in and degrades gracefully.** Gate it behind a config key (the existing `notify` / `auto_upgrade` pattern), default to the universal behavior, and no-op cleanly when the dependency is absent — never error or block on something a general user doesn't have.

## Lean into native host tools

When a host ships a native primitive for a job the skill needs — spawning a subagent, running a review, pushing a notification — use it. Do not shell out to reproduce it. On Claude that means the harness's own `Agent` / `Workflow` primitives; on Codex it means the native multi-agent tool rather than nested `codex exec` subprocesses.

The reason is that the reimplementation rots. When pln's Codex spawning was built on nested `codex exec`, a later CLI shipped a native multi-agent feature that is on by default, so the model reached for the native tool anyway while the shell path additionally tripped the host's command-approval reviewer — a stuck loop born entirely of fighting the grain. Native tools also get the host's own guards, approvals, and UI for free, which a subprocess has to re-earn and never fully does.

- **Native first, shell only as fallback.** Reach for a subprocess only where the host has no native primitive for the job, and say so where you do.
- **Preserve the invariants, or drop them on purpose.** A scripted substrate you replace was carrying guarantees (per-item commit checkpoints, fresh context, a non-empty-result guard, sequential ordering). Each must find a home in the native design or be consciously abandoned — never lost silently in the swap.
- **This is host-specific by nature, so it lives in `pln:only` blocks and host fragments,** not the host-neutral core. What is native on one host is absent on the other.

## The skill files are generated — edit `src/`

`SKILL.md` and `pln-pr/SKILL.md` are **build output**. What git tracks at those paths is a placeholder telling the reader to run `./setup`; `bin/pln-generate` overwrites them at install time with a build for the host it was installed under, so a model never reads instructions addressed to the other host.

- Sources: `src/SKILL.core.md` and `src/pln-pr/SKILL.core.md` (host-neutral bodies), `src/hosts/<host>/*.md` (per-host fragments), `src/hosts/<host>/vars` (literal `{{KEY}}` substitutions), `src/shared/*.md` (fragments both hosts get verbatim, so a passage two skills share lives in one file).
- Three directives, deliberately: `<!-- pln:include NAME -->`, `<!-- pln:only <host> -->` … `<!-- pln:endonly -->`, and `{{KEY}}`. If a change seems to need a fourth, that is a signal to move the passage into a fragment instead.
- `pln:include NAME` reads `src/hosts/<host>/NAME.md` and falls back to `src/shared/NAME.md`; a host fragment of the same name wins. A fragment may not include another one, which is why the shared Style section is two files with the host `voice` fragment between them — the cores name all three in order.
- Never commit a generated `SKILL.md`. If one shows as modified, you ran `./setup` in a working clone — `bin/pln-generate --clean` puts the placeholders back.
- Preview a build without touching the tree: `bin/pln-generate --host codex --out-dir /tmp/out`.
- Anything host-specific you add must exist for both hosts. Text that is true on only one belongs in a `pln:only` block, not in the core.

## The initial outline checkpoint is intentional

`/pln` writes and shows the plan skeleton, then stops before the item-by-item interview. Do not remove that stop, merge it into the first interview question, or describe it as redundant permission friction.

The checkpoint gives the user a chapter-outline view before entering the details. It lets them understand the whole shape, strike items that should not be discussed, and add missing items while the plan is still cheap to change. The later master-plan approval gate serves a different purpose: it approves the fully resolved plan before implementation. Both checkpoints stay.

## Voice and register fixes are Claude-specific until proven otherwise

The rules about how the skill *sounds* — cutting padding, the deletion test, not restating a fact three times, not posturing, defining a term before using it — exist because of Claude's register, not because planning needs them. Codex does not exhibit these habits; that is why `src/hosts/codex/voice.md` and `src/hosts/claude/voice.md` are separate files rather than one shared fragment.

- **A new register or verbosity rule goes in `src/hosts/claude/voice.md` only.** Do not add it to Codex's file "for symmetry." Symmetry is the failure mode here: the fix is aimed at a habit only one model has.
- **Touch Codex's voice file only with evidence that Codex needs it** — a real Codex `/pln` transcript showing the problem, not a guess that the rule is universally good. Absent that, leave it.
- **Interview *discipline* is different from register.** Rules about scope, structure, and which evidence to carry are model-neutral and can live in both files. The test: would this rule fire on a model that already writes plainly? If no, it's a register fix and belongs to Claude alone.

This is the one place the host seam is about the *model's* behavior rather than the *host's* mechanics, so it is easy to forget and cross-apply.

## Releases

Every PR that changes skill behavior must include both:

- A version bump in `VERSION`
- A matching entry in `CHANGELOG.md`

**Minor bump** (1.0.0 → 1.1.0): new guidance, reworked explanations, new sections, behavioral changes to `/pln`, `/pln-pr`, or `/pln-update`.  
**Patch bump** (1.0.0 → 1.0.1): typo fixes, factual corrections, wording-only edits that don't change behavior.

One open PR = one version. If scope grows mid-PR, bump the single version heading rather than creating a new entry. Merging to `main` is the publish event — do not create CHANGELOG entries for branches that never merge.

## Opening PRs — this repo skips `/pln-pr`

Always skip `/pln-pr` in this repository. This is the repo that ships `/pln-pr`, and its own changes are verified by the `tests/` gauntlet plus a manual install, not by pointing the review army at the source that defines it. So when `/pln` reaches its Step 8 ship hand-off, or when you are asked to open, create, put up, or "ship" a PR here, treat it as an explicit skip-the-review: commit, push, and open the PR directly with `gh pr create`. Do not invoke `/pln-pr`.

## Testing

Run every script in `tests/` before opening a PR — each needs only bash and git, no network, no agent CLI installed, no credentials, and none of them writes to the working tree or reads the developer's own `~/.pln`. All nine must print `OK`:

- `bash tests/generate.sh` — `bin/pln-generate`: the three directives, the generated-by banner, `--list`, `--clean`, every error path, and the two properties the host seam rests on — each host's build carries its own mechanics and none of the other's, and a `pln:include` resolves against `src/shared/` for a host that has no fragment of that name while a host fragment of the same name still wins (a missing name fails loudly, naming both folders). Checked against the real `src/` — where both skills must carry the whole Style section, the peer ladder behind its consent key, and the plan review's rules, the rung-3 spawn being the one part that differs by host — as well as fixtures.
- `bash tests/config.sh` — `bin/pln-config` and `bin/pln-model-route`: config round trips preserve whole values and exact keys; `evidence_profile` defaults to `inherit`, validates its opt-in, and host-local semantic routing preserves recognized frontier choices, requires deliberate unknown-capability fallback, and attributes unavailable economy fallback.
- `bash tests/codex-agent.sh` — `bin/pln-codex-agent` against a fake `codex` on `PATH`: an empty result is a failure, the thread id comes out of the event stream, the brief travels on stdin, `resume` is never handed the flags it rejects, and fresh spawns carry model/effort controls plus actual-route attribution.
- `bash tests/claude-agent.sh` — `bin/pln-claude-agent` against a fake `claude` on `PATH`: a non-zero exit is a failure even when prose was printed, the peer is restricted with `--tools` and never with `--allowedTools`, `ANTHROPIC_API_KEY` is left alone, and model/effort controls plus actual-route attribution survive the boundary.
- `bash tests/peer.sh` — `bin/pln-peer` against fake `claude`/`codex` CLIs and a scratch `PLN_STATE_DIR`: the three rungs in order, the skip-the-host rule in both directions, the one-time consent gate (nothing is sent in any state until it is granted, `--which` and `--dry-run` included), judgment-only routing attribution, and a peer that is absent, unauthenticated, empty, failed or malformed falling back rather than passing for a review.
- `bash tests/setup.sh` — `setup` against an isolated fake install: the peer nudge retains its settled-state behavior, and the optional economy-evidence notice appears once only when the host route is usable, includes the exact opt-in command, and no-ops cleanly otherwise.
- `bash tests/envelope.sh` — `bin/pln-read-envelope`: valid and exact-boundary envelopes pass, while oversized, missing, out-of-root, final-component symlink, and parent-directory symlink results fail before content reaches stdout.
- `bash tests/worker-contracts.sh` — every worker-owned runtime contract is installed, complete, host-neutral, absent from the generated coordinator prompt, and carries the requested/actual routing envelope; the review-brief helper assembles repository metadata, the exact worker contract, and the complete plan.
- `bash tests/scheduler.sh` — `bin/pln-scheduler`: conservative dependency/write-lease waves, three-item cohorts, non-git and unknown serial fallback, lifecycle transitions, ordered integration, handle-free recovery, and dirty-tree byte protection.

A test that drives a `bin/` helper does it through a fake CLI on `PATH` — never a real `claude` or `codex`, which most users of this repo will not have.

Then install the skill locally, restart the agent, and exercise the changed behavior manually. For `/pln`: run a multi-item task end-to-end, through the Step 8 hand-off, and confirm it reaches `/pln-pr` instead of pushing and running `gh pr create` inline.

A change under `src/` is not exercised until it is built. Preview both hosts with `bin/pln-generate --host claude --out-dir /tmp/pln-claude` and `--host codex --out-dir /tmp/pln-codex` and read the host you changed; `./setup` builds in place for the host you are installed under.
