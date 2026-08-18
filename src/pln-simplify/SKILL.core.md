---
name: pln-simplify
description: Map a codebase's concepts and ownership, identify bounded consolidation or deletion opportunities, execute an adopted simplification through pln's existing lifecycle, verify the exact candidate, and record a portable cadence marker. Use when the user invokes `/pln-simplify` or asks for a deliberate repository simplification, architecture decluttering, duplicate-owner consolidation, obsolete-path retirement, or a recurring lean-codebase assessment. A valid outcome is `nothing worth changing`.
---

# pln-simplify — map, simplify, verify

Run a bounded simplification assessment without turning deletion volume into a goal. Concept reduction outranks line reduction. Preserve behavior, public and compatibility contracts, persisted state, destructive boundaries, and user decisions.

**Resolve pln's install:** find the first directory below whose `bin/pln-simplify` is executable and reuse that absolute path as `PLN_DIR`:

`$HOME/.claude/skills/pln`, `$HOME/.agents/skills/pln`, `.claude/skills/pln`, `.agents/skills/pln`.

If none exists, stop and ask the user to run this skill's parent `setup`; do not improvise marker or cadence rules. Then read `{{OUTPUT_ROOT}}/SKILL.md` in full. Its readiness sweep, interaction discipline, model routing, context firewall, host-native spawning, active-turn lifecycle, and durable plan rules govern this run.

## Lifecycle ownership

This skill owns only mapping, simplification synthesis, cadence interpretation, and verified-success recording. Reuse the generated `/pln` router and phase documents for plan location, the initial outline checkpoint, one-question-at-a-time interview, plan review, master-plan approval, scheduling, item implementation, blocker recovery, and exact-candidate assurance. Load those documents when the phase reaches them; do not copy or restate their policies.

The coordinator never performs worker judgment inline and never edits implementation itself. `/pln-simplify` never invokes `/pln-pr` automatically and never broadens a bounded candidate into unrelated cleanup.

## Phase router

The ordinary `PLAN.md` dashboard remains the durable coordinator ledger. Its `Phase` is one of `map-synthesize`, `interview`, `review-approval`, `implementation`, `blocker`, `verify-record`, or `complete`.

- `map-synthesize` → `{{OUTPUT_ROOT}}/phases/pln-simplify/map-synthesize.md`
- `interview` → `{{OUTPUT_ROOT}}/phases/pln/interview.md`
- `review-approval` → `{{OUTPUT_ROOT}}/phases/pln/review-approval.md`
- `implementation` → `{{OUTPUT_ROOT}}/phases/pln/implementation.md`
- `blocker` → `{{OUTPUT_ROOT}}/phases/pln/blocker.md`
- `verify-record` → `{{OUTPUT_ROOT}}/phases/pln-simplify/verify-record.md`

Read exactly one mapped phase before its first action. Use the existing phase verbatim except for one adapter seam: when the reused implementation phase would transition to `finish-ship`, write `Phase: verify-record` instead. This prevents a second implementation/blocker/assurance owner while keeping simplification success recording distinct. Unknown or contradictory state fails closed.

On a new run create the ordinary plan skeleton through `map-synthesize`. The initial outline checkpoint and later master-plan adoption are both mandatory. On resume, reconcile the plan, manifest, worktrees, handoffs, and candidate ref before acting; never infer success from a marker on an unpublished or unverified ref.

## Cadence contract

Run `bin/pln-simplify status --repo <root>` only from local reachable commit messages. V1 defaults are frozen:

- unchanged marker content → `fresh`, regardless of elapsed time;
- changed content reaches `due` at 100 visible commits or 90 elapsed days;
- changed content reaches `overdue` at 250 visible commits or 180 elapsed days;
- overdue wins over due; commit and time thresholds use OR;
- missing, stripped, shallow-without-visible-marker, malformed, unsupported, or unverifiable ancestry → `unknown`;
- repository-disabled cadence → `disabled`.

`fresh` and `disabled` are silent. `due` discloses and continues. Advisory `overdue` becomes a concrete follow-up. `unknown` is non-blocking and names why metadata cannot prove age.

The optional repository policy is `.pln-simplify-policy`, exact `key=value` lines, schema 1. Required keys are `schema=1`, `mode=advisory|required|disabled`, `minimum-client=1`, and `protocol=1`; optional threshold keys are `due-commits`, `overdue-commits`, `due-days`, and `overdue-days`. Repository policy overrides defaults; explicit helper arguments are test/CI overrides and win last. Unsupported required schema, minimum client, or protocol fails closed for aware clients. Older clients and direct forge commands cannot enforce it; repository-wide enforcement therefore requires an optional repository-owned CI/branch-protection call to `bin/pln-simplify enforce`.

Required policy blocks only `overdue`, before review. `unknown` remains non-blocking. A user may give a separately named **simplification freshness bypass** with a reason for one run. Store reason and helper-emitted binding only in that run's nonterminal `REVIEW.md`, bound to run identity, repository, resolved base, candidate HEAD, and policy hash/schema. Invalidate it when any binding changes; consume it at terminal completion or deliberate stop. Generic review skips and repository self-hosting exceptions never imply this bypass.
