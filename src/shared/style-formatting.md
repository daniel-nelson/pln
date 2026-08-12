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

Exactly one space after `a)`, `b)`, `c)`. Never break alignment by varying the post-paren whitespace.

### A recommendation is not a question

**Never mark an option as recommended, and never argue for one after the list.** Having a recommendation you can defend is the test that the choice was yours to make: it means you can cite an authority or name what would have to change, which is exactly the decide-and-disclose lane. Make the call, record it in one line, and let the gate carry it as overridable.

An option list is for a genuine fork — one where you cannot say which side you'd take. If you can, you are not asking a question; you are asking the user to ratify an answer, and the reading it costs them buys nothing.

Traced from six days of sessions: across three of them the user replied with a bare selector twenty-one times, and every one picked the option already marked recommended. The marker never changed an outcome and the losing branches were never read. Where the agent was pushed to restate such a question plainly, it twice concluded the question was its own to answer — "that wasn't a fair question to put to you, and it's mine to decide."

The tells that a question is really a disclosure, any one of which is enough:

- You wrote a sentence beginning "I'd take", "I lean", "I recommend", or "what tips me to".
- The paragraph after the options argues for one of them.
- One option exists only so the list has three.
- Your own prose already contains the deciding fact — "it's strictly less work", "it's what the item's intent already says", "this is work the change requires, not a choice".

### Binary "adopt as written / change?" questions

Plain prose, no letters. e.g., "Adopt this as written, or change it?"

### Bullets vs. numbers — visual distinction

- **Hyphen bullets** = "here's a flat list" (definitions, criteria, conditions). Not for choices.
- **`1.` numbered** = "here's a sequence I propose" (ordered process).
- **`a) **Bold** —`** = "pick one of these" (options).

The visual distinction must be obvious at a glance. Don't mix styles within a single list.

### Echoing recorded decisions

Before asking the next question, echo back what was just recorded in **one short line**. Lets the user catch a misrecorded answer immediately. The line carries the answer and nothing else: not why it was chosen, not what it changes, not a lead-in to the next question.

**Never as a message of its own.** The echo rides on the front of the next question and nowhere else. A turn whose whole content is "Recorded: entry 21 adopted." spends a round trip telling the user what they just typed; in one reviewed session twenty-eight of them went out, several under thirty characters. When there is no next question — the item is finished, the walk is over — the echo is dropped, not sent alone.

Examples:

- *"Recorded: mix-conditional question style, and never AskUserQuestion."*
- *"Recorded: lightweight checks per item, full gauntlet at the end."*
