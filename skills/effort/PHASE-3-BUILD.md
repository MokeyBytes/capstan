# Phase 3: Build

Begin by re-reading the world, per [`SKILL.md`](SKILL.md). `<bin>` and `<id>` below are the helper folder and the owner id that file establishes. Then:

1. **Create each worktree yourself, before dispatching.** One per slice, outside the repository tree:

   ```bash
   git -C <repo> worktree add -q <worktrees-dir>/<effort>-<slice> -b <effort>/<slice>
   ```

   Do not rely on a Builder's frontmatter for isolation. Frontmatter worktree isolation binds to the *session's* working directory rather than to the repository the work lives in, so it fails outright whenever the session is rooted elsewhere, which is most of the time. Creating them yourself works from any session and you control the cleanup.

   Use `-q`. Without it git prints a per-file progress bar, which on a large repository is thousands of lines of noise into your context for every slice.

   Tell each Builder the absolute path of its worktree and say plainly that it is to work there.

2. Dispatch Builders on the unblocked frontier, **at most `capstan-max-builders` at once**, per `## Limits` in `SKILL.md`. Register each one before spawning it:

   ```bash
   <bin>/capstan-claim dispatch <working copy> --owner <id> build --slice <slice>
   ```

   Exit 0 adds the slice to `builders_in_flight`; spawn the Builder. Exit 5 means the limit is reached or that slice is already out: spawn nothing, and dispatch it when a Builder returns. When one returns, before anything else:

   ```bash
   <bin>/capstan-claim return <working copy> --owner <id> --slice <slice>
   ```

   - **The scratch at `<working copy>/.capstan/effort/` is gitignored, so it does not exist inside any worktree.** Give every Builder the absolute path to the spec, the plan, and the Scout findings in the main working copy, and the resolved document home, and say the scratch is not in its worktree. A Builder that cannot find its brief will invent one; nor can it resolve the document home itself.
   - Be explicit about which paths are in its worktree and which are in the main copy. The same file exists at two paths and they are not interchangeable.
   - Move that slice's row in the Tracker to `building` as you dispatch it — `tracker.md` in the document home when `capstan-tracker` is unset, the board `TRACKER-GITHUB.md` describes when it names one. A slice dropped at any point in this phase moves its row to `dropped` — never delete a row, dropped or merged.

3. The three-effort ceiling is about efforts; the builder limit is about slices inside one. A one-slice plan means one Builder, and that is a correct outcome rather than a failure to parallelise. A frontier wider than the limit goes out in the order the Graph's edges make useful, and the rest waits for a return. Nothing here polls or schedules: a Builder returning is what frees a place, and the run still ends at the gate.

4. As each Builder returns, dispatch a Reviewer on **that** slice immediately. Do not wait for the whole wave. A slice reviews while its neighbours are still building.
   - Hand over the **fixed point** to review against, the slice's branch, the absolute paths to `.capstan/effort/plan.md` and `.capstan/effort/spec.md` in the main working copy, and the resolved document home. A Reviewer will not guess a fixed point, and `<working copy>/.capstan/effort/` does not exist inside the worktree it is reading.
   - **You** write each Reviewer return verbatim to `<working copy>/.capstan/effort/review/<slice>-<n>.md`, where `<n>` is a round counter starting at 1. Do not summarise it on the way in; the citations and the finding format are the parts that matter later.

5. Read the findings. You decide what gets acted on: every finding is either actioned or dismissed with the reason written down in `decisions.md` in the document home, never in the review file itself, which holds the return and nothing else. A blocking finding goes back as a new Builder task on the same slice, never to the instance that wrote it, after the question below clears it. Register it as a fix dispatch before spawning:

   ```bash
   <bin>/capstan-claim dispatch <working copy> --owner <id> fix --slice <slice>
   ```

   That is the count below going up by one, held in `CLAIM.md` so it survives a run boundary. Exit 5 changes nothing, and its first line says which of three cases it is. `is already in flight` and `builder limit N reached` are the same wait as step 2: spawn nothing, dispatch when a Builder returns. `fix-dispatch limit N reached` is the ceiling, and the run ends here, per **The limit** below. The same `return` as step 2 follows the Builder back.

   **The Reviewer-prescribed case.** That fix dispatch's return earns a Reviewer too, by step 4's own rule — with one exception. You may verify the fix yourself, in place of that round, when the fix applies the Reviewer's own prescribed moves verbatim, adds no new scope, and is checkable by reading the diff against the standards the finding cited rather than the moves it prescribed. All three, together, every time; how small the change looks is never a fourth one. Short of all three, the return goes to a Reviewer like any other. The exception only reaches a fix already shaped by a Reviewer's findings — an initial build has none to apply, so step 4 governs it without exception.

   **The declared-check case.** Nor does the exception above reach a fix a verify return prescribed, at step 9. There the Architect is the one who found the problem, wrote the dispatch, and would be the one grading the result — no independent eye touches it at any point, where the Reviewer-prescribed case differs exactly because an independent grader wrote the moves and the Architect is only confirming they were applied. That fix dispatch's return takes a Reviewer, step 4's rule undiminished, with one exception: where the verify return is the repository's own declared checks failing, the grader is that tool rather than the Architect. The three conditions just above are worded for a Reviewer's findings — a failing check prescribes no moves and cites no standards for them to name, so neither has a referent here — and this case answers to its own bar instead: the same named command that returned red now returns green against the integration, the diff adds no scope beyond what that failure implicates, and the check's own output is the whole of what is being graded. All three, together, every time, the same as above. An ad hoc check the Architect runs and reads itself, a grep included, is not a declared check no matter how red it looks.

6. Merge in dependency order. Builders never merge; you do, or you dispatch integration explicitly. A merge that conflicts goes to the `resolving-merge-conflicts` discipline, which holds where a hunk's intent is found and the one case where aborting beats resolving. As each slice merges, move its row in the Tracker to `merged`, carrying the merge commit.

7. **Remove each worktree once its slice is merged**, so a dead worktree never gets handed to a later Builder:

   ```bash
   git -C <repo> worktree remove <worktrees-dir>/<effort>-<slice>
   ```

8. **Settle the version before verifying.** If the repository declares a version, decide whether this effort changes it and record the answer in `decisions.md` in the document home either way, including a no. Where it does, write the new value per the repository's own convention and commit it on the integration branch now. Verification has to cover the commit that ships, and a version written after it is a change nothing verified; `PHASE-4-DELIVER.md` opens by checking exactly that. Do not push it. Delivery hands the push to the operator.

9. **Verify the integration**, per the `verify` discipline. Every slice passed in its own worktree, which says nothing about them together, and the gate-3 brief is about to claim the work is done. Red goes back as a Builder task on the slice the merge order implicates, not into this run, through the same `dispatch fix` as step 5 and after the question below clears it. Whether that fix dispatch's return takes a Reviewer, and the one case where it does not, is settled at step 5. Green ends with `verify` recording the commit it passed against in the claim; from that commit on, nothing in this phase or the next changes the repository outside the document home without `PHASE-4-DELIVER.md` sending it back here.
   - File the verify return the same way: write it verbatim to `<working copy>/.capstan/effort/review/verify-<n>.md`, `<n>` a round counter, and keep that file to the return alone — actioning or dismissing what it finds still goes in `decisions.md` in the document home.

10. Record any decision that arose during the build. Implementation teaches things, and those belong in the log while they are fresh. Vocabulary gaps returned by a Builder or a Reviewer settle here too: the term goes into the glossary (`CONTEXT.md`), or the question goes into the decision log (`decisions.md`) as `open`, both in the document home, which is `<working copy>/.capstan/` unless configured otherwise.

11. When every slice is merged, reviewed and verified, checkpoint the claim, then post the gate-3 brief, naming the verified commit and `<id>`. End the run.

    ```bash
    <bin>/capstan-claim checkpoint <working copy> --owner <id> --phase build --next "<what phase 4 picks up>"
    ```

    If the run ends before that, for any reason, checkpoint before it does. This is the phase where slices sit in four states at once, and a branch alone does not say whether a slice is unreviewed, reviewed with findings outstanding, or ready to merge. The counts and the in-flight list are already in the claim; `next` carries what a count cannot, which findings are open and why.

**A slice that keeps coming back is asking a question nobody has asked yet.** The fix-dispatch count per slice lives on the claim's `fix_dispatches` line, written only by `dispatch fix`, so it survives a run boundary and no run starts it at zero. It goes up every time a finding sends a Builder task back onto a slice already built once, whether the finding came from a slice review (step 5) or a verify return (step 9). It counts dispatches to a Builder, not review returns filed: a step 5 round you verify and merge yourself without ever writing a review still counts if it sent a fix back first, and a review round that changed nothing does not.

Before sending a fix dispatch that would be the third on a slice, or any dispatch after that, ask whether that slice's design is wrong rather than its implementation. `dispatch fix` prints `design-question: fires` from the third on, so the moment is never missed, and it is asked every time it prints, not once: a question asked at three and skipped from then on is how a slice reaches nine rounds with nobody having named why. Answer it unattended, the same as any other call this phase makes without the operator, and write it to `decisions.md` in the document home every time it fires, whether or not the answer changed from the round before — a record that only appears on a changed answer looks identical to a round where nobody asked.

An answer to keep patching sends the dispatch and does not end the run. An answer that recuts or drops the slice changes the shape the operator locked at gate 2, so that answer ends the run here — before the dispatch goes out — and reports to the operator instead. A recut slice's count goes back to zero through `<bin>/capstan-claim reset <working copy> --owner <id> --slice <slice>`, with the recut recorded in `decisions.md`: it is a different slice now, and carrying the old count in would trip the question on its very first round.

**The limit.** `capstan-max-fix-dispatches`, per `## Limits` in `SKILL.md`, is the ceiling on that count. When `dispatch fix` exits 5, the count stays where it is, the finding stays open, and the run ends here: checkpoint the claim with what remains on that slice, and report to the operator which findings are outstanding, how many rounds were spent, and the design answers logged along the way. The operator raises the key, recuts the slice, or drops it. A run never resets the count to keep going, and a gate-3 brief never calls a slice done while a blocking finding on it is open.

**Done when** every slice in `plan.md` is built, reviewed, merged, and its worktree removed, `builders_in_flight` is empty, the version decision is recorded, the integration has been verified against the checks the repository declares and the commit it passed against is in the claim, every review and verify return is filed, every review and verification finding is actioned or dismissed on the record, and every slice's row in the Tracker reads `merged` or `dropped`.
