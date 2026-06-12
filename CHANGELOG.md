# Changelog

## 1.2.0 — 2026-06-12

### Changed

- **Interview questions must be self-contained.** Step 3 now requires each question to be answerable from the question text alone, without scrolling back to the overview or to intermediate tool output. The question leads with one or two lines restating the problem the decision resolves and the evidence the options hinge on, and never refers to earlier findings by transient label ("case C", "the repro above") without inlining what they were. This is a framing change, not a length one: the options and recommendation stay as they are. Added a matching entry to the failure-modes list.

## 1.1.0 — 2026-06-10

### Changed

- **Interview asks only what only the user can answer.** Every open choice now routes through a filter with two checkable tests — *authority* (can you cite a concrete source that already decides this, by name?) and *reversibility of consequence* (can you name what would have to depend on it before it could change?). Unbacked-and-consequential choices become one-at-a-time interview questions; cite-backed or reversible choices are decided and disclosed; not-yet-knowable choices are deferred to implementation. This narrows the interview to the user-owned decisions and stops the indifferent-bare-letter answers that signalled a wasted question.
- **Disclosed-decisions list at the master-plan gate.** Decide-and-disclose calls are presented at Step 4 as a globally-numbered, item-grouped, **self-triaged** list — the few low-confidence calls flagged for review, the rest scannable. The user reopens any by number ("3, 7, 8") to drop back into the one-at-a-time interview, starting from the recorded position and its rationale; unlisted decisions stand as accepted.
- **One filter, two surfaces.** The same tests govern what the plan *prescribes*. `PLAN.md` records intent, constraints, acceptance criteria, and load-bearing/irreversible decisions at full fidelity, but no longer prescribes reversible implementation mechanics (sequencing, internal structure, exact commands) — those are left to the implementer. Decisions are recorded as overridable-when-reversible context, not imperative steps; guardrail boilerplate ("remember to test") becomes a stated qualitative bar. Plans read as goals, not step lists — better for capable implementers (Opus or Fable) without branching on the active model.
- **Plain conversational voice.** A new Style rule strips Claude's default "intense, over-confident tech bro" register from the skill's prose: minimal bold, no em-dash drama, no certainty-theater words ("load-bearing", "the crux", "exactly right"), claims stated once instead of as "not just X, it's Y", no agreement-amplifier openers, no restating the user's point back, no pre-labeling a point as significant ("it's a real fork") or announcing a question before asking it, no self-congratulatory adverbs ("cleanly", "elegantly"), no jargon or strained metaphors where a plain word works ("load-bearing", "moves the needle", "the rule that would bite"). Also leads with the answer instead of burying it under narrated reasoning, and matches response length to the question. Governs conversational prose only; the functional formatting (option labels, `[recommended]` marker, status icons, numbered sequences) is exempt. `/plnify` now installs a matching **Plain voice** section (its third) so gstack planning skills get the same register.

## 1.0.0 — 2026-05-18

### Added

- **`/pln`** — two-phase personal planning workflow. Interview phase resolves all per-item questions into a master plan; implementation phase executes one item at a time. No interleaving, ever.
- **`/plnify gstack`** — one-time installer that appends pln's interaction discipline (one-question-at-a-time rules + exploratory-mode posture) to `~/.claude/CLAUDE.md` for gstack planning skills. Shows a full preview and requires explicit approval before writing.
- **`./setup`** — symlinks the `plnify` sub-skill into the parent `skills/` directory on install.
