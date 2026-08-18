# Shared behavior-preservation contract

This is the single policy owner for behavior preservation in simplification synthesis, item implementation, and structural PR repair. Each caller keeps its existing planning, review, implementation, blocker, and assurance lifecycle; it references this contract rather than creating a second policy or phase.

Apply this contract to every proposed removal, replacement, or consolidation, including a candidate described as private, unreachable, mechanical, or structurally obvious. Reachability evidence and behavior evidence answer different questions. Private reachability, an absence of references, a closed static consumer list, compilation, or post-change tests alone can support discovery, but none proves that behavior was preserved.

Before changing product files:

1. Name the affected behavioral boundary, its direct and indirect consumers, and its externally observable behavior or state effects. Repository-native discovery must cover relevant exports, routes, registries, generators, configuration, persisted data, and convention or plugin loading where they can create consumers; text search may supplement that discovery but cannot replace it.
2. Against the recorded pre-change source, run the narrowest repository-native characterization that exercises that boundary through its material consumers. Record the source identity, exact commands or scenarios, exit status, and the relevant outputs, effects, or state transitions. A new characterization is valid only when it captures behavior that exists before the edit; a post-only regression test is not a baseline.
3. After the change, rerun the same characterization under equivalent inputs and environment, then compare the post-change result with the recorded pre-change result. Supplement it where needed to exercise a changed integration route, but never replace the common before/after boundary with a different passing test.

Public, compatibility, persisted/stateful, or uncertain behavior requires affirmative repository evidence for the affected contract and state transitions. If indirect consumers, dynamic discovery, historical compatibility, or state effects cannot be bounded and characterized, retain the surface or stop at the existing blocker/decision boundary. Do not infer safety from private visibility or an empty reference search.

Evidence is sufficient only when another worker can rerun the discovery and the pre/post characterization and see which behavior was retained. Record that evidence in the candidate, repair, and qualitative surface balance as applicable. If no candidate has complete proof, `no change` or `nothing worth changing` is the correct successful outcome; never manufacture churn to produce a simplification.

WORKER_ONLY_SENTINEL_BEHAVIOR_PRESERVATION_V1
