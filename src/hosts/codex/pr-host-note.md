**Set up a scratch directory** before Step 1, and use it for every brief, result and transcript this run produces. It lives outside the repository so nothing it holds can be swept into a commit:

```bash
mkdir -p "${TMPDIR:-/tmp}/pln-pr-<branch-slug>" && echo "${TMPDIR:-/tmp}/pln-pr-<branch-slug>"
```

That printed path is written `$RUN` below. Substitute the real path each time — every shell call starts a fresh shell, so a variable set in one call is gone by the next.

**Two things about this host shape everything below.** A spawned agent runs sandboxed: `.git` is read-only to it and it has no network. So the agent does the reading, the writing and the thinking, and the orchestrator — this session — runs every `git commit`, `git push`, and `gh`/`glab` call itself. And spawns are serial, one at a time, because concurrent `codex` processes race on the shared OAuth token file.

