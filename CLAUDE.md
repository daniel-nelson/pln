# pln development workflow

## Audience — this is open source

`/pln` is an open-source skill installed by many people across different setups (Claude Code and Codex, macOS and Linux, solo and team repos). It is not tuned for the maintainer's machine. Design every feature for the general user.

- **No feature may depend on the maintainer's personal accounts, services, hardware, or environment.** No hardcoded keys, personal push channels, private endpoints, or "works because I happen to have X." If a capability isn't present on a fresh install, the skill must still work without it.
- **Prefer capabilities every user already has:** the agent harness's own tools and standard OS commands. Reach for a third-party service only when it's optional and the user configures it themselves.
- **Environment-specific behavior is opt-in and degrades gracefully.** Gate it behind a config key (the existing `notify` / `auto_upgrade` pattern), default to the universal behavior, and no-op cleanly when the dependency is absent — never error or block on something a general user doesn't have.

## The skill files are generated — edit `src/`

`SKILL.md` and `pln-pr/SKILL.md` are **build output**. What git tracks at those paths is a placeholder telling the reader to run `./setup`; `bin/pln-generate` overwrites them at install time with a build for the host it was installed under, so a model never reads instructions addressed to the other host.

- Sources: `src/SKILL.core.md` and `src/pln-pr/SKILL.core.md` (host-neutral bodies), `src/hosts/<host>/*.md` (per-host fragments), `src/hosts/<host>/vars` (literal `{{KEY}}` substitutions), `src/shared/*.md` (fragments both hosts get verbatim, so a passage two skills share lives in one file).
- Three directives, deliberately: `<!-- pln:include NAME -->`, `<!-- pln:only <host> -->` … `<!-- pln:endonly -->`, and `{{KEY}}`. If a change seems to need a fourth, that is a signal to move the passage into a fragment instead.
- `pln:include NAME` reads `src/hosts/<host>/NAME.md` and falls back to `src/shared/NAME.md`; a host fragment of the same name wins. A fragment may not include another one, which is why the shared Style section is two files with the host `voice` fragment between them — the cores name all three in order.
- Never commit a generated `SKILL.md`. If one shows as modified, you ran `./setup` in a working clone — `bin/pln-generate --clean` puts the placeholders back.
- Preview a build without touching the tree: `bin/pln-generate --host codex --out-dir /tmp/out`.
- Anything host-specific you add must exist for both hosts. Text that is true on only one belongs in a `pln:only` block, not in the core.

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

Run every script in `tests/` before opening a PR — each needs only bash and git, no network, no agent CLI installed, no credentials, and none of them writes to the working tree or reads the developer's own `~/.pln`. All five must print `OK`:

- `bash tests/generate.sh` — `bin/pln-generate`: the three directives, the generated-by banner, `--list`, `--clean`, every error path, and the two properties the host seam rests on — each host's build carries its own mechanics and none of the other's, and a `pln:include` resolves against `src/shared/` for a host that has no fragment of that name while a host fragment of the same name still wins (a missing name fails loudly, naming both folders). Checked against the real `src/` — where both skills must carry the whole Style section, the peer ladder behind its consent key, and the plan review's rules, the rung-3 spawn being the one part that differs by host — as well as fixtures.
- `bash tests/config.sh` — `bin/pln-config`: a value survives the round trip as written, spaces and flags and all, so a key can hold a whole invocation; the booleans still read identically; one key is never another key's prefix.
- `bash tests/codex-agent.sh` — `bin/pln-codex-agent` against a fake `codex` on `PATH`: an empty result is a failure, the thread id comes out of the event stream, the brief travels on stdin, and `resume` is never handed the flags it rejects.
- `bash tests/claude-agent.sh` — `bin/pln-claude-agent` against a fake `claude` on `PATH`: a non-zero exit is a failure even when prose was printed, the peer is restricted with `--tools` and never with `--allowedTools`, and `ANTHROPIC_API_KEY` is left alone.
- `bash tests/peer.sh` — `bin/pln-peer` against fake `claude`/`codex` CLIs and a scratch `PLN_STATE_DIR`: the three rungs in order, the skip-the-host rule in both directions, the one-time consent gate (nothing is sent in any state until it is granted, `--which` and `--dry-run` included), and a peer that is absent, unauthenticated, empty, failed or malformed falling back rather than passing for a review.

A test that drives a `bin/` helper does it through a fake CLI on `PATH` — never a real `claude` or `codex`, which most users of this repo will not have.

Then install the skill locally, restart the agent, and exercise the changed behavior manually. For `/pln`: run a multi-item task end-to-end, through the Step 8 hand-off, and confirm it reaches `/pln-pr` instead of pushing and running `gh pr create` inline.

A change under `src/` is not exercised until it is built. Preview both hosts with `bin/pln-generate --host claude --out-dir /tmp/pln-claude` and `--host codex --out-dir /tmp/pln-codex` and read the host you changed; `./setup` builds in place for the host you are installed under.
