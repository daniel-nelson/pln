## Start-of-invocation readiness sweep

Run this sweep on every invocation, new or continuing, before any repository research, phase action, or long-running dispatch. Its purpose is to settle predictable global questions while the user is still present, never after they have reasonably left the run unattended.

From the resolved pln installation root, run `bin/pln-peer --which --host {{HOST_CLI}} --material approved`. This is a local selection/authentication probe and sends no task material. Read its eight-line result and exit status:

- `STATUS=consent` / exit 5: fire the enabled notification channels, then ask the one-time cross-provider consent question as this turn's only question. Name the selected peer, explain that permitted task material will be sent to that external provider and may use its quota, and say the answer applies across repositories. Persist `peer_consent true|false`; stop the turn. The next invocation reruns this sweep.
- `STATUS=egress` / exit 6: fire the enabled notification channels, then ask the standing egress-policy question as this turn's only question. Explain that `consent` automatically sends material not marked sensitive/local-only without asking again, while `approved-only` sends only material explicitly approved for peer egress and otherwise stays local without prompting. Persist the exact answer with `pln-config set peer_egress consent|approved-only`; stop the turn.
- `STATUS=ready|none|declined|suppressed`, a missing helper, or an unavailable peer: the sweep is settled and does not block the run.

Ask at most one readiness question per invocation. Never raise either configuration question later in the run: if a later peer call unexpectedly returns `consent` or `egress` because the environment changed after this sweep, treat the peer as unavailable for this run, use the prescribed same-host substitute, and leave the question for the next invocation's sweep. There is no current-model readiness question; judgment workers inherit without confirmation.
