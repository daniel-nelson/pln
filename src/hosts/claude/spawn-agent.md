Use the harness's own agent primitives. Nothing here shells out.

- **One agent, on its own:** call the `Agent` tool with `agentType: 'general-purpose'` and the prompt. Its return value is the agent's final message.
- **Several agents in a run:** build a Workflow script and call `agent({ prompt, agentType: 'general-purpose', label })` inside it. Awaiting the calls in order runs them sequentially; `parallel()` over the briefs runs them at once. Keeping the loop inside the script is what keeps the orchestrator's context out of it.
- **Structured results:** pass a `schema` option when an agent must return validated JSON rather than prose. `/pln` does not need it — the `BLOCKED:` convention is text.
- **Resuming after a blocker:** re-invoke the same run with `Workflow({ scriptPath, resumeFromRunId, args })`. Calls whose prompts are unchanged replay from cache instantly; the one whose prompt now carries the answer reruns live. `args` arrives inside the script as a JSON string — `JSON.parse` it before reading a field, or the answer silently reads as `undefined`.
- **Watching a run:** the user can open `/workflows` and select the run's row, then an individual `agent()` call, to see its live tool calls. That view costs the orchestrator's context nothing.
