## Start-of-invocation readiness sweep

Run on every invocation, new or continuing, before any repository research, phase action, or long-running dispatch. Settle predictable configuration while the user is present.

Identify the run key without reconciling state: canonical absolute active `PLAN.md` for `{{PLN_CMD}}`, `REVIEW.md` for `{{PLN_PR_CMD}}`, or `new-pln:<absolute-working-directory>` / `new-pln-pr:<absolute-working-directory>` before either exists. When `_PLN_DIR` is set, run `"$_PLN_DIR/bin/pln-update-check" --start "$run_key"`, retain the exact `UPDATE_RECEIPT_READY` challenge, then run `"$_PLN_DIR/bin/pln-update-check" --consume "$run_key" "$challenge"`. Do not recover phase state unless consume succeeds. Missing, stale, wrong-run, wrong-challenge or spent receipts require fresh `--start`, never self-certification. Without helpers, record `HELPER_ABSENT`, claim no freshness and continue.

After consume, read the adoption's `Skill version` pin, carried to PR. For a legacy adopted run, reconcile adoption and record its executing version before deciding on an upgrade. In an unfinished pinned run, record ordinary `UPGRADE_AVAILABLE` as deferred through the endpoint; otherwise follow `{{PLN_UPDATE_CMD}}` and relay copy detail. Necessary correctness/security fixes or explicit update requests may reopen it. If installed `VERSION` differs from the pin, recover from that installation or the blocker boundary; never mix releases. Other skills retain their update rules. `JUST_UPGRADED` reports old/new; current is silent. `DISABLED`, `UNAVAILABLE` and deferred upgrades claim no freshness. New runs resume normal updates.

Run `bin/pln-peer --which --host {{HOST_CLI}} --material approved` from the resolved installation. This local selection/authentication probe sends no task material. Read its nine-line result and exit:

- `STATUS=consent` / exit 5: notify, then ask the one-time cross-provider consent question as this turn's only question. Name the peer, permitted material sent to its provider and quota use; the choice applies across repositories. Persist `peer_consent true|false` and stop. The next invocation reruns this sweep.
- `STATUS=egress` / exit 6: notify, then ask the standing egress-policy question as this turn's only question. `consent` automatically sends material not marked sensitive/local-only; `approved-only` sends only explicitly approved material, otherwise staying local without prompting. Persist `pln-config set peer_egress consent|approved-only` and stop.
- `STATUS=ready|none|declined|suppressed`, absent helper or unavailable peer settles the sweep without blocking.

Ask at most one readiness question per invocation. Never raise either configuration question later in the run: an unexpected later `consent` or `egress` makes the peer unavailable for this run. Use the prescribed same-host substitute and leave configuration to the next invocation's sweep. Judgment workers inherit the hosting model without a readiness question.
