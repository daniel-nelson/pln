---
name: pln-phase-review-approval
---

# /pln phase: plan review and approval

<!-- pln:include active-turn-lifecycle -->

Read this file in full before the first review or approval action. `Phase: review-approval` permits only plan review, plan repair, the approval conversation, and durable adoption writes; no feature implementation may begin here.

A review round remains in this phase until its merge result and all plan repairs/findings are durable. Persist any reopened question before sending it. After explicit adoption, write the Ship choice and PR base, write the queue items this run takes, reconcile all open questions/findings, then set `Phase: implementation` and read the implementation phase in full before dispatch. Delegated mode's advance adoption uses the same durable writes before advancing.

**A follow-up named at any point in this phase is filed in the turn it is named**, by running `{{OUTPUT_ROOT}}/bin/pln-queue add` — not by leaving it in prose for the close to remember.

<!-- pln:include assurance-policy -->

## Consulting a peer model

Some of this skill's work is worth putting to a **peer**: a model other than the one running this session, asked to check what that model produced. A fresh agent on this host is a fresh context; a peer is a fresh context *and* a different set of blind spots. Below, `$PLN_BIN` stands for `{{SKILL_DIR}}/bin` — substitute the real path when you run it.

<!-- pln:include peer-consult -->

## The plan review switch

Before the approval gate, the finished plan itself goes under review (Step 3.5): a reader that never saw the interview argues with the plan and checks its claims against the files it names. It is on by default, and exactly two things turn it off — a standing preference in config, and an instruction in the session. Nothing else does. **The size of the plan never does:** a two-item plan and a twelve-item plan get the same review. There is no small-plan shortcut, because the reviewer's cost is reading the plan and checking its claims, which already scales with the plan, and because the short plan is regularly the dangerous one — two items that change how every future run behaves are worth more scrutiny than nine items of one-line edits.

**The standing preference** is `plan_review` in `~/.pln/config.yaml`, read once where the review would start:

```bash
{{SKILL_DIR}}/bin/pln-config get plan_review
```

`false` or `no` means off, for every plan in every repository. Anything else — including absent, which is what an install that has never been told otherwise reads — means on. Off sends nothing and runs no reviewer. Usually it is a quiet authoritative opt-out; when assurance classification is R3, the gate must say plainly that critical plan assurance was skipped. `{{SKILL_DIR}}/bin/pln-config set plan_review false` turns it off, `true` back on.

**A spoken instruction wins over the key, for that run only**, in both directions — "skip the review" where the key is on, "review this one" where it is off — and never writes to config. Config is the standing preference; a sentence is about this plan. Honor it whenever it arrives before the gate, including mid-interview, and don't literal-match: infer the intent from natural phrasing, the way the defer / drop / think-offline signals are inferred.

The review has three parts that can be switched off separately, and an instruction naming one leaves the others running:

- **The whole step** — "skip the review", "no review this time", "straight to the gate". Step 3.5 doesn't run.
- **The peer** — "skip the cross-model pass", "don't send it anywhere", "keep it local". The review still runs, on a fresh same-model agent, exactly as if no peer had been available. Treat it as a `peer_consent` of `false` for that run: nothing is sent, no consent question is raised, and the result says which rung ran as always.
- **Applying anything** — "just tell me, don't change the plan", "flag everything". The review runs and every finding reaches the gate flagged; nothing is written into `PLAN.md`.

An instruction broader than any one of those (a bare "skip it") is the whole step. When it is genuinely ambiguous which part is meant, ask one short question instead of guessing — guessing wrong either sends a plan the user meant to keep on the machine, or throws away a review they wanted.

## Plan review ownership

The coordinator owns whether review runs, risk/roster validation, reader dispatch, the approval gate, and user-driven re-review. The always-loaded readiness sweep owns peer consent and egress prompts; review never raises them late. The coordinator never reads raw findings. The broad/specialist/adversarial reviewer contract is `{{SKILL_DIR}}/src/workers/plan-review.md`; reconciliation lives in `{{SKILL_DIR}}/src/workers/plan-review-merge.md`.

Every reviewer sees the plan but never the interview transcript or rejected options. The merge worker alone reads raw findings, checks citations/evidence state, updates `PLAN.md`, and returns a bounded envelope. A finding on a user-made decision is protected from repair. Empty or failed readers contribute nothing and are named accurately at the gate. The coordinator reads only the validated 4096-byte envelope; malformed merge output gets one fresh judgment retry, then fails closed.
### Step 3.5. Plan review

Every item's detail section is now written, and nobody has read the plan who wasn't in the conversation that produced it. This reading happens before adoption. The universal enabled floor is one fresh broad judgment reviewer inheriting the hosting model; semantic risk may add specialists and the R3 adversarial slot.

1. Use the existing `evidence/` and `results/` folders. Dispatch `assurance-classification.md`, validate its output with `pln-assurance classify`, then create the pre-fix roster with `pln-assurance roster`. If plan review is off, run no readers; record the opt-out and warn only for R3.
2. Assemble the broad review brief without opening the contract or plan in coordinator context:

   ```bash
   "$PLN_BIN/pln-build-review-brief" \
     --contract "{{SKILL_DIR}}/src/workers/plan-review.md" \
     --plan "<plan-dir>/PLAN.md" --root "<repository-root>" \
     --commit "$(git rev-parse HEAD)" --out "<plan-dir>/evidence/plan-review.brief.md"
   ```

3. Spawn the fresh same-model broad reviewer on that brief. For R2/R3, assemble distinct briefs naming each rostered specialist area and spawn at most those two readers. Each writes a distinct raw artifact and returns only its pointer. Missing, empty, malformed, errored, timed-out, or wrong-tree output is failed coverage.
4. For R3, fill the roster's adversarial slot through Consulting a peer model when consent, egress policy, and repository/session classification permit. Otherwise spawn one fresh same-model adversarial reviewer in that same slot and attribute why model-family independence was absent. In R1/R2, consult a peer only for an explicit request or recorded assurance-first posture; it is additive and its absence does not invent a substitute slot.
5. Spawn one fresh merge worker with `{{SKILL_DIR}}/src/workers/plan-review-merge.md`, the plan path, all raw artifact paths, actual-reader/role attribution, exact source fingerprint, whether applying is enabled, item scope, `evidence/plan-review-merge.md`, `results/plan-review-merge.txt`, and a 4096-byte budget. On a bounded round, these findings replace the in-scope items' earlier findings. The merge worker alone reads findings and edits `PLAN.md`.
6. Validate the merge envelope through `bin/pln-read-envelope --root <plan-dir> --max-bytes 4096`. At least the broad reader must succeed; for R3, a failed role is a visible coverage failure rather than a clean plan. Never open raw findings in this context.

**Spawning same-model reviewers on this host:**

<!-- pln:include plan-review-invoke -->

The review runs once on the finished plan. Re-showing the gate does not trigger another pass. A material user rewrite does, bounded as described below; a repair made by the merge worker does not.

**What the plan is checked against** is the tree as it stands before any item runs, and this step finishes before Step 5 starts. A review that overlaps implementation reads a repository the plan no longer describes: an item's own repair comes back as the pre-existing state, the plan is reported as wrong about the world, and the items still unbuilt yield nothing, so the half of the review that is still valid is the half that found nothing. Reviewing what implementation produced is a diff review and belongs to `/pln-pr`.

### Step 4. Master-plan approval gate

**Resolve mandated questions first.** Before anything else in this step, check the dashboard's Pre-flight findings for a mandated rule (Step 1: a required decision named by the project's own `CLAUDE.md`/`AGENTS.md`) that the interview never actually resolved — not every mandated rule needs a decision, but one that does isn't allowed to ride into the gate unanswered. If one is still open, ask and resolve it now, in its own message, one question at a time exactly as in Step 3. Record the answer in the dashboard before moving on. Only once every mandated question is resolved does the gate itself get shown, and it gets shown in a message of its own — never folded into the same message as a mandated question, and never bundled with the adopt choice below.

Show the user the master plan in one message, with enough in it to adopt on without opening the file:

- Print the dashboard (status list) — the same bullet list of items the Step 2 skeleton showed, updated. This is the user's overview and their editing surface, and it is cheap: in a measured 9,195-character gate it was under a tenth of the message. It stays.
- **Do not print a digest of the items.** Every item's intent was settled with the user, question by question, in the interview they just finished; restating it back is the largest avoidable block in the message and it is the half they already know. The detail lives in `PLAN.md` for the implementer and the reviewer.
- Print **one numbered list of what was settled without the user**: the decide-and-disclose calls that clear The fork test, and — when Step 3.5 ran — the findings the review flagged rather than rejected or repaired.

  **What earns a number is filtered before the list is built, not after.** Anything that fails The fork test is not listed — it is the work, and it lives in its item's section. That is the cut, and it is most of what used to fill this list. Findings that all reopen the same decision are one entry, so the number of entries is the number of questions, not the number of defects.

  **A call already said in the flow still gets a number**, in its own group at the top marked as already-said, one line each. It is tempting to collapse those into a clause with a count, since the user saw them once and one word would have stopped them — but that rests on the disclosure line having registered, and it lands mid-interview inside a message about something else. A line read past is not a decision ratified. Keep the number, so the gate stays the one surface where everything decided without the user is visible and answerable by number. One number space across both kinds (so the user can reply "3, 7, 8" without saying which kind each is), each entry named by its item's title as well as its number per Naming things the user reads. Each entry is one line that opens with its kind:
  - ***decision*** — what was decided, with its cited rationale.
  - ***flagged*** — the finding in one sentence, what the reviewer would change, and which kind it is: a false factual claim, a contradiction inside the plan, or a judgment call.

  Every ***flagged*** entry names the reader role(s) that raised it; duplicate defects remain one entry with complete attribution.

  **Repairs are never listed, and neither are rejections.** A finding the reviewer raised and you repaired is you fixing your own drafting inside a document the user does not read — it was never theirs to write and is not theirs to ratify. It is recorded in its item's section, and a rejection in the dashboard's Plan review section; both are for the implementer, the reviewer, and the next revision of this filter. In the gate this rule was drawn from, sixteen of thirty-six numbered entries were repairs: 44% of the list, none of it actionable.

  A finding that lands on the plan as a whole rather than on any one item — a missing item, an ordering that won't work — is numbered in the same sequence, in a final group of its own after the per-item ones. It is in the dashboard's Open questions, not in an item's section, but it is one of the things the user can act on, so it gets a number like everything else.
- When Step 3.5 ran, say in one clause the risk tier and which reader roles actually ran. For R3, name the peer or the reason a fresh same-model adversarial substitute ran; never imply model-family independence when it was absent. A review that found nothing gets the same clause and no more.
- Self-triage the list. Lead with the entries you're least sure about and name them for the user's eye ("worth a look: 3, 7"). One triage line covers the whole list rather than one per kind — the single number space exists so there is one thing to scan and one way to reply. **What earns a place is that your answer and theirs would produce different builds**, which is a harder bar than the fork test itself and is meant to be: an entry closest to the ask/decide line, one whose authority is weakest, one where you can genuinely picture them saying "no, the other one". Two or three is the usual size of that; a triage line naming half the list has triaged nothing. The rest stand as a scannable list the user can skim or ignore. The risk to avoid is a miscalibrated "all safe here" that buries an entry the user would have changed; when genuinely unsure, flag rather than bury. The offer to walk the flagged entries one at a time (see Walking the flagged entries below) leads the adopt prompt, so the user answers them where they are told about them instead of scrolling back up a forty-entry list to reply by number.
- End with a five-way prompt, one option per line:

  ```
  Adopt this master plan?
  a) walk the flagged entries one at a time
  b) implement it and open a draft PR when done
  c) implement it and open a PR when done
  d) implement only
  e) reopen anything by number / change something?
  ```

  When the triage line names no entries, option a has nothing to walk: drop it, letter the three ship shapes a, b and c, and letter the reopen option d, restoring the four-way shape.

  **Review depth rides on the same answer.** A ship option takes the full PR-time roster its risk tier calls for. Adding `light` or `no review` to the letter cuts that to the broad reviewer alone, or skips review entirely. Offer it in one line under the prompt rather than as more lettered options — this is the one moment the user is already deciding how much ceremony the branch gets, and the answer is what keeps `/pln-pr` from stopping to ask later.

**When no review ran** — `plan_review` is off, the user skipped it, or the plan predates review — include no empty findings machinery. For R1/R2 the numbered list is disclosed decisions only. For R3, add one clear warning that critical plan assurance was deliberately skipped; do not claim a reviewer or clean result.

This is the only place implementation-blocking approval lives. Possible responses:

- *Walk the flagged entries* — the triaged entries one question per turn, per Walking the flagged entries below. Not an adoption: the walk ends back at this prompt.
- *Adopt* — one of the three shapes below. Whichever it is, every numbered entry not reopened stands as accepted: decisions hold and flagged findings were seen and left alone. Proceed to Step 5.
  - **Implement and open a draft PR when done.** Record `Ship: draft PR after implementation` in the dashboard's Ship field, plus `PR base: <branch>` when item 4's stacking override applies. This answers Step 8's ask up front: Step 7's wrap-up hands straight to `/pln-pr` with no further prompt. The PR opens as a draft and **stays** one — `/pln-pr` still watches CI and still fixes what goes red, and then closes with the PR in draft instead of marking it ready. On a team, ready is what tells everyone else, and whatever automation waits on ready, that the branch is theirs to look at; this option keeps that signal in the user's hands so they can read the PR first.
  - **Implement and open a PR when done.** Record `Ship: PR after implementation` in the dashboard's Ship field, plus `PR base: <branch>` when item 4's stacking override applies. Same as the draft-PR option, except `/pln-pr` marks the PR ready once CI is green.
  - **Implement only.** Record `Ship: implement only` in the dashboard's Ship field. Step 8 still asks once, at the end of Step 7's wrap-up, exactly as it did before this choice existed.

  Under either PR-bearing shape, the same write records the review depth in the Ship field — `Review: full`, `Review: broad`, or `Review: none`, defaulting to `full` when the user named none. Under `implement only` there is no PR to size a roster for; Step 8's later ask carries the depth instead.

  Whichever shape it is, the same write fills the dashboard's `## Queue items` section: the follow-up-queue ids this run takes, one per line, or `- none taken` when it takes none. Create the section above `## Ship` when the plan does not carry one. Adoption is not recorded while the section still reads `- (not yet declared)` — answering it is what makes a run that takes queue items say so, and Step 5 claims each id it names.
- *Reopen by number* (e.g. "3, 7, 8") — any entry, of either kind. A **decision** returns to the one-question-at-a-time interview, exactly like Step 3, but starting from the recorded position and its rationale, not a blank question ("I chose X because Y; here's the tradeoff; what would you change?"). A **flagged** finding becomes an interview question of the same shape: what the reviewer found, what it would change, what the user wants done. Resolve each, update `PLAN.md`, re-show, re-prompt. Unlisted entries remain accepted.

  A repair is not on the list, so it cannot be reopened by number — but the user can still name one they disagree with in prose, and it is then shown with what it replaced and reverted if they say so. The record in the item's detail section is what makes that one edit instead of a reconstruction; re-read the revert to confirm it landed.
- *Change X* — make the change in `PLAN.md`, re-show the affected section(s), re-prompt the same adopt question. Loop until the user adopts.

A rewrite made through either response is an item's section being written again, so it goes through Step 3's four checks — the first of them most of all. A reopened decision has changed that item's premise, and the parts written under the old one are reconciled rather than left standing beside the new answer.

**Walking the flagged entries.** Choosing the walk takes the triaged entries in Step 3's format: one question per turn, `AskUserQuestion` never used, each entry restated in full when its turn comes — its number and title, what it is, and what each answer changes — because by then the list is several screens up and the point of the walk is that nothing has to be found again. It is the *Reopen by number* path with the hunting removed, and it ends the same way: update `PLAN.md`, re-show, re-prompt. The walk is not an adoption: a ship option still adopts the whole plan, triaged entries included, walked or not.

A walked entry the user changes is a rewrite like any other and starts a bounded round below; one they look at and leave alone is not, and starts nothing. When a round produces its own triage line, the re-prompt's walk covers its entries the same way — the user skips it as easily as they choose it, and dropping it would hide findings that reached the line by the same triage.

**A finding earns a question only when the answer is the user's to give.** This governs every round after the plan has first been shown for adoption, and it is the one thing standing between a review that pays for itself and a walk that ends in fatigue. Measured across seven sessions, half of all post-gate questions caught a defect that would have caused wrong or wasted implementation — a plan anchored to the wrong model, an index that would have deadlocked a page permanently, a whole workstream built on a phrase that was never meant as a mechanism. A quarter caught nothing, and they share one shape: **you already knew the answer.** So the test is not whose text the finding is against — a finding against a repair you wrote is as likely to be real as any other, and suppressing that whole class loses genuine defects. The test is whether the user has a decision to make.

Do not ask when any of these is true; repair the plan and say in one line that you did.

- **You have already decided and you are content with the decision.** "I decided this rather than asking, so here's my reasoning to argue with" is not a question. Record the decision as a decision; the user reopens it by number if they disagree.
- **You are about to concede the premise.** If the honest next turn is "you're right, my framing was wrong," the framing was wrong before it was sent. Check the premise against the plan and the repository first, and drop the question when it does not survive.
- **The user has already answered it.** An option they passed over one round ago is settled. Re-offering it reads as not having listened, and it is.
- **A correction to your own error does not change their answer.** Fix it, name the correction in one line, and leave their answer standing rather than asking them to re-confirm it.
- **It is an observation, not a finding.** Something you noticed about the shape of an entry, which no implementer would get wrong, is not something to raise as though it were actionable.

None of this drops a finding. What is repaired is recorded in its item's section and named in the one-line report, so the user can reopen it like anything else. And when a finding does earn a question, the cost of asking it twice is the same as the cost of a wasted one: write it plainly the first time, in the terms the user has been using, not in the vocabulary of the reviewer that raised it.

**Re-review after a rewrite.** Both responses above are the user changing the plan, and a change the user made is the only thing that starts another round. An edit made through either counts as a rewrite of an item, for this purpose, when it changes that item's premise, intent, acceptance criteria, or a decision another item depends on. An edit that only tightens wording, fixes a typo, or is otherwise trivially correct does not. Neither does a repair you made yourself in response to a review finding: a repair is finished once it is made and recorded in its item's section, and reading your own response to a reviewer is the loop that has no end. So an item a correction touched and the user did not is not a changed item here.

When one or more items are rewritten, re-run Step 3.5 bounded to just those items before re-showing the gate — not the whole plan again. Give the re-review each rewritten item's section plus the sections of any items whose own text names it as a dependency, so a cross-item contradiction the rewrite introduced is still catchable. The new pass's findings replace the rewritten item's prior findings entirely; findings on every other, untouched item stand as they were. Say in one line which items were re-reviewed before re-prompting, and record the round in the dashboard's Plan review section.

**The roster is bounded by the same change the items are.** The tier is a property of the plan and does not move, but a round's readers are chosen from what the rewritten items now carry, not from what the plan carried when the tier was set. The broad reader always runs — it is the one that reads the change as a whole. A specialist re-runs only where the rewritten sections still carry the signal that specialist owns, and the adversarial slot only where the rewrite touched a decision it argued with or introduced a new one of that weight. A rewrite that carries none of them is the broad reader alone. Say which readers ran and why in the same line that names the re-reviewed items, so a reader that did not run is a visible decision rather than a silent economy — and where a rewrite genuinely re-opens a specialist's area, that specialist runs, whatever it costs.

This is a bound on the round, never on the tier or on the first pass: the pre-gate review that produces the plan's own findings runs the full roster its tier calls for, and a re-classification that finds the plan has *become* higher-risk raises the tier for every round after it. What it stops is the reflex. Measured on a real run: a mid-interview scope addition of one detail re-ran four readers, a merge and a risk re-classification at high effort — the second full R3 roster in one hour, on a change no infrastructure or external-effects reader had anything to say about.

**When the rounds stop.** Coverage decides this, not cost. They stop when every item the user changed has been read since they changed it and that latest reading found no false factual claim and no contradiction inside the plan. A judgment call earns no further round; it goes to the gate flagged like any other finding. There is no round cap and none is needed — only the user's own edits start a round, so the rounds end when the user stops editing. A cap would end them somewhere else instead, leaving whatever the last rewrite introduced unread. What keeps the rounds from turning into a walk of questions the user has no decision in is the bar above, not a limit on how many rounds may run.

Do not enter Step 5 without an explicit adoption signal. Delegated mode is the one exception, and only because the signal was already given: the instruction that entered it adopts the plan in advance for the whole run, and what that mode prints before Step 5 is its short list of reversals, one-way doors, flagged findings and unanswerable questions — not a gate.
