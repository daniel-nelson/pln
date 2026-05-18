# pln development workflow

## Releases

Every PR that changes skill behavior must include both:

- A version bump in `VERSION`
- A matching entry in `CHANGELOG.md`

**Minor bump** (1.0.0 → 1.1.0): new guidance, reworked explanations, new sections, behavioral changes to `/pln` or `/plnify`.  
**Patch bump** (1.0.0 → 1.0.1): typo fixes, factual corrections, wording-only edits that don't change behavior.

One open PR = one version. If scope grows mid-PR, bump the single version heading rather than creating a new entry. Merging to `main` is the publish event — do not create CHANGELOG entries for branches that never merge.

## Testing

Install the skill locally, restart Claude Code, and exercise the changed behavior manually before opening a PR. For `/pln`: run a multi-item task end-to-end. For `/plnify`: test against a CLAUDE.md that already has the sections (should bail) and one that doesn't (should write correctly).
