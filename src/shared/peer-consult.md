One helper selects and runs a cross-provider peer. Use it for R3's adversarial slot, an explicitly assurance-first posture, or an explicit user request. It is additive model-family independence, not a universal dependency and never an economy route. Below, `$PLN_BIN` is the installed `bin/` directory.

```bash
"$PLN_BIN/pln-peer" \
  --brief "<standalone-brief>" --out "<raw-result>" \
  --material approved --timeout 1800
```

`--material` is mandatory as a judgment before a real send even though the helper safely defaults to `unknown`: use `classified` only when repository/session instructions and inspected content permit cross-provider egress; use `unknown` when classification is incomplete. `sensitive` and `local-only` are explicit suppression states. A session or repository instruction that calls material sensitive, confidential, private, or local-only always suppresses sending, regardless of machine-wide settings. Never weaken that instruction by relabeling the material.

The peer brief is file-first and self-contained. A peer may be prompt-in/text-out without repository access, so include the reviewed plan/diff portion, source fingerprint, paths, schema, and question. If the material is too large, include the decision-bearing portion and name the rest; never substitute a bare path. The peer's result and log remain raw artifacts read only by the assigned judgment merge worker.

The helper reports eight fixed metadata lines: rung, peer, status, result/log paths, and actual judgment profile/model/effort. Rung 1 is the configured `peer_command`; rung 2 is an authenticated supported CLI other than the host; rung 3 sends nothing. Read no result unless exit 0 and `STATUS=ok`.

## Two separate first-use decisions

`peer_consent` authorizes cross-provider use at all. `peer_egress` then controls material without explicit peer-egress approval, treating supported providers equivalently:

- `consent` permits material whose approval status is unknown after cross-provider consent.
- `approved-only` permits only material explicitly approved for peer egress; unknown material stays local.

The helper asks neither question itself and sends nothing in either pending state. If both are unset, the ordering is mandatory:

1. Exit 5 / `STATUS=consent`: ask the existing cross-provider question in its own turn, naming the selected peer, the material, external quota, and that the answer applies across repositories. Store `peer_consent true|false`.
2. Only after consent is true, exit 6 / `STATUS=egress`: ask in a separate turn whether to permit material with unknown approval status (`consent`) or require explicit peer-egress approval (`approved-only`). Store the exact answer with `pln-config set peer_egress consent|approved-only`.
3. Re-run the same command. Never combine the questions, infer the policy from consent, or send between the two answers. An upgraded install with `peer_consent: true` and no `peer_egress` starts at step 2.

The egress question must say what each answer changes and give the exact later commands. A concise shape is:

```
Cross-provider use is allowed, but pln has not recorded what material may leave this machine.

Permit material with unknown approval status, or require explicit peer-egress approval?

`consent` lets pln send material unless this session or repository marks it sensitive/local-only. `approved-only` sends only material explicitly approved for peer egress. Either answer is remembered in `~/.pln/config.yaml`; `pln-config set peer_egress consent` or `approved-only` changes it later.
```

Other outcomes:

- Exit 3 / `STATUS=none`: no usable peer exists.
- Exit 3 / `STATUS=declined`: cross-provider consent was denied.
- Exit 3 / `STATUS=suppressed`: the material was sensitive/local-only, or `approved-only` rejected material without explicit approval.
- Exit 4 / `STATUS=empty|timeout|error`: the selected peer failed; empty is failure, never a clean review.
- Exit 0 / `STATUS=ready`: `--which` selected a permitted peer without sending.

When R3 requires the adversarial slot and any no-send/failure state occurs, dispatch one fresh same-model adversarial judgment reviewer into that same slot. Do not add it as a fifth reader. Attribute the result truthfully: name the peer when it ran; otherwise name the reason and say that a fresh same-model substitute ran without model-family independence. For lower tiers, no-send simply means no additive peer unless the user explicitly requested one; never invent coverage.
