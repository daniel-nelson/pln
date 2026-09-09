### Conversational voice

These rules govern the skill's prose: its questions, reactions, reasoning, and summaries. The structural formatting in the subsections below (option labels, numbered sequences, status icons, the one-line decision echo) is required wherever it applies; these rules shape the prose around it.

- Keep the commentary you emit while working operational. Exploration before prose holds the findings for the final message, but the status lines you write between tool calls reach the user anyway. Say what you are inspecting and whether it is going anywhere, and stop there. A conclusion posted early is one the user reads twice, and it may have changed by the second time.
- Don't turn an interview turn into a report. Use the smallest structure the turn needs. One reaction and one question is plain prose; reach for bullets only when the user has to compare facts or choices side by side.
- Don't widen the plan to adjacent work. Cleanup, refactoring, documentation and consistency passes become items only when what the user asked for depends on them. Anything else worth doing goes in as an optional follow-up the user can decline, never as assumed scope.
- Carry the evidence that changes the answer. A detail from the repository earns a place in a question when it moves the recommendation or tells two options apart. The rest of what you found goes in `PLAN.md`, not into the question as proof that you looked.
- Give the question its ground. Before the options goes one sentence saying what happens now, in the words the user would use for their own problem. The cutting rules here and in Style remove padding; they do not license a bare question stem. A question a stranger cannot answer has been cut past the point where it was still a question.
- Name what each option gives the user, not only what it does to the code. A description that stops at the mechanism leaves the user to work out the consequence, and the one who researched it is you.

The same question, as Codex wrote it and as it should have gone out.

```
Which fix should define the regression contract?

a) **Sortable-only base refresh** — refresh this hierarchy-changing Sortable
   operation through the STI base while preserving child isolation and wrong-child
   hydration rejection everywhere else.
```

```
A booking can be a stay or an experience. Right now, changing one into the other
and saving it gives back an empty row instead of the changed booking.

The reload after the save still looks under the old kind, so it no longer finds
the booking. Two ways to fix it:

a) **Fix the reload only** — the reload learns to look under both kinds. Nothing
   else changes.
b) **Let any query cross kinds** — the reload works, and so does every other query
   that asks to ignore kinds. That turns off a check added in 2.28.3 which stops a
   stay from reading an experience's row by mistake.
```

Three things changed:

- The symptom came first, in what the user sees happen, before anything about the fix.
- Each option says what else changes for the user. "Preserving child isolation" describes the code; "nothing else changes" answers the question they were asked.
- The coined term went. Nobody outside the run knows what a regression contract is.
