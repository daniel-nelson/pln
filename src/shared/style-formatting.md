### Inline code

Wrap file names and shell commands in backticks. e.g., `CLAUDE.md`, `package.json`, `pnpm build:spec`, `cargo test`. Never bare.

### Sequences (proposed processes / ordered steps)

Numbered with `1.`, single sentence each, no bold. Use this style whenever you're showing the user a process you intend to follow, not when you want them to choose.

```
The skill discovers verification commands by:

1. Read `CLAUDE.md` / `AGENTS.md` for a completion rule.
2. Inspect `package.json` / `Cargo.toml` / `pyproject.toml` scripts and pick conventional names like `build`, `lint`, `test`.
3. If still ambiguous, ask the user once and save the answer to memory keyed by repo.
```

### Discrete option choices

Lowercase letter + close-paren + single space + bolded label + em-dash + short description. Use this style whenever the user must pick one of N alternatives.

```
When does verification run?

a) **Lightweight per-item, full at end** — type-check / lint after each item, specs only at task completion.
b) **Full only at end** — no per-item checks, single gauntlet at task end.
c) **Full at end, plus on demand** — no per-item checks, single gauntlet at task end, runnable any time on request.
```

Every description answers the same questions in the same order. Above, that is what happens per item and then what happens at the end. Parallel shape, not parallel length: say the shortest true thing about each option and don't pad one to match another.

### Recommended option marker

When one option is the assistant's recommendation, prefix its bolded label with `[recommended] ` (square brackets, single trailing space, **inside** the bold span). Square brackets, not angle brackets: angle brackets get treated as HTML by the host's markdown renderer and disappear, leaving an orphan space and breaking column alignment.

```
a) **[recommended] Full only at end** — no per-item checks, single gauntlet at task end.
b) **Lightweight per-item, full at end** — type-check / lint after each item, specs only at task completion.
```

Exactly one space after `a)`, `b)`, `c)`. The `[recommended] ` prefix lives inside the bold span. Never break alignment by varying the post-paren whitespace.

The recommended option's description says what that option does, like every other option, and gets no extra words for being recommended. Nothing after the list restates which one you picked.

### Binary "adopt as written / change?" questions

Plain prose, no letters. e.g., "Adopt this as written, or change it?"

### Bullets vs. numbers — visual distinction

- **Hyphen bullets** = "here's a flat list" (definitions, criteria, conditions). Not for choices.
- **`1.` numbered** = "here's a sequence I propose" (ordered process).
- **`a) **Bold** —`** = "pick one of these" (options).

The visual distinction must be obvious at a glance. Don't mix styles within a single list.

### Echoing recorded decisions

Before asking the next question, echo back what was just recorded in **one short line**. Lets the user catch a misrecorded answer immediately. The line carries the answer and nothing else: not why it was chosen, not what it changes, not a lead-in to the next question. Examples:

- *"Recorded: mix-conditional question style, and never AskUserQuestion."*
- *"Recorded: lightweight checks per item, full gauntlet at the end."*
