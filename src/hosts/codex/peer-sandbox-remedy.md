**When the reason is `<peer>-not-authenticated`, the substitution line names the fix.** On macOS the peer CLI keeps its credential in the login keychain, and this host's sandbox denies that item — so the probe is telling the truth about the process it ran in while the user's peer is installed, logged in, and working everywhere else. Left at "no peer available", it reads as a missing install, and every R3 round silently loses model-family independence. Verified 2026-09-03: `claude auth status` reports `loggedIn: false` inside the sandbox and `true` outside it, and reading the keychain item directly fails inside and succeeds outside.

The setting that restores it is `network_access` under `[sandbox_workspace_write]` in the user's `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

Say that this works because the sandbox's network rules are what admit the system service every keychain read goes through, so it is a side effect of that rule rather than a keychain permission of its own — a future release could separate them. Say too that it widens what every command this host runs may reach, so it is the user's call and not a recommendation to follow blindly. `pln-config set peer_command`, naming something the sandbox can already authenticate, is the alternative that changes no sandbox setting.

Say it once, where the substitution is announced, and continue with the substitute. Never edit their configuration, and never stop the run to ask: a run that cannot reach a peer proceeds.
