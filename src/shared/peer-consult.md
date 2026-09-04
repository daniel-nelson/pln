One helper selects and runs a cross-provider peer. Use it for R3's adversarial slot, an explicitly assurance-first posture, or an explicit user request. It is additive model-family independence, not a universal dependency and never an economy route. Below, `$PLN_BIN` is the installed `bin/` directory.

```bash
"$PLN_BIN/pln-peer" \
  --brief "<standalone-brief>" --out "<raw-result>" \
  --material approved --timeout 1800
```

`--material` is mandatory as a judgment before a real send even though the helper safely defaults to `unknown`: use `approved` only when repository/session instructions and inspected content permit cross-provider egress; use `unknown` when approval is unclear. `sensitive` and `local-only` are explicit suppression states. A session or repository instruction that calls material sensitive, confidential, private, or local-only always suppresses sending, regardless of machine-wide settings. Never weaken that instruction by relabeling the material.

The peer brief is file-first and self-contained. A peer may be prompt-in/text-out without repository access, so include the reviewed plan/diff portion, source fingerprint, paths, schema, and question. If the material is too large, include the decision-bearing portion and name the rest; never substitute a bare path. The peer's result and log remain raw artifacts read only by the assigned judgment merge worker.

Run the helper as a tracked foreground or host-native resumable command. If it overlaps an independent same-model roster, retain both native handles and join both before advancing. Never detach `pln-peer` with an untracked shell `&`/`disown`, and never send a final response while the peer subprocess or its paired roster remains active.

The helper reports eight fixed metadata lines: rung, peer, status, result/log paths, and actual judgment profile/model/effort. Rung 1 is the configured `peer_command`; rung 2 is an authenticated supported CLI other than the host; rung 3 sends nothing. Read no result unless exit 0 and `STATUS=ok`.

## Two separate one-time decisions

`peer_consent` is remembered global authorization for cross-provider use. `peer_egress` is a separate remembered standing policy, treating supported providers equivalently:

- `consent` sends material not marked sensitive/local-only without asking again.
- `approved-only` sends only material explicitly approved for peer egress; other material stays local without prompting.

The helper asks neither question itself and sends nothing in either pending state. The always-loaded start-of-invocation readiness sweep owns both questions; if both are unset, the ordering there is mandatory:

1. Exit 5 / `STATUS=consent`: ask the existing cross-provider question in its own turn, naming the selected peer, the material, external quota, and that the answer applies across repositories. Store `peer_consent true|false`.
2. Only after consent is true, exit 6 / `STATUS=egress`: ask in a separate turn whether to send eligible material automatically without asking again (`consent`) or require explicit peer-egress approval (`approved-only`). Explain that both are standing policies, then store the exact answer with `pln-config set peer_egress consent|approved-only`.
3. Re-run the readiness sweep on the next invocation. Never combine the questions, infer the policy from consent, or send between the two answers. An install with `peer_consent: true` and no `peer_egress` starts at step 2.

During plan review or PR review, `STATUS=consent|egress` is never a late prompt. It means readiness changed after the invocation began: use the fresh same-host substitute for this run and leave the question for the next invocation's sweep.

The egress question must say what each answer changes and give the exact later commands. A concise shape is:

```
Cross-provider use is allowed, but pln has not recorded the standing egress policy.

Send eligible material automatically, or require explicit peer-egress approval?

`consent` sends material not marked sensitive/local-only without asking again. `approved-only` sends only material explicitly approved for peer egress; other material stays local without prompting. Either standing policy is remembered in `~/.pln/config.yaml`; `pln-config set peer_egress consent` or `approved-only` changes it later.
```

Other outcomes:

- Exit 3 / `STATUS=none`: no usable peer exists.
- Exit 3 / `STATUS=declined`: cross-provider consent was denied.
- Exit 3 / `STATUS=suppressed`: the material was sensitive/local-only, or `approved-only` rejected material without explicit approval.
- Exit 4 / `STATUS=empty|timeout|error`: the selected peer failed; empty is failure, never a clean review.
- Exit 0 / `STATUS=ready`: `--which` selected a permitted peer without sending.

When R3 requires the adversarial slot and any no-send/failure state occurs, dispatch one fresh same-model adversarial judgment reviewer into that same slot. Do not add it as a fifth reader. **Dispatch it with the rest of the roster, not after them.** The slot is the fourth reader either way, and whichever fills it runs beside the other three — a peer's shell call before the wait loop, a substitute's spawn among the other spawns. Observed otherwise: a run whose peer was unavailable spawned its three same-model readers at 5463s, 5467s and 5472s, awaited them at 5474s, and only then spawned the adversarial substitute at 5725s, adding that reader's whole runtime to the round instead of overlapping it. The instruction that ordered this named the peer call alone, so the substitute — the case that occurs whenever there is no peer, which is every run on a host whose sandbox hides one — inherited no ordering at all. Attribute the result truthfully: name the peer when it ran; otherwise name the reason and say that a fresh same-model substitute ran without model-family independence. For lower tiers, no-send simply means no additive peer unless the user explicitly requested one; never invent coverage.

**A substitution in the adversarial slot is said out loud, in the turn it happens.** Written into the plan's review record and nowhere else, it is a fact the user learns weeks later, if ever: a real run substituted on every one of its deepest-setting rounds because `STATUS=none` meant the peer CLI was installed somewhere the host's environment could not see, and nothing said so until the transcript was read for another reason. So when the slot substitutes, say it in one line where the review is reported — that the adversarial reader was the same model, and the reason `pln-peer` gave. `none` in particular is worth naming as a setup gap rather than a verdict: the peer may be installed and simply unreachable from this host, and `pln-config set peer_command` is the answer. The helper's `REASON=` line says which gap it is, and the two want opposite things from the user. `no-peer-cli-found` means no second CLI is installed or on any path the helper knows. `<peer>-not-authenticated:<path>` means one *is* installed and answered its own probe with a refusal — and the usual cause is not a logged-out user but a sandbox that denies the credential store the CLI keeps its login in, so the probe is telling the truth about this process rather than about the machine. Relay the reason rather than the bare status; "pln could not find a peer" is wrong and unactionable when a peer is installed, logged in, and merely walled off. Where the reason is `not-authenticated` and the user says the peer is logged in, both are true: the remedy is theirs and lives in the host's own sandbox settings, or in `pln-config set peer_command` naming something the sandbox can reach. Name the remedy, never take it — running the peer outside the sandbox its host chose is pln escalating its own permissions, and it is not pln's to escalate. One line, no ceremony, and never a question — a run that cannot reach a peer proceeds with the substitute, it does not stop to ask.

**Then say it again at the next place the run actually stops.** Spoken only in the turn it happens, this is a line the user may never see: the run continues, and an unattended one can put hours of output behind it before it next pauses. That is the same disappearance as writing it to the review record and nowhere else, moved from a file nobody reopens to a transcript nobody scrolls back through. So carry it — one clause, not this paragraph — to the first moment the run genuinely stops for the user: the approval gate, a blocker question, an interview question, or the closing message, whichever comes first. Name the reason and the remedy there, because that is very likely where it is read for the first time. Say it once at that stop and drop it; a notice repeated at every later stop is noise, and the run has already been told not to manufacture those.
