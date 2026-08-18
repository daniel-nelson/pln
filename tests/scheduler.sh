#!/usr/bin/env bash
# tests/scheduler.sh — deterministic execution graphs, durable lifecycle state,
# and dirty-tree protection for /pln and /pln-pr.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEDULER="$REPO_DIR/bin/pln-scheduler"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pln-scheduler-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$3"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3"; return 0; }

[ -x "$SCHEDULER" ] || fail "missing executable scheduler helper: $SCHEDULER"

mkdir -p "$WORK/plan/results" "$WORK/repo"
git -C "$WORK/repo" init -q
git -C "$WORK/repo" config user.email test@example.com
git -C "$WORK/repo" config user.name Test
printf 'base\n' > "$WORK/repo/base.txt"
printf 'owned\n' > "$WORK/repo/user-owned.txt"
git -C "$WORK/repo" add base.txt user-owned.txt
git -C "$WORK/repo" commit -qm base
printf 'user dirty\n' >> "$WORK/repo/user-owned.txt"

"$SCHEDULER" snapshot --repo "$WORK/repo" --out "$WORK/plan/dirty.tsv"
has "$WORK/plan/dirty.tsv" $'PATH\tHASH' 'dirty snapshot has an unknown header'
has "$WORK/plan/dirty.tsv" 'user-owned.txt' 'dirty snapshot omitted a modified tracked file'

cat > "$WORK/plan/nodes.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	src/api	api-chain	fresh	clean
2	1	src/client	api-chain	reuse	clean
3	-	docs/guide	-	fresh	clean
4	-	UNKNOWN	-	fresh	unknown
5	-	src/api/generated	-	fresh	clean
EOF

build_out="$WORK/build.out"
"$SCHEDULER" build \
  --root "$WORK/plan" \
  --nodes "$WORK/plan/nodes.tsv" \
  --manifest "$WORK/plan/run-manifest.tsv" \
  --source-root "$WORK/repo" \
  --source-head "$(git -C "$WORK/repo" rev-parse HEAD)" \
  --dirty-snapshot "$WORK/plan/dirty.tsv" \
  --repo-mode git > "$build_out"
has "$build_out" 'NODE_COUNT=5' 'build did not report every node'
has "$WORK/plan/run-manifest.tsv" $'META\tSOURCE_HEAD\t' 'manifest omitted source HEAD'
has "$WORK/plan/run-manifest.tsv" $'META\tDIRTY_SNAPSHOT\t' 'manifest omitted dirty snapshot'
has "$WORK/plan/run-manifest.tsv" $'1\t-\tsrc/api\tapi-chain\tfresh\tclean\t1\tisolated' \
  'first disjoint node was not assigned to an isolated wave'
has "$WORK/plan/run-manifest.tsv" $'3\t-\tdocs/guide\t-\tfresh\tclean\t1\tisolated' \
  'second disjoint node did not share the isolated wave'
has "$WORK/plan/run-manifest.tsv" $'2\t1\tsrc/client\tapi-chain\treuse\tclean\t2\tisolated' \
  'same-context cohort did not retain its isolated lane'
has "$WORK/plan/run-manifest.tsv" $'4\t1,2,3\tUNKNOWN\t-\tfresh\tunknown\t3\toriginal' \
  'unknown writes were not serialized behind all earlier nodes'
has "$WORK/plan/run-manifest.tsv" $'5\t1,4\tsrc/api/generated\t-\tfresh\tclean\t4\toriginal' \
  'unknown/ancestor relations did not add conservative dependency edges'

if "$SCHEDULER" finish-check --manifest "$WORK/plan/run-manifest.tsv" \
  >"$WORK/finish-check.out" 2>"$WORK/finish-check.err"; then
  fail 'a pending implementation manifest unexpectedly passed the finish gate'
fi
has "$WORK/finish-check.out" 'STATUS=active' \
  'the finish gate did not report a nonterminal manifest as active'
has "$WORK/finish-check.out" $'ACTIVE\t1\tpending' \
  'the finish gate did not identify a pending item'
has "$WORK/finish-check.err" 'implementation remains; keep the coordinator turn alive' \
  'the finish gate did not explain the required coordinator behavior'

ready="$WORK/ready.out"
"$SCHEDULER" ready --manifest "$WORK/plan/run-manifest.tsv" > "$ready"
has "$ready" $'READY\t1\t1\tisolated\tfresh' 'node 1 was not initially ready'
has "$ready" $'READY\t3\t1\tisolated\tfresh' 'node 3 was not initially ready'
hasnt "$ready" $'READY\t2\t' 'dependent cohort node was ready too early'

"$SCHEDULER" claim --manifest "$WORK/plan/run-manifest.tsv" --item 1 \
  --handle agent-1 --worktree "$WORK/wt-1" >/dev/null
"$SCHEDULER" checkpoint --manifest "$WORK/plan/run-manifest.tsv" --item 1 \
  --result results/item-1.txt --commit aaa111 \
  --actual-profile judgment --actual-model frontier --actual-effort high >/dev/null
"$SCHEDULER" ready --manifest "$WORK/plan/run-manifest.tsv" > "$ready"
has "$ready" $'READY\t2\t2\tisolated\treuse' \
  'a checkpointed direct predecessor did not release its cohort continuation'
if "$SCHEDULER" integrate --manifest "$WORK/plan/run-manifest.tsv" --item 3 \
  --commit ccc333 >"$WORK/out" 2>"$WORK/err"; then
  fail 'out-of-order integration unexpectedly succeeded'
fi
has "$WORK/err" 'earlier integration order is not complete' \
  'out-of-order integration failed without a useful cause'
"$SCHEDULER" integrate --manifest "$WORK/plan/run-manifest.tsv" --item 1 \
  --commit aaa111 >/dev/null

"$SCHEDULER" claim --manifest "$WORK/plan/run-manifest.tsv" --item 2 \
  --handle agent-1 --worktree "$WORK/wt-1" >/dev/null
"$SCHEDULER" block --manifest "$WORK/plan/run-manifest.tsv" --item 2 \
  --handoff handoffs/item-2.md >/dev/null
"$SCHEDULER" wait --manifest "$WORK/plan/run-manifest.tsv" --item 5 >/dev/null
has "$WORK/plan/run-manifest.tsv" $'5\t1,4\tsrc/api/generated\t-\tfresh\tclean\t4\toriginal\t' \
  'waiting dependency node disappeared from the manifest'
has "$WORK/plan/run-manifest.tsv" $'\twaiting\t' 'auto-mode dependency wait was not persisted'
recover="$WORK/recover.out"
"$SCHEDULER" recover --manifest "$WORK/plan/run-manifest.tsv" --item 2 > "$recover"
has "$recover" 'RECOVERY=continue-handle' 'blocked node lost its live-handle recovery path'
"$SCHEDULER" set-handle --manifest "$WORK/plan/run-manifest.tsv" --item 2 --handle - >/dev/null
"$SCHEDULER" recover --manifest "$WORK/plan/run-manifest.tsv" --item 2 > "$recover"
has "$recover" 'RECOVERY=fresh-worker' 'blocked node could not recover without a live handle'
has "$recover" "WORKTREE=$WORK/wt-1" 'handle-free recovery omitted its retained worktree'

"$SCHEDULER" check-dirty --repo "$WORK/repo" \
  --snapshot "$WORK/plan/dirty.tsv" --manifest "$WORK/plan/run-manifest.tsv" \
  --allow-items 1 > "$WORK/dirty-check.out"
has "$WORK/dirty-check.out" 'DIRTY_STATE=unchanged' 'unchanged user-owned dirty bytes failed validation'
printf 'worker trespass\n' >> "$WORK/repo/user-owned.txt"
if "$SCHEDULER" check-dirty --repo "$WORK/repo" \
  --snapshot "$WORK/plan/dirty.tsv" --manifest "$WORK/plan/run-manifest.tsv" \
  --allow-items 1 >"$WORK/out" 2>"$WORK/err"; then
  fail 'changed user-owned dirty bytes unexpectedly passed validation'
fi
has "$WORK/err" 'user-owned dirty state changed outside allowed leases' \
  'dirty-byte mismatch failed without the safety cause'

cat > "$WORK/plan/non-git.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	a	-	fresh	clean
2	-	b	-	fresh	clean
EOF
"$SCHEDULER" build --root "$WORK/plan" --nodes "$WORK/plan/non-git.tsv" \
  --manifest "$WORK/plan/non-git-manifest.tsv" --source-root "$WORK/repo" \
  --source-head non-git --dirty-snapshot "$WORK/plan/dirty.tsv" \
  --repo-mode non-git >/dev/null
has "$WORK/plan/non-git-manifest.tsv" $'1\t-\ta\t-\tfresh\tclean\t1\toriginal' \
  'non-git node 1 was not serial in the original tree'
has "$WORK/plan/non-git-manifest.tsv" $'2\t-\tb\t-\tfresh\tclean\t2\toriginal' \
  'non-git node 2 was not serial in the original tree'

cat > "$WORK/plan/dirty-nodes.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	user-owned.txt	-	fresh	overlap
2	-	docs/a	-	fresh	clean
3	-	docs/b	-	fresh	clean
EOF
"$SCHEDULER" build --root "$WORK/plan" --nodes "$WORK/plan/dirty-nodes.tsv" \
  --manifest "$WORK/plan/dirty-manifest.tsv" --source-root "$WORK/repo" \
  --source-head head --dirty-snapshot "$WORK/plan/dirty.tsv" --repo-mode git >/dev/null
has "$WORK/plan/dirty-manifest.tsv" $'1\t-\tuser-owned.txt\t-\tfresh\toverlap\t1\toriginal' \
  'a dirty-overlap node did not stay serial in the source tree'
has "$WORK/plan/dirty-manifest.tsv" $'2\t-\tdocs/a\t-\tfresh\tclean\t2\tisolated' \
  'a dirty-independent node did not enter an isolated wave'
has "$WORK/plan/dirty-manifest.tsv" $'3\t-\tdocs/b\t-\tfresh\tclean\t2\tisolated' \
  'dirty-independent nodes did not share an isolated wave'

cat > "$WORK/plan/too-long.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	a	chain	fresh	clean
2	1	b	chain	reuse	clean
3	2	c	chain	reuse	clean
4	3	d	chain	reuse	clean
EOF
if "$SCHEDULER" build --root "$WORK/plan" --nodes "$WORK/plan/too-long.tsv" \
  --manifest "$WORK/plan/bad.tsv" --source-root "$WORK/repo" \
  --source-head head --dirty-snapshot "$WORK/plan/dirty.tsv" \
  --repo-mode git >"$WORK/out" 2>"$WORK/err"; then
  fail 'four-node cohort unexpectedly passed validation'
fi
has "$WORK/err" 'cohort exceeds the three-node cap' \
  'overlong cohort failed without naming the cap'

"$SCHEDULER" verify --manifest "$WORK/plan/run-manifest.tsv" >/dev/null

cat > "$WORK/plan/terminal-nodes.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	src/terminal	-	fresh	clean
EOF
"$SCHEDULER" build --root "$WORK/plan" --nodes "$WORK/plan/terminal-nodes.tsv" \
  --manifest "$WORK/plan/terminal-manifest.tsv" --source-root "$WORK/repo" \
  --source-head head --dirty-snapshot "$WORK/plan/dirty.tsv" --repo-mode git >/dev/null
"$SCHEDULER" claim --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 \
  --handle terminal-agent --worktree "$WORK/terminal-wt" >/dev/null
if "$SCHEDULER" finish-check --manifest "$WORK/plan/terminal-manifest.tsv" \
  >"$WORK/finish-check.out" 2>"$WORK/finish-check.err"; then
  fail 'a running implementation worker unexpectedly passed the finish gate'
fi
has "$WORK/finish-check.out" $'ACTIVE\t1\trunning' \
  'the finish gate did not identify a running worker'
"$SCHEDULER" checkpoint --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 \
  --result results/terminal.txt --commit abc123 --actual-profile judgment \
  --actual-model frontier --actual-effort high >/dev/null
if "$SCHEDULER" finish-check --manifest "$WORK/plan/terminal-manifest.tsv" \
  >"$WORK/finish-check.out" 2>"$WORK/finish-check.err"; then
  fail 'a checkpointed but unintegrated item unexpectedly passed the finish gate'
fi
has "$WORK/finish-check.out" $'ACTIVE\t1\tcheckpointed' \
  'the finish gate did not identify an unintegrated checkpoint'
"$SCHEDULER" integrate --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 \
  --commit abc123 >/dev/null
"$SCHEDULER" finish-check --manifest "$WORK/plan/terminal-manifest.tsv" \
  >"$WORK/finish-check.out"
has "$WORK/finish-check.out" 'STATUS=complete' \
  'a fully integrated manifest did not pass the finish gate'
has "$WORK/finish-check.out" 'ACTIVE_COUNT=0' \
  'the complete finish gate reported active work'

echo "OK"
