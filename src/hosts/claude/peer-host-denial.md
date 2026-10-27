**When Claude Code's auto-mode classifier denies the `pln-peer` call.** The tool result names the auto mode classifier and a reason such as `[Data Exfiltration]`. The helper never ran, so there is no `STATUS=` line. This is the host's safety check. It is not a pln policy and not a ruling on the user's consent: the classifier cannot see `~/.pln/config.yaml`, and it can deny a send it allowed earlier in the same session. Observed: a run sent material to Codex twice in one session, then had the third send denied, and the retry after the user wrote "Send to Codex" was denied too. Do not retry, reshape the command, or guess what tipped it. The remedy is a permission rule, which Claude Code checks before the classifier. Give the user this line for `permissions.allow` in `~/.claude/settings.json`, with the absolute path you ran:

```
"Bash(<absolute path>/pln-peer *)"
```

Do not edit the settings file yourself; the classifier refuses that too, as self-modification. Do not offer a `!` command as the fix either: it runs only at the terminal, and the user answering may be on a phone. Then continue as for any no-send. Plan review continues with the broad reader, PR review fills the slot with the same-model substitute, and the notice at the next stop names the denial and gives this rule.

**Run it so that rule matches.** A Bash allow rule matches each subcommand's literal text. So run `pln-peer` by its absolute path as the whole command: no `$PLN_BIN` or other variable in front of it, no `;`, `&&` or `|` chain, and no shell redirect. `--out` and `--log` already write the files.
