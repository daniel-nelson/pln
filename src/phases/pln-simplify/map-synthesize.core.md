---
name: pln-simplify-phase-map-synthesize
---

# /pln-simplify phase: map and synthesize

<!-- pln:include active-turn-lifecycle -->

Read this file before repository mapping, then load `{{OUTPUT_ROOT}}/phases/pln/outline.md` for root-instruction discovery, plan-directory placement, `.git/info/exclude`, pre-flight evidence routing, and its mandatory initial outline checkpoint. The specialization below changes only the evidence that shapes that outline; it does not create another planning or approval lifecycle.

Dispatch fresh `judgment` workers on `{{OUTPUT_ROOT}}/src/workers/simplification-map.md` across the smallest independent set of responsibility areas that covers the requested scope. Use one worker when the scope has one owner; use disjoint workers concurrently only when their reads are independent. Each gets one bounded area, the source commit and root mandates, distinct evidence/result paths, routing attribution, and a 4096-byte envelope. Validate every result with `pln-read-envelope`; failed coverage stays uncertainty.

Then dispatch one fresh `judgment` worker on `{{OUTPUT_ROOT}}/src/workers/simplification-synthesis.md` with the complete map artifact paths and protected decisions. Require it to read and apply the single shared behavior-preservation owner at `{{OUTPUT_ROOT}}/src/workers/behavior-preservation.md`; every removal, replacement, or consolidation candidate needs the existing behavior-oriented suite or a proven new characterization, exact runnable baseline commands or scenarios and recorded outcomes from the recorded pre-change tree, and any required meaningful broken-behavior failure before it enters the plan. `capture during implementation` is not an admissible placeholder. It alone compares overlapping owners and produces the bounded candidates. The coordinator reads only its validated envelope.

Before writing an item, validate its `Safety disposition` against the shared owner. Treat an omitted or malformed disposition as `retain`. Only an `admit` record with every required conjunct marked `pass` and non-empty rerunnable evidence may become a plan item; if a worker claims `admit` with a missing, failed, unknown, incomparable, or contradicted conjunct, convert it to retained evidence rather than retrying it as an admission. An existing consequential/destructive boundary remains `needs-decision`, never automatic admission, and structural clues cannot overrule the record.

Write the ordinary `PLAN.md` skeleton from the validated synthesis: one item per coherent admitted candidate, with ownership, dependency, the complete disposition, the exact admitted baseline behavior command/scenario and outcome, the equivalent post-change comparison, and the final repository gauntlet. Retained candidates remain assessment evidence but never become implementation items. If no candidate remains admitted, record `nothing worth changing` as the successful no-change assessment rather than inventing an edit. Show the skeleton and stop at `/pln`'s mandatory initial outline checkpoint. If the user continues, set `Phase: interview` and use the existing `/pln` interview and review-approval phases; they own one-question-at-a-time resolution, plan review, and master-plan adoption. Never implement before adoption.
