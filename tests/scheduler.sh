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
mkdir "$WORK/repo/linked-dir"
printf 'inner\n' > "$WORK/repo/linked-dir/inner.txt"
ln -s linked-dir "$WORK/repo/dir-link"

"$SCHEDULER" snapshot --repo "$WORK/repo" --out "$WORK/plan/dirty.tsv"
has "$WORK/plan/dirty.tsv" $'PATH\tHASH' 'dirty snapshot has an unknown header'
has "$WORK/plan/dirty.tsv" 'user-owned.txt' 'dirty snapshot omitted a modified tracked file'
has "$WORK/plan/dirty.tsv" 'dir-link' 'dirty snapshot failed on an untracked symlink to a directory'

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
# `recover` says what comes next, and says it as the whole invocation: `claim`
# writes --handle and --worktree straight through, so a caller told only to
# claim can re-claim with placeholders and lose the retained worktree.
has "$recover" \
  "NEXT=$SCHEDULER claim --manifest $WORK/plan/run-manifest.tsv --item 2 --handle agent-1 --worktree $WORK/wt-1" \
  'blocked node did not name the whole claim invocation as its next step'
"$SCHEDULER" set-handle --manifest "$WORK/plan/run-manifest.tsv" --item 2 --handle - >/dev/null
"$SCHEDULER" recover --manifest "$WORK/plan/run-manifest.tsv" --item 2 > "$recover"
has "$recover" 'RECOVERY=fresh-worker' 'blocked node could not recover without a live handle'
has "$recover" "WORKTREE=$WORK/wt-1" 'handle-free recovery omitted its retained worktree'
# `-` is a real column value, not a null: a claim carrying it through is the
# placeholder re-claim that destroys the state `recover` exists to report.
has "$recover" 'NEXT=first supply a fresh worker for its handle, then run: ' \
  'handle-free recovery did not name the step that produces the missing handle'
has "$recover" '--handle <new-handle>' \
  'handle-free recovery did not mark the handle as a value the caller must supply'
hasnt "$recover" '--handle -' 'recover proposed a claim that writes a placeholder handle through'
# A pending isolated node: dispatch, and it has no worktree allocated yet,
# so that step is named too rather than passed through as `-`.
"$SCHEDULER" recover --manifest "$WORK/plan/run-manifest.tsv" --item 3 > "$recover"
has "$recover" 'RECOVERY=dispatch' 'a pending node lost its dispatch recovery path'
has "$recover" '--worktree ' 'a pending isolated node named no worktree argument at all'
hasnt "$recover" '--worktree -' 'recover proposed a claim that writes a placeholder worktree through'
# Read-only diagnostic: no status is rewritten by asking what to do next.
has "$WORK/plan/run-manifest.tsv" $'\tblocked\t' 'recover mutated the blocked item it reported on'
has "$WORK/plan/run-manifest.tsv" $'\twaiting\t' 'recover mutated the waiting item it reported on'

"$SCHEDULER" check-dirty --repo "$WORK/repo" \
  --snapshot "$WORK/plan/dirty.tsv" --manifest "$WORK/plan/run-manifest.tsv" \
  --allow-items 1 > "$WORK/dirty-check.out"
has "$WORK/dirty-check.out" 'DIRTY_STATE=unchanged' 'unchanged user-owned dirty bytes failed validation'
mkdir -p "$WORK/repo/src/api"
printf 'leased worker change\n' > "$WORK/repo/src/api/added.txt"
"$SCHEDULER" check-dirty --repo "$WORK/repo" \
  --snapshot "$WORK/plan/dirty.tsv" --manifest "$WORK/plan/run-manifest.tsv" \
  --allow-items 1 > "$WORK/dirty-check.out"
has "$WORK/dirty-check.out" 'DIRTY_STATE=unchanged' \
  'a change inside an allowed lease was compared against the lease sentinel instead of its path'
printf 'outside lease\n' > "$WORK/repo/outside.txt"
if "$SCHEDULER" check-dirty --repo "$WORK/repo" \
  --snapshot "$WORK/plan/dirty.tsv" --manifest "$WORK/plan/run-manifest.tsv" \
  --allow-items 1 >"$WORK/out" 2>"$WORK/err"; then
  fail 'an out-of-lease worker change unexpectedly passed validation'
fi
has "$WORK/err" 'user-owned dirty state changed outside allowed leases' \
  'out-of-lease change failed without the safety cause'
rm -f "$WORK/repo/outside.txt"
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
"$SCHEDULER" recover --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 > "$recover"
has "$recover" \
  "NEXT=$SCHEDULER integrate --manifest $WORK/plan/terminal-manifest.tsv --item 1 --commit abc123" \
  'a checkpointed node did not name its integration by the commit it recorded'
"$SCHEDULER" integrate --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 \
  --commit abc123 >/dev/null
"$SCHEDULER" finish-check --manifest "$WORK/plan/terminal-manifest.tsv" \
  >"$WORK/finish-check.out"
has "$WORK/finish-check.out" 'STATUS=complete' \
  'a fully integrated manifest did not pass the finish gate'
has "$WORK/finish-check.out" 'ACTIVE_COUNT=0' \
  'the complete finish gate reported active work'
"$SCHEDULER" recover --manifest "$WORK/plan/terminal-manifest.tsv" --item 1 > "$recover"
has "$recover" 'NEXT=nothing; this item is integrated' \
  'an integrated node proposed further work'

# ─── `ready` is a dispatch list, so it withholds a held original tree ─────────
# One original worktree holds one worker. `block` and `interrupt` write only the
# status and never release the worktree column, so all four claimed-and-not-yet-
# integrated statuses hold the tree, not `running` alone. The carve-out: a
# `reuse` continuation whose immediate cohort predecessor is `checkpointed` is
# exactly what `ready` exists to release. `claim` keeps its own dependency gate,
# so a withheld node asked for by number is still claimable.
cat > "$WORK/plan/hold-nodes.tsv" <<'EOF'
ITEM	DEPS	LEASES	COHORT	CONTEXT	DIRTY_STATE
1	-	hold/a	hold-chain	fresh	clean
2	1	hold/b	hold-chain	reuse	clean
3	-	hold/c	-	fresh	clean
EOF
hold_manifest="$WORK/plan/hold-manifest.tsv"
hold_ready="$WORK/hold-ready.out"
build_hold() {
  "$SCHEDULER" build --root "$WORK/plan" --nodes "$WORK/plan/hold-nodes.tsv" \
    --manifest "$hold_manifest" --source-root "$WORK/repo" --source-head head \
    --dirty-snapshot "$WORK/plan/dirty.tsv" --repo-mode non-git >/dev/null
}
build_hold
has "$hold_manifest" $'1\t-\thold/a\thold-chain\tfresh\tclean\t1\toriginal' \
  'the holding fixture did not build node 1 into the original tree'
has "$hold_manifest" $'3\t-\thold/c\t-\tfresh\tclean\t3\toriginal' \
  'the holding fixture did not build node 3 into the original tree'
"$SCHEDULER" ready --manifest "$hold_manifest" > "$hold_ready"
has "$hold_ready" $'READY\t1\t' 'an unheld original node was not ready'
has "$hold_ready" $'READY\t3\t' 'a second unheld original node was not ready'

for holding in running blocked interrupted; do
  build_hold
  "$SCHEDULER" claim --manifest "$hold_manifest" --item 1 \
    --handle hold-agent --worktree "$WORK/hold-wt" >/dev/null
  case "$holding" in
    blocked) "$SCHEDULER" block --manifest "$hold_manifest" --item 1 \
      --handoff handoffs/item-1.md >/dev/null ;;
    interrupted) "$SCHEDULER" interrupt --manifest "$hold_manifest" --item 1 >/dev/null ;;
  esac
  "$SCHEDULER" ready --manifest "$hold_manifest" > "$hold_ready"
  hasnt "$hold_ready" $'READY\t3\t' \
    "ready reported a second original node while item 1 was $holding"
  # The withheld node is still dependency-ready, and `claim` must say so by
  # claiming it rather than by refusing with a cause that is not true.
  cp "$hold_manifest" "$WORK/plan/hold-claim.tsv"
  "$SCHEDULER" claim --manifest "$WORK/plan/hold-claim.tsv" --item 3 \
    --handle hold-agent-3 --worktree "$WORK/hold-wt-3" > "$WORK/hold-claim.out" \
    2>"$WORK/hold-claim.err" \
    || fail "claim refused a withheld but dependency-ready node while item 1 was $holding"
  has "$WORK/hold-claim.out" 'STATUS=running' \
    "claim did not run a withheld node while item 1 was $holding"
  if [ "$holding" = interrupted ]; then
    has "$hold_ready" $'READY\t1\t' 'an interrupted node lost its own recovery slot'
  fi
done

build_hold
"$SCHEDULER" claim --manifest "$hold_manifest" --item 1 \
  --handle hold-agent --worktree "$WORK/hold-wt" >/dev/null
"$SCHEDULER" checkpoint --manifest "$hold_manifest" --item 1 \
  --result results/item-1.txt --commit ddd444 --actual-profile judgment \
  --actual-model frontier --actual-effort high >/dev/null
"$SCHEDULER" ready --manifest "$hold_manifest" > "$hold_ready"
has "$hold_ready" $'READY\t2\t' \
  'a checkpointed cohort predecessor did not release its own reuse continuation'
hasnt "$hold_ready" $'READY\t3\t' \
  'ready reported an unrelated original node while a checkpoint still held the tree'

# ─── pln's own follow-up queue is not the user's uncommitted work ─────────────
# A door that files mid-run writes an untracked detail file and rewrites a
# possibly-tracked index. Both trip the guards that protect user-owned bytes, so
# a filing into a committed queue would destroy the run it fired from — and
# /pln-simplify's own Step 1 would create the dirt its marker step then refuses.
# So the guards skip the queue's own paths: the index, `q/` and `done/` beneath
# a root that actually holds a queue, never the root itself.
QUEUE_BIN="$REPO_DIR/bin/pln-queue"
SIMPLIFY="$REPO_DIR/bin/pln-simplify"
[ -x "$QUEUE_BIN" ] || fail "missing executable queue helper: $QUEUE_BIN"
[ -x "$SIMPLIFY" ] || fail "missing executable simplify helper: $SIMPLIFY"
export PLN_QUEUE_DATE=2026-08-27

queue_case() { # queue_case <name>  → prints the repo dir, leaves plan state beside it
  local name="$1" d
  d="$WORK/queue-$name"
  mkdir -p "$d/repo" "$d/plan"
  git -C "$d/repo" init -q
  git -C "$d/repo" config user.email test@example.com
  git -C "$d/repo" config user.name Test
  printf 'base\n' > "$d/repo/base.txt"
  git -C "$d/repo" add base.txt
  git -C "$d/repo" commit -qm base
  printf 'ITEM\tDEPS\tLEASES\tCOHORT\tCONTEXT\tDIRTY_STATE\n1\t-\tsrc/x\t-\tfresh\tclean\n' \
    > "$d/plan/nodes.tsv"
  printf '%s' "$d"
}
queue_baseline() { # queue_baseline <dir>
  local d="$1"
  "$SCHEDULER" snapshot --repo "$d/repo" --out "$d/plan/dirty.tsv" >/dev/null
  "$SCHEDULER" build --root "$d/plan" --nodes "$d/plan/nodes.tsv" \
    --manifest "$d/plan/run-manifest.tsv" --source-root "$d/repo" \
    --source-head "$(git -C "$d/repo" rev-parse HEAD)" \
    --dirty-snapshot "$d/plan/dirty.tsv" --repo-mode git >/dev/null
}
# The two guards, run together: nothing the queue wrote may reach either.
queue_guards_pass() { # queue_guards_pass <dir> <description>
  local d="$1" what="$2"
  "$SCHEDULER" snapshot --repo "$d/repo" --out "$d/plan/after.tsv" >/dev/null
  cmp -s "$d/plan/dirty.tsv" "$d/plan/after.tsv" \
    || fail "$what: a queue write changed the scheduler's dirty snapshot"
  "$SCHEDULER" check-dirty --repo "$d/repo" --snapshot "$d/plan/dirty.tsv" \
    --manifest "$d/plan/run-manifest.tsv" --allow-items - > "$d/plan/check.out" \
    || fail "$what: a queue write failed check-dirty"
  has "$d/plan/check.out" 'DIRTY_STATE=unchanged' "$what: check-dirty did not report an unchanged tree"
  "$SIMPLIFY" marker --repo "$d/repo" --completed 2026-08-27T00:00:00Z > "$d/plan/marker.out" \
    || fail "$what: a queue write failed the simplification marker's clean-tree gate"
  has "$d/plan/marker.out" 'PLN-SIMPLIFY-V1 completed=' "$what: no marker line was produced"
}

# Answer (a) — committed in the repository, at the default project root. Both
# halves are exercised: an untracked queue, and a tracked one whose index a
# later filing modifies.
d="$(queue_case committed)"
queue_baseline "$d"
"$QUEUE_BIN" init --project "$d/repo" >/dev/null
"$QUEUE_BIN" add --project "$d/repo" --id first --claim 'the first follow-up' \
  --source 'this run' >/dev/null
hasnt "$d/plan/dirty.tsv" 'pln/QUEUE.md' 'the baseline snapshot listed the queue index'
# git itself sees the queue as dirt, which is what makes the assertion below a
# statement about the exclusion rather than about an empty write.
[ -n "$(git -C "$d/repo" status --porcelain --untracked-files=all -- pln)" ] \
  || fail 'the untracked-queue case did not actually dirty the working tree'
queue_guards_pass "$d" 'an untracked queue at the project root'
git -C "$d/repo" add pln
git -C "$d/repo" commit -qm 'commit the queue'
queue_baseline "$d"
"$QUEUE_BIN" add --project "$d/repo" --id second --claim 'the second follow-up' \
  --source 'this run' >/dev/null
[ -n "$(git -C "$d/repo" status --porcelain -- pln)" ] \
  || fail 'the tracked-queue case did not actually dirty the queue'
queue_guards_pass "$d" 'a tracked queue whose index a filing modified'

# An instruction-file-derived root inside the working tree is the same case with
# the root somewhere else entirely, which is exactly why the exclusion is scoped
# to the queue's own paths rather than to whatever the root turns out to be.
d="$(queue_case declared)"
printf 'pln-queue: docs/queue\n' > "$d/repo/CLAUDE.md"
git -C "$d/repo" add CLAUDE.md
git -C "$d/repo" commit -qm 'declare the queue location'
queue_baseline "$d"
"$QUEUE_BIN" add --project "$d/repo" --id declared-item --claim 'filed into the declared root' \
  --source 'this run' > "$d/plan/add.out"
has "$d/plan/add.out" "QUEUE_ROOT=$(cd "$d/repo" && pwd -P)/docs/queue" \
  'the declared root did not resolve where this case needs it'
queue_guards_pass "$d" 'a queue at a root the project instructions declared'

# Answers (b) and (c) put the queue outside the working tree, where there is
# nothing to exclude — asserted rather than assumed, because "invisible" is the
# property the location answer was chosen for.
d="$(queue_case commondir)"
mkdir -p "$d/repo/.git/pln"
queue_baseline "$d"
"$QUEUE_BIN" add --project "$d/repo" --id in-common-dir --claim 'filed into the shared git dir' \
  --source 'this run' > "$d/plan/add.out"
has "$d/plan/add.out" 'RESOLVED_BY=common-dir' 'this case did not resolve to the shared git directory'
queue_guards_pass "$d" 'a queue in the shared git directory'

d="$(queue_case external)"
mkdir -p "$WORK/outside-queue"
outside_root="$(cd "$WORK/outside-queue" && pwd -P)"
printf 'pln-queue: %s\n' "$outside_root" > "$d/repo/CLAUDE.md"
git -C "$d/repo" add CLAUDE.md
git -C "$d/repo" commit -qm 'declare an external queue'
queue_baseline "$d"
"$QUEUE_BIN" add --project "$d/repo" --id outside --claim 'filed outside the repository' \
  --source 'this run' > "$d/plan/add.out"
has "$d/plan/add.out" "QUEUE_ROOT=$outside_root" 'this case did not resolve outside the repository'
queue_guards_pass "$d" 'a queue outside the repository'

# The scoping, and it is the load-bearing half: a bare top-level `QUEUE.md`, `q`
# or `done` is *not* excluded. Were it, a queue root at the repository top level
# would disable dirty-state accounting and the clean-tree gate for every
# user-owned change in the repository — which is worse than the failure the
# exclusion exists to fix, and is why no queue root is ever the top level.
d="$(queue_case toplevel)"
queue_baseline "$d"
mkdir -p "$d/repo/q" "$d/repo/done/2026-08"
printf '<!-- pln-queue v1\n-->\n' > "$d/repo/QUEUE.md"
printf 'a top-level item\n' > "$d/repo/q/item.md"
printf 'a top-level archive\n' > "$d/repo/done/2026-08/index.md"
"$SCHEDULER" snapshot --repo "$d/repo" --out "$d/plan/after.tsv" >/dev/null
has "$d/plan/after.tsv" 'QUEUE.md' 'a bare top-level QUEUE.md was excluded from the dirty snapshot'
has "$d/plan/after.tsv" 'q/item.md' 'a bare top-level q/ was excluded from the dirty snapshot'
has "$d/plan/after.tsv" 'done/2026-08/index.md' 'a bare top-level done/ was excluded from the dirty snapshot'
if "$SCHEDULER" check-dirty --repo "$d/repo" --snapshot "$d/plan/dirty.tsv" \
  --manifest "$d/plan/run-manifest.tsv" --allow-items - >"$WORK/out" 2>"$WORK/err"; then
  fail 'a repository-top-level queue disabled check-dirty for the whole repository'
fi
if "$SIMPLIFY" marker --repo "$d/repo" --completed 2026-08-27T00:00:00Z \
  >"$WORK/out" 2>"$WORK/err"; then
  fail 'a repository-top-level queue disabled the simplification clean-tree gate'
fi
has "$WORK/err" 'clean non-ignored tree' 'the marker refused without naming the clean-tree requirement'

echo "OK"
