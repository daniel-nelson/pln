**Set up a scratch directory** before Step 1, and use it for every brief, result and transcript this run produces. It lives outside the repository so nothing it holds can be swept into a commit:

```bash
mkdir -p "${TMPDIR:-/tmp}/pln-pr-<branch-slug>" && echo "${TMPDIR:-/tmp}/pln-pr-<branch-slug>"
```

That printed path is written `$RUN` below. Substitute the real path each time — every shell call starts a fresh shell, so a variable set in one call is gone by the next.

**Two things about this host shape everything below.** A spawned agent inherits this session's sandbox and network limits. So the agent does the reading, writing, and thinking allowed inside that sandbox, while the orchestrator owns every `git commit`, `git push`, and `gh`/`glab` call. Native agents are not separate login processes and may run concurrently when the flow proves their work independent. The OAuth token race applies only to fallback CLI processes, which stay serial.
