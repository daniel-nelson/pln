#!/usr/bin/env bash
# tests/queue.sh — bin/pln-queue, the helper that owns the follow-up queue.
#
# The helper exists because prose gets skipped: a run has to call it, and the
# closing message renders what it printed back. So the properties under test are
# the ones a close depends on and cannot check for itself — that `add` returns
# the exact line it wrote, that `list` fails loudly rather than rendering an
# empty follow-up list, that nothing destroys a record, and that the queue is
# found again on the next run wherever the user put it.
#
# Everything runs against a scratch tree: bash and git only, no network, no
# agent CLI, no credentials. HOME is redirected into the scratch directory, so
# nothing reads the developer's own state and a `~/`-relative queue root lands
# in the sandbox. Dates come from PLN_QUEUE_DATE, so a month boundary or a
# staleness cutoff cannot make this script's result depend on the day it runs.
#
# Run:  bash tests/queue.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUEUE="$REPO_DIR/bin/pln-queue"

# Resolved with `pwd -P`: the helper reports absolute physical paths, and on
# macOS the default TMPDIR is itself a symlink, so an unresolved scratch root
# would make every path comparison below fail for the wrong reason.
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/pln-queue-test.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
mkdir -p "$HOME"
export PLN_QUEUE_DATE=2026-08-27

fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" || fail "$3"; }
hasnt() { grep -qF -- "$2" "$1" && fail "$3"; return 0; }
line_is() { grep -qxF -- "$2" "$1" || fail "$3"; }
said() { case "$Q_OUT$Q_ERR" in *"$1"*) ;; *) fail "$2" ;; esac; }
didnt_say() { case "$Q_OUT$Q_ERR" in *"$1"*) fail "$2" ;; esac; return 0; }

[ -x "$QUEUE" ] || fail "missing executable queue helper: $QUEUE"

# Every call keeps its streams on disk, so a byte comparison is possible and a
# non-zero exit is a fact under test rather than an abort.
Q_OUT=''; Q_ERR=''; Q_RC=0
q() {
  set +e
  "$QUEUE" "$@" >"$WORK/out" 2>"$WORK/err"
  Q_RC=$?
  set -e
  Q_OUT="$(cat "$WORK/out")"
  Q_ERR="$(cat "$WORK/err")"
}
ok() { # ok <description> <args...>
  local what="$1"; shift
  q "$@"
  [ "$Q_RC" = 0 ] || fail "$what exited $Q_RC: $Q_ERR"
}
refused() { # refused <description> <args...>
  local what="$1"; shift
  q "$@"
  [ "$Q_RC" != 0 ] || fail "$what exited 0 (expected a refusal)"
}
field() { sed -n "s/^$1=//p" "$WORK/out" | head -1; }
is() { # is <field> <expected> <description>
  local got; got="$(field "$1")"
  [ "$got" = "$2" ] || fail "$3 ($1 was '$got', expected '$2')"
}

new_repo() { # new_repo <dir>
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email test@example.com
  git -C "$d" config user.name Test
  printf 'base\n' > "$d/base.txt"
  git -C "$d" add base.txt
  git -C "$d" commit -qm base
}

index_payload() { # index_payload <list-stdout-file> <dest>
  awk '/^INDEX_BEGIN$/ { f = 1; next } /^INDEX_END$/ { f = 0 } f' "$1" > "$2"
}

# appears_before <file> <first> <second> <description>
appears_before() {
  local f="$1" first="$2" second="$3" what="$4" a b
  a="$(awk -v n="$first" 'index($0, n) { print NR; exit }' "$f")"
  b="$(awk -v n="$second" 'index($0, n) { print NR; exit }' "$f")"
  [ -n "$a" ] || fail "$what (never found: $first)"
  [ -n "$b" ] || fail "$what (never found: $second)"
  [ "$a" -lt "$b" ] || fail "$what"
}

# ─── resolution, leg 4: create and ask ────────────────────────────────────────
# Nothing to find, so the helper creates the default root and reports the
# location question as still owed — the only state that records an answer lives
# in the queue's own header, so a run that never asks leaves it saying so.
R="$WORK/created"
new_repo "$R"
ok "init in a project with no queue" init --project "$R"
is QUEUE_ROOT "$R/pln" "init did not create the default queue root"
is RESOLVED_BY created "init did not report that it created the queue"
is CREATED 1 "init did not report the creation"
is LOCATION_QUESTION owed "a created queue did not report the location question as owed"
is MIGRATION_OFFERED none "a fresh queue reported a migration offer"
[ -d "$R/pln/q" ] || fail "init created no live-item directory"

# The header sentinel is the first line, exactly, and it is what every other
# reader keys on — pln-scheduler and pln-simplify identify a queue root by it.
[ "$(sed -n 1p "$R/pln/QUEUE.md")" = '<!-- pln-queue v1' ] \
  || fail "the index does not open with the '<!-- pln-queue v1' sentinel"
has "$R/pln/QUEUE.md" "queue-root: $R/pln" "the index header does not record the resolved root"
has "$R/pln/QUEUE.md" '_No open items._' "an empty index does not say it is empty"

# ─── resolution, leg 1: an existing queue is found again ──────────────────────
ok "a second init in the same project" init --project "$R"
is QUEUE_ROOT "$R/pln" "the second run resolved a different root"
is RESOLVED_BY project-root "the second run did not find the existing queue"
is CREATED 0 "the second run created a queue over one that already existed"

# The answered question and the migration offer are recorded in that header and
# nowhere else, so no state exists outside the queue.
ok "recording the answered location question" init --project "$R" --answered --migration-offered
is LOCATION_QUESTION answered "the answered location question was not recorded"
is MIGRATION_OFFERED 2026-08-27 "the migration offer was not dated"
ok "a later run" init --project "$R"
is LOCATION_QUESTION answered "the answered location question did not survive a later run"
is MIGRATION_OFFERED 2026-08-27 "the recorded migration offer did not survive a later run"

# ─── resolution, leg 2: the shared git directory ──────────────────────────────
# Answer (b). The common dir is not a working-tree path, so it survives every
# worktree — and it must resolve to the same root from anywhere inside the tree.
R="$WORK/commondir"
new_repo "$R"
mkdir -p "$R/.git/pln"
printf 'pln-queue: %s\n' "$WORK/declared-loser" > "$R/CLAUDE.md"
ok "init with a queue in the common dir" init --project "$R"
is RESOLVED_BY common-dir "the common-dir leg did not resolve the queue"
is QUEUE_ROOT "$R/.git/pln" "the common-dir leg resolved the wrong root"
[ ! -e "$WORK/declared-loser" ] || fail "the instruction-file leg ran ahead of the common dir"
mkdir -p "$R/deep/sub"
ok "init from a subdirectory" init --project "$R/deep/sub"
is QUEUE_ROOT "$R/.git/pln" "the common-dir root differs when resolved from a subdirectory"

# Leg 1 sits above leg 2: a queue at the project root wins even when the common
# dir holds one too, which is why an applied answer has to move what it left.
mkdir -p "$R/pln"
ok "init with queues in both places" init --project "$R"
is RESOLVED_BY project-root "the common dir shadowed a queue at the project root"

# ─── resolution, leg 3: the project's own instruction files ───────────────────
# A named directory becomes the root.
R="$WORK/named-dir"
new_repo "$R"
printf '# Project\n\n- `pln-queue:` `docs/queue`\n' > "$R/CLAUDE.md"
ok "init with a declared directory" init --project "$R"
is RESOLVED_BY instructions "the declared directory did not resolve the queue"
is QUEUE_ROOT "$R/docs/queue" "the declared directory produced the wrong root"

# A named *file* makes its containing directory the root, and the file itself is
# never touched — it is what item 13's migration offer reads.
R="$WORK/named-file"
new_repo "$R"
mkdir -p "$R/notes"
printf 'an existing unstructured to-do file\n' > "$R/notes/TODO.md"
before="$(cat "$R/notes/TODO.md")"
printf 'pln-queue: notes/TODO.md\n' > "$R/AGENTS.md"
ok "init with a declared file" init --project "$R"
is RESOLVED_BY instructions "the declared file did not resolve the queue"
is QUEUE_ROOT "$R/notes" "the declared file did not make its directory the root"
said 'derived the root from the named file TODO.md' \
  "init did not report which named file the root came from"
[ "$(cat "$R/notes/TODO.md")" = "$before" ] || fail "the named to-do file was written to"

# `~/` in a declaration resolves against HOME, which this script owns.
R="$WORK/named-home"
new_repo "$R"
printf 'pln-queue: ~/followups\n' > "$R/CLAUDE.md"
ok "init with a home-relative declaration" init --project "$R"
is QUEUE_ROOT "$HOME/followups" "a ~/-relative declaration did not resolve against HOME"

# Only the declaration form counts. Prose that merely mentions the helper is not
# a location, or leg 3 would turn every passing reference into a queue root.
R="$WORK/prose"
new_repo "$R"
printf 'Follow-ups are filed with pln-queue, somewhere under docs.\n' > "$R/CLAUDE.md"
ok "init with prose that names no path" init --project "$R"
is RESOLVED_BY created "prose mentioning the helper was read as a declaration"

# ─── resolution: what is never adopted ────────────────────────────────────────
# A `pln` that is something else is passed over *and* refused as a creation
# target: writing into it would put the queue somewhere nobody chose.
for kind in symlink other-content gitlink; do
  R="$WORK/refuse-$kind"
  new_repo "$R"
  case "$kind" in
    symlink)
      mkdir -p "$WORK/refuse-$kind-target"
      ln -s "$WORK/refuse-$kind-target" "$R/pln"
      needle='is a symlink, not adopted'
      ;;
    other-content)
      mkdir -p "$R/pln"
      printf 'someone else lives here\n' > "$R/pln/README.md"
      needle='holds something other than a queue, not adopted'
      ;;
    gitlink)
      mkdir -p "$R/pln"
      printf 'submodule content\n' > "$R/pln/inner.txt"
      git -C "$R" update-index --add \
        --cacheinfo 160000,0000000000000000000000000000000000000001,pln
      needle='is a git submodule mountpoint, not adopted'
      ;;
  esac
  refused "init against a $kind at pln/" init --project "$R"
  said "$needle" "init did not say why the $kind at pln/ was passed over"
  said 'nothing was written' "init did not say that nothing was written for the $kind case"
  [ ! -e "$R/pln/QUEUE.md" ] || fail "init wrote an index into the $kind at pln/"
done

# The repository top level is refused as a queue root under either shape it can
# arrive in. Adopting it would scatter QUEUE.md, q/ and done/ across the top
# level and put pln's own dirt exclusion in front of every user-owned change.
R="$WORK/top-level-file"
new_repo "$R"
printf 'old todos\n' > "$R/TODO.md"
printf 'pln-queue: TODO.md\n' > "$R/CLAUDE.md"
ok "init with a declared file at the repository top level" init --project "$R"
said 'is the repository top level, not adopted' \
  "a top-level declared file was adopted as the queue root"
is QUEUE_ROOT "$R/pln" "a refused top-level root did not fall through to the default"

R="$WORK/top-level-dir"
new_repo "$R"
printf '<!-- pln-queue v1\n-->\n' > "$R/QUEUE.md"
printf 'pln-queue: .\n' > "$R/CLAUDE.md"
ok "init with the repository top level declared" init --project "$R"
said 'is the repository top level, not adopted' \
  "the declared repository top level was adopted as the queue root"
is QUEUE_ROOT "$R/pln" "a refused top-level root did not fall through to the default"

# A bare repository has a common dir and no work tree, so there is nowhere for a
# queue to live: it must fall through rather than write inside the git dir.
git init -q --bare "$WORK/bare.git"
refused "init in a bare repository" init --project "$WORK/bare.git"
said 'bare repository' "init in a bare repository did not say why it refused"

# --no-create is the read-only form: it resolves or refuses, and never writes.
R="$WORK/nocreate"
new_repo "$R"
refused "init --no-create with nothing to find" init --project "$R" --no-create
[ ! -e "$R/pln" ] || fail "init --no-create created a queue"

# ─── add: the detail file is canonical, and it lands first ────────────────────
R="$WORK/filing"
new_repo "$R"
ok "filing the first item" add --project "$R" \
  --id cancel-releases-held-dates \
  --claim 'a cancelled booking never releases its held dates' \
  --source 'the cancellation change, PR review' \
  --group refunds --touches 'app/bookings/,app/calendar/availability.rb' \
  --holds staging-deploy
detail="$(field DETAIL_FILE)"
[ "$detail" = "$R/pln/q/cancel-releases-held-dates.md" ] \
  || fail "the detail file's path is not derived from the item's id: $detail"

# The read-back rule is a render of this line, so it has to be the line that is
# in the file — not a reconstruction of it.
add_line="$(field INDEX_LINE)"
[ -n "$add_line" ] || fail "add printed no INDEX_LINE"
line_is "$R/pln/QUEUE.md" "$add_line" "add's INDEX_LINE is not verbatim in the index"
case "$add_line" in
  '- [ ] ready · a cancelled booking never releases its held dates → `q/cancel-releases-held-dates.md`') ;;
  *) fail "add composed an unexpected index line: $add_line" ;;
esac

# A conforming detail file: the frontmatter fields the format defines, and a
# leading `# <claim>` H1 that is what every reader takes the claim from.
[ "$(sed -n 1p "$detail")" = '---' ] || fail "the detail file has no frontmatter"
for f in 'id: cancel-releases-held-dates' 'state: "[ ]"' 'urgent: false' 'status: ready' \
  'opened: 2026-08-27' 'source: the cancellation change, PR review' 'group: refunds' \
  'depends_on: []' 'touches: [app/bookings/, app/calendar/availability.rb]' \
  'holds: [staging-deploy]'; do
  line_is "$detail" "$f" "the detail file is missing '$f'"
done
line_is "$detail" '# a cancelled booking never releases its held dates' \
  "the detail file carries no leading '# <claim>' H1"
for section in '## What exists and where' '## What to do' '## What has to be true first' \
  '## How to tell it worked' '## Related' '## Sub-items'; do
  has "$detail" "$section" "the detail file's packet is missing '$section'"
done

# Refusing rather than overwriting: an id is a path, and `mv` would take the
# record with it.
refused "filing a second item under an existing id" add --project "$R" \
  --id cancel-releases-held-dates --claim 'a different claim' --source elsewhere
said 'nothing was overwritten' "a refused add did not say the record was untouched"
line_is "$detail" '# a cancelled booking never releases its held dates' \
  "a refused add rewrote the existing detail file"

# The detail file is written *before* the index line, which is what makes an
# interruption leave a recoverable orphan instead of a phantom line. Injecting a
# malformed detail file makes the index rebuild fail, so the write that did land
# before it is the one under test.
printf 'not a detail file\n' > "$R/pln/q/broken.md"
refused "an add whose index rebuild fails" add --project "$R" \
  --id second-item --claim 'the second item' --source s
[ -f "$R/pln/q/second-item.md" ] \
  || fail "add lost the detail file when the index write failed — the index is written first"
hasnt "$R/pln/QUEUE.md" 'q/second-item.md' "a failed add left a phantom index line"
didnt_say 'INDEX_LINE=' "a failed add still reported an index line"

# `list` fails closed while the queue cannot be read. A close renders its
# follow-up bullets from this call, so a silent empty result would reproduce the
# exact failure the queue exists to fix.
refused "list over an unreadable detail file" list --project "$R"
didnt_say 'INDEX_BEGIN' "a failed list still emitted an index"

# With the malformed file gone, the orphan is adopted by the rebuild.
rm "$R/pln/q/broken.md"
ok "list after the orphan became readable" list --project "$R"
has "$WORK/out" 'q/second-item.md' "the rebuild did not adopt the orphaned detail file"

# And a line with no detail file behind it does not survive the rebuild.
printf -- '- [ ] ready · a phantom → `q/ghost.md`\n' >> "$R/pln/QUEUE.md"
ok "list after a hand-edited index" list --project "$R"
hasnt "$R/pln/QUEUE.md" 'q/ghost.md' "the rebuild kept an index line with no detail file"

# ─── list: the derived order, and the same bytes every time ───────────────────
R="$WORK/order"
new_repo "$R"
add_item() { # add_item <id> <claim> [args...]
  local id="$1" claim="$2"; shift 2
  ok "filing $id" add --project "$R" --id "$id" --claim "$claim" --source 'this run' "$@"
}
add_item urgent-old 'urgent, opened first' --urgent --group zulu --opened 2026-01-01
add_item urgent-new 'urgent, opened later' --urgent --group alpha --opened 2026-06-06
add_item refund-early 'the earliest refund item' --group refunds --opened 2026-02-02
add_item refund-late 'the latest refund item' --group refunds --opened 2026-05-05
add_item refund-undated 'a refund item with no date' --group refunds
# Three items filed in one run, which is the case the date cannot order: they
# all carry today's. A fourth carries no `opened` at all, which item 5 allows.
add_item loose-c 'the third ungrouped item'
add_item loose-b 'the second ungrouped item'
add_item loose-a 'the first ungrouped item'
sed -i.bak 's/^opened: .*/opened:/' "$R/pln/q/refund-undated.md"
rm -f "$R/pln/q"/*.bak

ok "listing the whole queue" list --project "$R"
is ITEM_COUNT 8 "list miscounted the live items"
is STATUS items "list did not report that the queue has items"
index_payload "$WORK/out" "$WORK/payload-1"
cmp -s "$WORK/payload-1" "$R/pln/QUEUE.md" \
  || fail "list's INDEX_BEGIN/INDEX_END payload is not the index file's bytes"

idx="$R/pln/QUEUE.md"
appears_before "$idx" '## Urgent' '## refunds' "the Urgent section is not above the group headings"
appears_before "$idx" '## refunds' '## Everything else' \
  "the ungrouped catch-all is not last"
# A flagged item renders under `## Urgent` and not again beneath its group, so a
# group whose only members are flagged gets no heading at all.
hasnt "$idx" '## zulu' "a flagged item's group got a heading of its own"
hasnt "$idx" '## alpha' "a flagged item's group got a heading of its own"
for id in urgent-old urgent-new refund-early refund-late refund-undated loose-a loose-b loose-c; do
  [ "$(grep -cF "q/$id.md" "$idx")" = "1" ] \
    || fail "$id does not appear exactly once in the index"
done
has "$idx" '- [ ] ! ready · urgent, opened first → `q/urgent-old.md`' \
  "the urgency flag does not render as a single ! before the status word"

# The whole precedence chain, one assertion per level, with nothing hand-set
# anywhere in it (src/shared/queue-format.md:42): the flag, then the group, then
# date opened, then the items carrying no `opened` date, then `id`. The fixture
# above is built so that each level has to do the work — drop any one of them
# and one of these five flips.
#
# 1. The flag outranks the group. `urgent-old` is in `zulu` and `refund-early`
#    is in `refunds`, so on group alone the refund would come first.
appears_before "$idx" 'q/urgent-old.md' 'q/refund-early.md' \
  "an unflagged item sorts above a flagged one"
# 2. The group outranks the date, inside `## Urgent` as well, where it renders
#    no heading: `urgent-new` is in `alpha` and was opened five months after
#    `urgent-old` in `zulu`, and it still comes first.
appears_before "$idx" 'q/urgent-new.md' 'q/urgent-old.md' \
  "the group does not order flagged items above date opened"
# 3. The date orders within one group.
appears_before "$idx" 'q/refund-early.md' 'q/refund-late.md' \
  "a group's items are not ordered by date opened"
# 4. The undated follow the dated rather than sorting as if they were oldest.
appears_before "$idx" 'q/refund-late.md' 'q/refund-undated.md' \
  "an item with no date opened does not sort after the dated ones"
# 5. `id` is the last tiebreak, and it is what orders three items filed in one
#    run, which share one `opened` and would otherwise tie with nothing left.
appears_before "$idx" 'q/loose-a.md' 'q/loose-b.md' \
  "three items filed in one run are not ordered by id"
appears_before "$idx" 'q/loose-b.md' 'q/loose-c.md' \
  "three items filed in one run are not ordered by id"

# Two runs over an unchanged set of detail files produce the same bytes, and a
# hand-mangled index is restored to them rather than merged with.
ok "listing a second time" list --project "$R"
index_payload "$WORK/out" "$WORK/payload-2"
cmp -s "$WORK/payload-1" "$WORK/payload-2" \
  || fail "two list runs over an unchanged queue produced different bytes"
printf 'stray prose\n' >> "$idx"
sed -i.bak '/loose-a/d' "$idx" && rm -f "$idx.bak"
ok "listing after the index was mangled" list --project "$R"
cmp -s "$WORK/payload-1" "$idx" \
  || fail "the rebuild did not restore the index to its derived bytes"

# An empty queue is a real read, and says so — the output is never empty, so a
# close can tell an empty queue from a failed call.
R="$WORK/empty"
new_repo "$R"
ok "listing an empty queue" list --project "$R"
is ITEM_COUNT 0 "an empty queue did not report a zero item count"
is STATUS empty "an empty queue did not report STATUS=empty"
said 'INDEX_BEGIN' "an empty list emitted no index markers"
said '_No open items._' "an empty index does not say it is empty"

# ─── check: the refusal names what it collided with ───────────────────────────
R="$WORK/overlap"
new_repo "$R"
mk() { ok "filing $1" add --project "$R" --id "$1" --claim "$1" --source s "${@:2}"; }
mk wide --touches 'app/bookings/'
mk narrow --touches 'app/bookings/cancellation.rb'
mk elsewhere --touches 'docs/guide.md'
mk deploy-a --touches 'app/a.rb' --holds 'staging-deploy'
mk deploy-b --touches 'app/b.rb' --holds 'staging-deploy,evals'
mk unknown-writes

ok "checking a directory claim against a file beneath it" check --project "$R" --id wide --against narrow
said 'CHECK=refused' "a prefix overlap was not refused (directory declared first)"
said $'COLLISION\tnarrow\tpath\tapp/bookings' \
  "the refusal did not name the colliding item and path"
ok "checking a file claim against the directory above it" check --project "$R" --id narrow --against wide
said 'CHECK=refused' "a prefix overlap was not refused (file declared first)"
said $'COLLISION\twide\tpath\tapp/bookings/cancellation.rb' \
  "the reversed refusal did not name the colliding item and path"

ok "checking two items that share a resource" check --project "$R" --id deploy-a --against deploy-b
said 'CHECK=refused' "a shared holds token was not refused"
said $'COLLISION\tdeploy-b\tresource\tstaging-deploy' \
  "the refusal did not name the colliding item and resource"

ok "checking an item that declares no touches" check --project "$R" --id unknown-writes --against elsewhere
said 'CHECK=refused' "an item with no touches was reported parallel-safe"
said 'unknown-writes declares no touches' "the refusal did not say the subject's writes are unknown"
ok "checking against an item that declares no touches" check --project "$R" --id elsewhere --against unknown-writes
said 'CHECK=refused' "an item with no touches was taken as writing nothing"
said 'unknown-writes declares no touches' "the refusal did not name the item with unknown writes"

ok "checking two disjoint items" check --project "$R" --id wide --against elsewhere
said 'CHECK=clear' "two disjoint items were not reported parallel-safe"
didnt_say 'COLLISION' "a clear check still reported a collision"

# `mark` is the refinement path: an item filed with unknown writes becomes
# parallel-safe once someone has looked, without being refiled.
ok "filling in touches after filing" mark --project "$R" --id unknown-writes --touches 'lib/util.rb'
ok "checking the refined item" check --project "$R" --id unknown-writes --against elsewhere
said 'CHECK=clear' "an item refined with mark --touches is still reported unknown"

# ─── claim: one lock over the check and the record ────────────────────────────
R="$WORK/claiming"
new_repo "$R"
ok "filing the contested item" add --project "$R" --id contested --claim 'the contested item' \
  --source s --touches 'app/contested.rb'
ok "warming the queue" list --project "$R"

# Two runs racing for one item. A bare check cannot enforce a refusal — both can
# read a clear answer — so exactly one of these must come away holding it.
# `set +e` inside each subshell: the loser exits non-zero, and under `set -e`
# that would abort the subshell before it could record which one it was.
( set +e; "$QUEUE" claim --project "$R" --id contested --run run-a >"$WORK/claim-a" 2>&1
  echo "$?" > "$WORK/claim-a.rc" ) &
( set +e; "$QUEUE" claim --project "$R" --id contested --run run-b >"$WORK/claim-b" 2>&1
  echo "$?" > "$WORK/claim-b.rc" ) &
wait
held="$(grep -l 'CLAIM=held' "$WORK/claim-a" "$WORK/claim-b" | wc -l | tr -d '[:space:]')"
[ "$held" = "1" ] || fail "two concurrent claims produced $held holders, expected exactly 1"
if grep -q 'CLAIM=held' "$WORK/claim-a"; then
  winner=run-a; loser="$WORK/claim-b"; loser_rc="$(cat "$WORK/claim-b.rc")"
else
  winner=run-b; loser="$WORK/claim-a"; loser_rc="$(cat "$WORK/claim-a.rc")"
fi
[ "$loser_rc" != "0" ] || fail "the losing claim exited 0"
has "$loser" 'CLAIM=refused' "the losing claim did not report a refusal"
has "$loser" "HELD_BY=$winner" "the losing claim did not name the run that holds the item"
has "$R/pln/q/contested.md" "claimed_by: $winner" \
  "the holder was not recorded in the item's own record"

# A stale claim is released only by naming the holder it displaces.
refused "stealing under the wrong holder" claim --project "$R" --id contested --run run-c --steal nobody
said "HELD_BY=$winner" "a mis-aimed steal did not name the actual holder"
said 'nothing was released' "a mis-aimed steal did not say the claim stands"
ok "stealing under the right holder" claim --project "$R" --id contested --run run-c --steal "$winner"
said "STOLEN_FROM=$winner" "a steal did not name the holder it displaced"
said 'CLAIM=held' "a steal did not record the new holder"
has "$R/pln/q/contested.md" 'claimed_by: run-c' "a steal did not rewrite the holder"

# A claim that collides is refused and records nothing.
ok "filing an overlapping item" add --project "$R" --id overlapping --claim 'overlapping work' \
  --source s --touches 'app/contested.rb'
refused "claiming an item that collides with the held set" claim --project "$R" \
  --id overlapping --run run-d
said 'CHECK=refused' "a colliding claim did not report the collision"
hasnt "$R/pln/q/overlapping.md" 'claimed_by' "a refused claim recorded a holder anyway"

# ─── the same-run path exemption ──────────────────────────────────────────────
# A run's own path overlaps are already scheduler ordering, so refusing them a
# second time stops a plan from claiming the items it exists to do. The exemption
# is per pair and covers `path` alone: `resource`, `unknown` and a foreign run
# keep refusing, and the identity that unlocks it is the run string *and* the
# worktree it claimed from.
R="$WORK/same-run"
new_repo "$R"
mkq() { ok "filing $1" add --project "$R" --id "$1" --claim "$1" --source s "${@:2}"; }
mkq head --touches 'app/shared.rb'
mkq tail --touches 'app/shared.rb'
mkq probe --touches 'app/shared.rb'
mkq stranger --touches 'app/shared.rb'
mkq both-a --touches 'app/both.rb' --holds 'staging-deploy'
mkq both-b --touches 'app/both.rb' --holds 'staging-deploy'

ok "claiming the first item of the run" claim --project "$R" --id head --run plan-1
said 'CLAIM=held' "the first claim of a run was not granted"
has "$R/pln/q/head.md" 'claimed_by: plan-1' "the claim did not record the run"
has "$R/pln/q/head.md" "claimed_in: $R" \
  "the claim record does not carry the worktree it was claimed from"

# The same run, from the same worktree, on a path-overlapping item.
ok "claiming a path-overlapping item for the same run" claim --project "$R" --id tail --run plan-1
said 'CLAIM=held' "a run was refused its own path overlap"
said $'EXEMPT\thead\tpath\tapp/shared.rb' \
  "the exempted claim did not name the same-run overlap it passed over"
said 'CHECK=clear' "an exempted claim did not report the check as clear"

# A shared `holds` resource keeps refusing, including for the pair that shares
#    a path *and* a resource — the case a set-derivation exemption would drop.
ok "claiming the first of the two resource holders" claim --project "$R" --id both-a --run plan-1
refused "claiming a same-run item that shares a holds resource" claim --project "$R" \
  --id both-b --run plan-1
said $'COLLISION\tboth-a\tresource\tstaging-deploy' \
  "a same-run resource collision was not refused, or did not name the resource"
said $'EXEMPT\tboth-a\tpath\tapp/both.rb' \
  "the same pair's path overlap was not exempted alongside the resource refusal"
hasnt "$R/pln/q/both-b.md" 'claimed_by' "a resource-colliding claim recorded a holder anyway"

# A different run is refused, unchanged, naming the item and what it shares.
refused "claiming a path-overlapping item for a different run" claim --project "$R" \
  --id stranger --run plan-2
said $'COLLISION\thead\tpath\tapp/shared.rb' \
  "a foreign run's path collision was not refused, or did not name the item and path"
didnt_say 'EXEMPT' "a foreign run's claim reported an exemption"

# `--against` is honored verbatim: the caller named that set, so nothing in it
#    is exempt.
ok "checking a same-run pair through an explicit --against" check --project "$R" \
  --id probe --against head --run plan-1
said 'CHECK=refused' "--against was given the same-run exemption"
said $'COLLISION\thead\tpath\tapp/shared.rb' "--against did not report the overlap it was handed"

# `check` never reports clear where `claim` would refuse. Run-less it is
#    conservative; with `--run` it agrees with `claim --run` exactly.
ok "checking without a run" check --project "$R" --id probe
said 'CHECK=refused' "a run-less check passed over an overlap it cannot attribute"
said $'COLLISION\thead\tpath\tapp/shared.rb' "a run-less check did not name the overlap"
ok "checking with the run that holds the overlap" check --project "$R" --id probe --run plan-1
said 'CHECK=clear' "check --run disagreed with what claim --run would grant"
said $'EXEMPT\thead\tpath\tapp/shared.rb' "check --run did not name the overlap it passed over"
ok "checking a resource collision with its own run" check --project "$R" --id both-b --run plan-1
said 'CHECK=refused' "check --run reported clear for a pair claim --run refuses"

# An undeclared `touches` on either side keeps refusing, same run or not: an
# unknown write set is not a path overlap and inherits nothing from the argument
# the exemption rests on. Its own queue, so the unknown record cannot make the
# checks above refuse for a reason they were not testing.
R="$WORK/same-run-unknown"
new_repo "$R"
mkq silent
mkq vague --touches 'app/vague.rb'
mkq later --touches 'app/later.rb'
refused "claiming a same-run item that declares no touches" claim --project "$R" \
  --id silent --run plan-1
said 'silent declares no touches' "an item with unknown writes was claimable by its own run"
ok "claiming an item that later loses its touches" claim --project "$R" --id vague --run plan-1
ok "clearing the held item's touches" mark --project "$R" --id vague --touches ''
refused "claiming against a same-run item whose writes are unknown" claim --project "$R" \
  --id later --run plan-1
said $'COLLISION\tvague\tunknown' \
  "a same-run item with no touches was exempted through the unknown branch"

# One run string, two worktrees: two repositories whose instructions declare
#    one queue root meet in one queue, and the run string alone cannot separate
#    them. The claiming worktree is what does.
QROOT="$WORK/shared-root"
for tree in tree-one tree-two; do
  new_repo "$WORK/$tree"
  printf 'pln-queue: %s\n' "$QROOT" > "$WORK/$tree/CLAUDE.md"
done
ok "filing into the shared root from the first tree" add --project "$WORK/tree-one" \
  --id shared-head --claim 'shared head' --source s --touches 'app/shared.rb'
is QUEUE_ROOT "$QROOT" "the declared root was not adopted from the first tree"
ok "filing into the shared root from the second tree" add --project "$WORK/tree-two" \
  --id shared-tail --claim 'shared tail' --source s --touches 'app/shared.rb'
is QUEUE_ROOT "$QROOT" "the two trees did not resolve to one queue root"
ok "claiming from the first tree" claim --project "$WORK/tree-one" --id shared-head --run 2026-08-31-x
has "$QROOT/q/shared-head.md" "claimed_in: $WORK/tree-one" \
  "the claim did not record which of the two trees it came from"
refused "claiming the same run's overlap from another worktree" claim \
  --project "$WORK/tree-two" --id shared-tail --run 2026-08-31-x
said $'COLLISION\tshared-head\tpath\tapp/shared.rb' \
  "one run string in two worktrees passed its own overlap"
ok "claiming the same run's overlap from the worktree that holds it" claim \
  --project "$WORK/tree-one" --id shared-tail --run 2026-08-31-x
said 'CLAIM=held' "the claiming worktree was refused its own overlap"

# ─── mark: the three markers, the flag, and the sub-item checklist ────────────
R="$WORK/marking"
new_repo "$R"
ok "filing an item to mark" add --project "$R" --id partly --claim 'an item done in parts' --source s
detail="$R/pln/q/partly.md"
for state in '[ ]' '[-]' '[x]'; do
  ok "marking $state" mark --project "$R" --id "partly" --state "$state"
  line_is "$detail" "state: \"$state\"" "mark did not set the completion marker to $state"
  case "$(field INDEX_LINE)" in
    "- $state "*) ;;
    *) fail "the index line does not carry the $state marker mark just set" ;;
  esac
done

# The parent's marker is what its sub-items add up to: any child done and any
# child not makes it `[-]`. The checklist is body text the helper appends to and
# the parent's own marker is frontmatter, so the two are set together here.
ok "adding a finished sub-item" mark --project "$R" --id partly \
  --add-sub-item 'release the held dates when a booking is cancelled' --sub-item-state '[x]'
ok "adding an unfinished sub-item" mark --project "$R" --id partly \
  --add-sub-item 'the same when the host cancels rather than the guest'
line_is "$detail" '- [x] release the held dates when a booking is cancelled' \
  "mark did not append the finished sub-item under the checklist"
line_is "$detail" '- [ ] the same when the host cancels rather than the guest' \
  "mark did not append the unfinished sub-item under the checklist"
ok "deriving the parent from mixed children" mark --project "$R" --id partly --state '[-]'
line_is "$detail" 'state: "[-]"' "a parent with mixed children is not [-]"
case "$(field INDEX_LINE)" in
  '- [-] '*) ;;
  *) fail "the index line does not show the derived [-] parent" ;;
esac

# The flag is set and cleared after filing, since an item that becomes urgent
# must not have to be refiled.
ok "flagging an item urgent" mark --project "$R" --id partly --urgent true
line_is "$detail" 'urgent: true' "mark did not set the urgency flag"
case "$(field INDEX_LINE)" in
  '- [-] ! '*) ;;
  *) fail "the index line does not carry the ! flag mark just set" ;;
esac
has "$R/pln/QUEUE.md" '## Urgent' "a flagged item did not move into the Urgent section"
ok "clearing the flag" mark --project "$R" --id partly --urgent false
line_is "$detail" 'urgent: false' "mark did not clear the urgency flag"
case "$(field INDEX_LINE)" in
  '- [-] ! '*) fail "the index line still carries the ! flag after it was cleared" ;;
esac
hasnt "$R/pln/QUEUE.md" '## Urgent' "the Urgent section survived its last item being cleared"

# The other frontmatter fields a refinement sets.
ok "refining the rest of the frontmatter" mark --project "$R" --id partly \
  --status blocked --group refunds --holds 'staging-deploy' --depends-on 'other-item' \
  --source 'the review that found it'
for f in 'status: blocked' 'group: refunds' 'holds: [staging-deploy]' \
  'depends_on: [other-item]' 'source: the review that found it'; do
  line_is "$detail" "$f" "mark did not set '$f'"
done
has "$R/pln/QUEUE.md" '## refunds' "a regrouped item did not move under its group heading"

# The helper owns the frontmatter and the checklist it appends to, and nothing
# else in the body.
printf '\nA paragraph a person wrote.\n' >> "$detail"
ok "marking an item with hand-written body prose" mark --project "$R" --id partly --status ready
line_is "$detail" 'A paragraph a person wrote.' "mark rewrote body prose it did not write"

# ─── archive: a record moves, and nothing is ever destroyed ───────────────────
R="$WORK/archiving"
new_repo "$R"
ok "filing an item to finish" add --project "$R" --id finished --claim 'work that landed' --source s
printf '\nEvidence a person wrote into the packet.\n' >> "$R/pln/q/finished.md"

# `completed` is refused for a record nobody marked `[x]`: the marking and the
# evidence cannot come apart.
refused "archiving an unfinished item as completed" archive --project "$R" --id finished \
  --disposition completed --evidence 'the commit that closed it'
said 'nothing writes a completion nobody verified' \
  "an unverified completion was refused without saying why"
[ -f "$R/pln/q/finished.md" ] || fail "a refused archive removed the live record"

ok "marking the item done" mark --project "$R" --id finished --state '[x]'
ok "archiving the finished item" archive --project "$R" --id finished \
  --disposition completed --evidence 'commit abc1234'
archived="$(field ARCHIVE_FILE)"
month_index="$(field ARCHIVE_INDEX)"
[ "$archived" = "$R/pln/done/2026-08/finished.md" ] \
  || fail "the archive path is not <queue-root>/done/<YYYY-MM>/<slug>.md: $archived"
[ "$month_index" = "$R/pln/done/2026-08/index.md" ] \
  || fail "the month index is not beside the archived record: $month_index"
is DISPOSITION completed "archive did not report the disposition"
is STATE '[x]' "archive did not report the state the record kept"

# The record exists at the archive path and nowhere else, with its body intact.
[ ! -e "$R/pln/q/finished.md" ] || fail "the record is still in the live queue after archiving"
hasnt "$R/pln/QUEUE.md" 'q/finished.md' "the archived item still has a live index line"
line_is "$archived" '# work that landed' "the archived record lost its claim"
line_is "$archived" 'Evidence a person wrote into the packet.' "the archived record lost its body"
for f in 'disposition: completed' 'archived: 2026-08-27' 'evidence: commit abc1234'; do
  line_is "$archived" "$f" "the archived record is missing '$f'"
done
has "$month_index" '- [x] completed · work that landed → `finished.md` — commit abc1234' \
  "the month index did not gain the archived record's line"

# A terminal state that is not a completion keeps the state it had: nothing
# writes an [x] for work nobody verified.
ok "filing an item finished elsewhere" add --project "$R" --id elsewhere-done \
  --claim 'work that got done some other way' --source s
ok "marking what actually landed" mark --project "$R" --id elsewhere-done --state '[-]'
ok "archiving on the user's confirmation" archive --project "$R" --id elsewhere-done \
  --disposition resolved-elsewhere --evidence 'the user said the refactor covered it'
is STATE '[-]' "an externally-resolved record did not keep its own state"
hasnt "$(field ARCHIVE_FILE)" 'state: "[x]"' "an externally-resolved record gained an [x]"
has "$month_index" 'resolved-elsewhere · work that got done some other way' \
  "the month index did not record the terminal disposition"

# Archiving refuses rather than overwriting an occupied destination — an
# unguarded `mv` would destroy the record the archive exists to keep.
ok "refiling under an archived id" add --project "$R" --id finished \
  --claim 'the same work came back' --source s
ok "marking the refiled item done" mark --project "$R" --id finished --state '[x]'
refused "archiving over an existing record" archive --project "$R" --id finished \
  --disposition completed --evidence 'a second commit'
said 'nothing was overwritten' "a refused archive did not say the record was untouched"
line_is "$archived" '# work that landed' "a refused archive overwrote the archived record"
[ -f "$R/pln/q/finished.md" ] || fail "a refused archive removed the live record"

# There is no delete subcommand, and an unknown one is refused rather than
# guessed at.
refused "a delete subcommand" delete --project "$R" --id finished
has "$WORK/err" 'There is no delete subcommand' \
  "the usage text does not say that a record is archived, never destroyed"
hasnt "$WORK/err" 'pln-queue delete' "the usage text advertises a delete subcommand"
[ -f "$R/pln/q/finished.md" ] || fail "a refused subcommand removed a record"

# ─── stale: candidates, and not one write ─────────────────────────────────────
R="$WORK/staleness"
new_repo "$R"
PLN_QUEUE_DATE=2026-01-01 ok "filing an aged item" add --project "$R" --id aged \
  --claim 'filed long ago' --source s --touches 'a.rb'
PLN_QUEUE_DATE=2026-01-01 ok "filing an item to abandon" add --project "$R" --id abandoned \
  --claim 'claimed and left' --source s --touches 'b.rb'
PLN_QUEUE_DATE=2026-01-01 ok "abandoning a claim" claim --project "$R" --id abandoned --run gone-run
ok "filing a finished item nobody archived" add --project "$R" --id done-not-archived \
  --claim 'marked done and left in the live queue' --source s
ok "marking it done" mark --project "$R" --id done-not-archived --state '[x]'
ok "filing a dropped item" add --project "$R" --id dropped-not-archived \
  --claim 'dropped and left in the live queue' --source s
ok "dropping it" mark --project "$R" --id dropped-not-archived --status dropped
ok "filing a fresh item" add --project "$R" --id fresh --claim 'filed today' --source s

before="$(cd "$R/pln" && find . -type f | sort | xargs shasum)"
ok "reporting staleness" stale --project "$R" --days 30
is STALE_DAYS 30 "stale did not report the window it used"
is STALE_CUTOFF 2026-07-28 "stale did not report the cutoff it computed"
said $'STALE\taged\taged\t-' "an aged item was not reported"
said $'STALE\tabandoned\tclaim-abandoned\tgone-run' \
  "an abandoned claim was not reported with the run that holds it"
said $'STALE\tdone-not-archived\tcompleted-not-archived' \
  "a completed but unarchived record was not reported"
said $'STALE\tdropped-not-archived\tdropped-not-archived' \
  "a dropped but unarchived record was not reported"
didnt_say $'STALE\tfresh' "a fresh item was reported stale"
is STALE_COUNT 4 "stale reported the wrong number of candidates"
after="$(cd "$R/pln" && find . -type f | sort | xargs shasum)"
[ "$before" = "$after" ] || fail "stale wrote to the queue; it reports and never writes"

# ─── the scratch tree is the only thing that was written ──────────────────────
[ ! -e "$HOME/.pln" ] || fail "the helper wrote to the developer's pln state directory"

echo "OK"
