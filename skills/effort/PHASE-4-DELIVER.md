# Phase 4: Deliver

Only after the operator has approved gate three.

Begin by re-reading the world, per [`SKILL.md`](SKILL.md). `<bin>` and `<id>` are the helper folder and the owner id that file establishes. Then, in order:

1. **Confirm the verified commit still covers `HEAD`.**

   ```bash
   <bin>/capstan-claim drift <working copy> --document-home <resolved document home>
   ```

   Exit 0: nothing outside the document home changed since `verified_commit`. The verification stands, and whatever it lists inside the document home is records, reported as such in step 7. Exit 8: something else landed after verification, the operator's own commits between gates included, or sits uncommitted. The verification does not cover what is about to ship, so run `verify` again on the integration and record the new commit before going on; red sends it back to phase 3 and ends this run here. Exit 6: no verified commit was ever recorded, so phase 3 did not finish, and this run ends here saying so. From this step on nothing in this phase changes the repository outside the document home, so the commit `drift` confirmed is the commit that ships. The version was settled before verification, in phase 3, and is not revisited here.

2. Dispatch the Courier, handing it the working copy's absolute path so it can read `capstan-knowledge-base` there, and the verified commit with the version it carries, so the note names what a reader six months out can match against what they have installed. It packages what ships, drafts the recipient briefs, writes the knowledge-base note, and reports the note's absolute path. Capstan never runs git in the knowledge base.

3. Dispatch a Reviewer on the note, unless the Courier reports no knowledge base was configured, in which case there is no note and nothing to review. The note review has no fixed point: no commit, no branch, no tag, because Capstan never runs git in the knowledge base. Tell the Reviewer this plainly — it is a degraded review rather than a clean one. Hand over the note's absolute path; the Reviewer reads the whole note at that path rather than a diff, and says so in its report. Also hand over the absolute path to `.capstan/effort/spec.md` in the main working copy, and to the decision log, `decisions.md` in the document home, which is `<working copy>/.capstan/` unless configured otherwise, so the note's Spec axis is graded against what the effort actually decided, and to `agents/courier.md` — the standard the note was written against, holding both the copy-versus-derive rule for its frontmatter and what its body must cover.

4. Read the findings. Action every one or dismiss it with the reason written down. A blocking finding goes back to the Courier as a fix task on the same note, corrected in place: the note is not committed yet, so there is no history to preserve or rewrite. Register it first:

   ```bash
   <bin>/capstan-claim dispatch <working copy> --owner <id> note
   ```

   Exit 5 is `capstan-max-fix-dispatches` reached on the note: the finding stays open, nothing is reset, and the run ends here reporting what is outstanding, the same as a slice at its limit in `PHASE-3-BUILD.md`.

   If the run ends before step 6, for any reason, checkpoint the claim before it does. Phase 4 ends in deletion rather than a gate, so nothing else records where the note loop stopped.

5. **Rotate the decision log**, now that the note is written and reviewed: `<bin>/capstan-log rotate <document home>`. This runs after the note rather than before it, because the Courier and its Reviewer both read `decisions.md` whole, and rotating first would move a row out from under one of them mid-read. Run it at every document home, default or configured: Capstan writes files to a configured home the same as the default, per `## Document home` above, it only refrains from running git there.

   | Exit | Means | Do |
   |---|---|---|
   | 0 | Rotated, or a no-op because the log is still under threshold | Continue |
   | 1 | `<document home>` or its `decisions.md` is missing | Stop and report it; phase 3 should have left both in place |
   | 2, 3, 4, 5 | Refused: a target archive already exists, a row number repeats, a row does not parse, or the header is missing or malformed | Nothing was written. Stop and report the fault in the log itself; it needs a person's eyes before anything else touches it |
   | 6 | Internal: the row multiset differed before and after; nothing was written | Stop and report it as a fault in the helper, not in the log |
   | 7 | Failed: a rename failed partway | Not safe to rerun as is. The message names the archive file to remove first; remove exactly that, then rerun once |
   | 64 | Usage error | Fix the invocation and rerun |

   At the default document home, the rotated `decisions.md` and any new archive file ship in this phase's own commit, the same ordinary unattended work as every other write there. At a configured document home, they are written and left for the operator to commit, the same as the note.

6. Delete the scratch, exact paths only:

   ```bash
   <bin>/capstan-scratch-clean <working copy> --effort <slug> --owner <id>
   ```

   It deletes `<working copy>/.capstan/effort/` and the copies a sync service makes of it, `effort 2`, `effort 3`, and so on, once the claim inside names this effort and the lock is yours. 391 recorded such a copy outliving a delivery, and the wildcard that once reached them reached `effort-archive` too. A copy whose claim names a different effort is left in place and named: it is that effort's state, stale or not, and only `--any-effort` deletes it, passed once the Tracker shows every row of that effort at `merged` or `dropped`. Anything else in `.capstan/` is left alone and named in the output, whatever its name begins with; `decisions.md`, `CONTEXT.md`, `decisions/` and `tracker.md` are never candidates. A symlink standing where the scratch should be is removed as a link, its target untouched. Nothing to delete is a valid outcome: the scratch is already gone, and the step is done. The lock goes with the scratch, and that is the release. Delete all of it: spec, plan, scout findings, review output, checkpoint drafts. A stale spec or an old research file left behind is worse than none: the next agent reads it as current and builds on something that stopped being true. The Tracker is not part of this deletion. Unset, that means `tracker.md`: it lives in the document home, not the scratch, and stays, carrying every row this effort's slices reached.

7. Report to the operator: what shipped and the commit verification ran against, every commit since it, each named as inside the document home, what review found on the note, and what was actioned or dismissed. Say that the note is reviewed and ready, and that committing it is the operator's own action, to be done once, now. Say the same of the default branch: pushing it is the operator's own action too, done once, now.

Before sending a fix dispatch that would be the third on the note, or any dispatch after that, ask whether the instruction is wrong rather than the wording it produced. `dispatch note` prints `design-question: fires` from the third on. Ask it every time it prints, not once: a question asked at three and skipped from then on is how a note reaches nine rounds with nobody having named why. Answer it unattended, the same as any other call this phase makes without the operator, and write it to `decisions.md` in the document home every time it fires, whether or not the answer changed from the round before — a record that only appears on a changed answer looks identical to a round where nobody asked.

**Done when** `drift` exited 0 against the commit that ships, the note is reviewed, or its absence is reported as skipped, every finding is actioned or dismissed on the record, `capstan-scratch-clean` reports `<working copy>/.capstan/effort/` and every sync-made sibling of it gone, and the operator has been told what shipped, the verified commit, what review found, and that the note and the default branch are theirs — the note to commit, the branch to push.
