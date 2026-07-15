# pln development workflow

## Audience — this is open source

`/pln` is an open-source skill installed by many people across different setups (Claude Code and Codex, macOS and Linux, solo and team repos). It is not tuned for the maintainer's machine. Design every feature for the general user.

- **No feature may depend on the maintainer's personal accounts, services, hardware, or environment.** No hardcoded keys, personal push channels, private endpoints, or "works because I happen to have X." If a capability isn't present on a fresh install, the skill must still work without it.
- **Prefer capabilities every user already has:** the agent harness's own tools and standard OS commands. Reach for a third-party service only when it's optional and the user configures it themselves.
- **Environment-specific behavior is opt-in and degrades gracefully.** Gate it behind a config key (the existing `notify` / `auto_upgrade` pattern), default to the universal behavior, and no-op cleanly when the dependency is absent — never error or block on something a general user doesn't have.

## Releases

Every PR that changes skill behavior must include both:

- A version bump in `VERSION`
- A matching entry in `CHANGELOG.md`

**Minor bump** (1.0.0 → 1.1.0): new guidance, reworked explanations, new sections, behavioral changes to `/pln` or `/plnify`.  
**Patch bump** (1.0.0 → 1.0.1): typo fixes, factual corrections, wording-only edits that don't change behavior.

One open PR = one version. If scope grows mid-PR, bump the single version heading rather than creating a new entry. Merging to `main` is the publish event — do not create CHANGELOG entries for branches that never merge.

## Testing

Install the skill locally, restart Claude Code, and exercise the changed behavior manually before opening a PR. For `/pln`: run a multi-item task end-to-end. For `/plnify`: test against a CLAUDE.md that already has the sections (should bail) and one that doesn't (should write correctly).
