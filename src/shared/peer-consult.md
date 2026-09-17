One helper selects and runs a cross-provider peer. Use it for R3's adversarial slot, an explicitly assurance-first posture, or an explicit user request. It is additive model-family independence, not a universal dependency and never an economy route. Below, `$PLN_BIN` is the installed `bin/` directory.

```bash
"$PLN_BIN/pln-peer" \
  --brief "<standalone-brief>" --out "<raw-result>" \
  --material approved --timeout 1800
```

`--material` is mandatory as a judgment before a real send even though the helper safely defaults to `unknown`. It is a question about *this material*, not a re-derivation of consent: whether cross-provider use is allowed at all was answered once by `peer_consent` and `peer_egress`, and the helper enforces both. Use `approved` when an instruction in force explicitly approves this material for peer egress. Use `unknown` otherwise — the ordinary answer, which `peer_egress: consent` still sends and `approved-only` still holds back. `sensitive` and `local-only` are the two suppression states, and reaching either requires a repository or session instruction that names this material sensitive, confidential, private, or local-only. Quote that instruction wherever the suppression is reported; where none can be quoted, the material is not suppressed. Never weaken a real instruction by relabeling the material.

**An authorization you do not have is not a prohibition.** Observed: a run whose config carried `peer_consent: true` and `peer_egress: consent`, and whose plan review had already completed three peer reads at `STATUS=ok`, reached the PR review's adversarial slot, never called the helper at all, and closed by telling the user that the cross-model review "could not run because policy prohibited sending private source code externally." The policy it cited was the user's own global instruction granting standing approval for something narrower — sending synthetic eval fixtures to a model API — which it read as the ceiling on every external send rather than as permission for one. Two things follow. A private or proprietary repository is not by itself sensitive material: reviewing the user's own source is what the peer exists for, and it is exactly what the consent question they already answered was about. And an instruction authorizing some other traffic says nothing about this traffic, so its silence is not a refusal. **No run may report the peer as blocked, prohibited, or unavailable without a `STATUS=` line from the helper saying so.** Where the material really does look suppressed, classify it, run the helper anyway, and report what it returns — that way the decision is attributable, and the user can change it with `pln-config` instead of arguing with a reading of an instruction file they cannot see.

The peer brief is file-first and self-contained. A peer may be prompt-in/text-out without repository access, so include the reviewed plan/diff portion, source fingerprint, paths, schema, and question. If the material is too large, include the decision-bearing portion and name the rest; never substitute a bare path. The peer's result and log remain raw artifacts read only by the assigned judgment merge worker.

Run the helper as a tracked foreground or host-native resumable command. If it overlaps an independent same-model roster, retain both native handles and join both before advancing. Never detach `pln-peer` with an untracked shell `&`/`disown`, and never send a final response while the peer subprocess or its paired roster remains active.

The helper reports nine fixed metadata lines: rung, peer, status, `REASON=` for why there is no peer when there is none, result/log paths, and actual judgment profile/model/effort. Rung 1 is the configured `peer_command`; rung 2 is an authenticated supported CLI other than the host; rung 3 sends nothing. Read no result unless exit 0 and `STATUS=ok`.

## Two separate one-time decisions

`peer_consent` is remembered global authorization for cross-provider use. `peer_egress` is a separate remembered standing policy, treating supported providers equivalently:

- `consent` sends material not marked sensitive/local-only without asking again.
- `approved-only` sends only material explicitly approved for peer egress; other material stays local without prompting.

The helper asks neither question itself and sends nothing in either pending state. The always-loaded start-of-invocation readiness sweep owns both questions and their wording; what this section adds is the order. Consent (exit 5 / `STATUS=consent`) is asked first, and egress (exit 6 / `STATUS=egress`) only once consent is true — so an install with `peer_consent: true` and no `peer_egress` starts at the second. Never combine the questions, infer the policy from consent, or send between the two answers.

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

**A substitution in the adversarial slot is said out loud, in the turn it happens.** Written into the plan's review record and nowhere else, it is a fact the user learns weeks later, if ever: a real run substituted on every one of its deepest-setting rounds because `STATUS=none` meant the peer CLI was installed somewhere the host's environment could not see, and nothing said so until the transcript was read for another reason. So when the slot substitutes, say it in one line where the review is reported — that the adversarial reader was the same model, and the reason `pln-peer` gave. `none` in particular is worth naming as a setup gap rather than a verdict: the peer may be installed and simply unreachable from this host, and `pln-config set peer_command` is the answer. The helper's `REASON=` line says which gap it is, and the two want opposite things from the user. `no-peer-cli-found` means no second CLI is installed or on any path the helper knows. `<peer>-not-authenticated:<path>` means one *is* installed and answered its own probe with a refusal. Relay that reason rather than the bare status; "pln could not find a peer" is wrong and unactionable when a peer is installed, logged in, and merely walled off. What the remedy is, and that it is the user's, is set out below under that same reason. Name it, never take it — running the peer outside the sandbox its host chose is pln escalating its own permissions, and it is not pln's to escalate.

**Then say it again at the next place the run actually stops.** Spoken only in the turn it happens, this is a line the user may never see: the run continues, and an unattended one can put hours of output behind it before it next pauses. That is the same disappearance as writing it to the review record and nowhere else, moved from a file nobody reopens to a transcript nobody scrolls back through. So carry it — one clause, not this paragraph — to the first moment the run genuinely stops for the user: the approval gate, a blocker question, an interview question, or the closing message, whichever comes first. Name the reason and the remedy there, because that is very likely where it is read for the first time. Say it once at that stop and drop it; a notice repeated at every later stop is noise, and the run has already been told not to manufacture those.
