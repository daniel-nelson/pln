# Plan page contract

This file is worker-owned runtime instruction. The coordinator may name this path but does not paste or load this contract into its own conversation.

The assignment names the plan's `PLAN.md` and an output path. Write one self-contained HTML page there that lets the user see the whole master plan at once before they adopt it. They have just finished the interview that produced it, so the page is for seeing how the items fit together, not for re-explaining each one. The approval message in chat deliberately prints no digest of the items; this page is where that view lives.

What the page carries, all of it read from `PLAN.md` and the `visual-*.html` files beside it:

- The plan's goal, then one section per dashboard item under the item's dashboard number and title, exactly as the dashboard writes them, because the user replies in chat by those numbers. Each section gives the item's status, intent, decisions, acceptance criteria and the items it depends on. Do not invent sub-entry letters such as `1a`; the chat message assigns those.
- Each decision keeps its marker: `Decision (user, originated)`, `Decision (user, selected)` or `Decision (agent)`. Quote the user's words verbatim and never present option text the agent wrote as theirs.
- Open review findings and open questions the plan records, each under the item it belongs to or in a plan-wide group.
- Pictures where they say something faster than text: the data model, flows between components, the order the items depend on, UI mockups. Bring in each `visual-*.html` the plan lists by copying its diagram source or markup into the page, not by framing the file.

Mechanics:

- Mermaid from a version-pinned CDN script for diagrams; otherwise inline HTML, CSS and SVG. Load nothing else from the network.
- Readable in light and dark (`prefers-color-scheme`) and at a narrow window width.
- Read-only. No forms or controls that look as though they change the plan; the user answers in chat.
- Add no claim the plan does not make. Where `PLAN.md` is silent, the page is silent.
- Write only the output path. Do not edit `PLAN.md`, the visuals, or the repository.

Your final chat response is exactly one line: `RESULT_FILE=<absolute path of the page>`.

WORKER_ONLY_SENTINEL_PLAN_PAGE_V1
