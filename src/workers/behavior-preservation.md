# Shared behavior-preservation contract

This is the single policy owner for behavior preservation in simplification synthesis, item implementation, and structural PR repair. Each caller keeps its existing planning, review, implementation, blocker, and assurance lifecycle; it references this contract rather than creating a second policy or phase.

Apply this contract to every proposed removal, replacement, or consolidation, including a candidate described as private, unreachable, mechanical, or structurally obvious. Reachability evidence and behavior evidence answer different questions. Private reachability, an absence of references, a closed static consumer list, compilation, or post-change tests alone can support discovery, but none proves that behavior was preserved.

Existing behavior-oriented tests are the primary safety net. Prefer the repository's tests that exercise user-visible outcomes, public contracts, state transitions, or effects through material consumers. Tests coupled only to implementation structure, private calls, mocks of the code being changed, snapshots of source shape, or symbol presence may supplement that suite, but implementation-detail tests do not establish the behavioral boundary.

Before a simplifying candidate enters a plan or automatic repair queue:

1. Name the affected behavioral boundary, its direct and indirect consumers, and its externally observable behavior or state effects. Repository-native discovery must cover relevant exports, routes, registries, generators, configuration, persisted data, and convention or plugin loading where they can create consumers; text search may supplement that discovery but cannot replace it.
2. Find the narrowest existing repository-native behavior suite that exercises that boundary through its material consumers. Run it on the recorded pre-change tree and record the recorded pre-change source identity, exact commands or scenarios, environment needed for comparison, exit status, and relevant outputs, effects, or state transitions. A promise to capture this later is not admission evidence.
3. If existing behavior coverage is missing, validate a proposed behavior characterization or test against the unmodified baseline before admission. It must pass on that baseline and show that it fails meaningfully when the protected behavior is deliberately broken in a disposable or safely restored tree or harness. Record both outcomes. A post-change-only regression test, or a test that cannot detect the broken behavior, is not a baseline.

Every candidate carries this concise conjunctive record, with rerunnable evidence after each status:

```text
Safety disposition:
- Disposition: admit | retain | needs-decision
- Baseline suite/outcome: pass | fail | unknown — recorded source identity, exact suite command/scenario, environment, and outcome
- Fault detection: pass | fail | unknown — existing behavior suite evidence, or the new characterization's meaningful broken-behavior failure
- Consumer closure: pass | fail | unknown — direct, indirect, and dynamic discovery and consumers
- Observable/state effects: pass | fail | unknown — external outputs, effects, and state transitions, including evidence that none exist
- Public/compatibility classification: pass | fail | unknown — private, public, or compatibility surface and the supporting evidence
- Comparable pre/post route: pass | fail | unknown — the same boundary, inputs, environment, suite, and planned comparison
- Consequential/destructive uncertainty: pass | fail | unknown — evidence that no consequential or destructive uncertainty remains
```

The default is `retain`. Only `admit` when every required conjunct is `pass` and every evidence field is non-empty and specific enough to rerun; an existing suite can satisfy fault detection only when its evidence shows it exercises the protected behavior. Any missing, malformed, `unknown`, or `fail` conjunct vetoes admission and becomes `retain`, or `needs-decision` at the caller's existing consequential/destructive decision or blocker boundary. Structural clues cannot override this veto: private visibility, reference counts, compilation, similarity, or projected code reduction never turn an incomplete record into `admit`. Public, compatibility, persisted/stateful, consequential, or destructive work also keeps any stricter caller decision boundary even when all behavioral conjuncts pass.

Before changing product files, item implementation and structural PR repair rerun the same admitted behavior suite against the actual current pre-change source and confirm that its identity, inputs, environment, and outcomes remain comparable with the admission record. After the change, rerun that suite under equivalent inputs and environment, then compare the post-change result with the recorded pre-change result. Supplement it where needed to exercise a changed integration route, but never replace the common before/after boundary with a different passing or implementation-detail test. The full repository gauntlet remains the final regression floor after the targeted comparison; it does not replace admission or the common pre/post boundary.

Public, compatibility, persisted/stateful, or uncertain behavior requires affirmative repository evidence for the affected contract and state transitions. Missing, flaky, environment-incomparable, indirect or dynamic, public, compatibility, persisted/stateful, or implementation-coupled evidence retains the surface or stops at the existing blocker/decision boundary unless the shared requirements above are satisfied. If consumers, historical compatibility, or state effects cannot be bounded and characterized, retain the surface or stop. Do not infer safety from private visibility or an empty reference search.

Evidence is sufficient only when another worker can rerun the discovery and the pre/post characterization and see which behavior was retained. Record the complete Safety disposition in the candidate, repair, and qualitative surface balance as applicable. If no candidate has complete proof, `no change` or `nothing worth changing` is the correct successful outcome; never manufacture churn to produce a simplification.

WORKER_ONLY_SENTINEL_BEHAVIOR_PRESERVATION_V1
