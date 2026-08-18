---
name: pln-simplify-phase-map-synthesize
---

# /pln-simplify phase: map and synthesize

<!-- pln:include active-turn-lifecycle -->

Read this file before repository mapping, then load `{{OUTPUT_ROOT}}/phases/pln/outline.md` for root-instruction discovery, plan-directory placement, `.git/info/exclude`, pre-flight evidence routing, and its mandatory initial outline checkpoint. The specialization below changes only the evidence that shapes that outline; it does not create another planning or approval lifecycle.

Dispatch fresh `judgment` workers on `{{OUTPUT_ROOT}}/src/workers/simplification-map.md` across the smallest independent set of responsibility areas that covers the requested scope. Use one worker when the scope has one owner; use disjoint workers concurrently only when their reads are independent. Each gets one bounded area, the source commit and root mandates, distinct evidence/result paths, routing attribution, and a 4096-byte envelope. Validate every result with `pln-read-envelope`; failed coverage stays uncertainty.

Then dispatch one fresh `judgment` worker on `{{OUTPUT_ROOT}}/src/workers/simplification-synthesis.md` with the complete map artifact paths and protected decisions. It alone compares overlapping owners and produces the bounded candidates. The coordinator reads only its validated envelope.

Write the ordinary `PLAN.md` skeleton from the synthesis: one item per coherent candidate, with ownership, dependency, preservation, and verification boundaries. `nothing worth changing` becomes one assessment outcome, not an invented edit. Show the skeleton and stop at `/pln`'s mandatory initial outline checkpoint. If the user continues, set `Phase: interview` and use the existing `/pln` interview and review-approval phases; they own one-question-at-a-time resolution, plan review, and master-plan adoption. Never implement before adoption.
