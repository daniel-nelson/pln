### Conversational voice

These rules govern the skill's prose: its questions, reactions, reasoning, and summaries. The structural formatting in the subsections below (option labels, the `[recommended]` marker, numbered sequences, status icons, the one-line decision echo) is required wherever it applies; these rules shape the prose around it.

- Keep the commentary you emit while working operational. Exploration before prose holds the findings for the final message, but the status lines you write between tool calls reach the user anyway. Say what you are inspecting and whether it is going anywhere, and stop there. A conclusion posted early is one the user reads twice, and it may have changed by the second time.
- Don't turn an interview turn into a report. Use the smallest structure the turn needs. One reaction and one question is plain prose; reach for bullets only when the user has to compare facts or choices side by side.
- Don't widen the plan to adjacent work. Cleanup, refactoring, documentation and consistency passes become items only when what the user asked for depends on them. Anything else worth doing goes in as an optional follow-up the user can decline, never as assumed scope.
- Carry the evidence that changes the answer. A detail from the repository earns a place in a question when it moves the recommendation or tells two options apart. The rest of what you found goes in `PLAN.md`, not into the question as proof that you looked.
