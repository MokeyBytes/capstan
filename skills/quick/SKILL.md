---
name: quick
description: Run one single-slice piece of work past a single gate, for anything too small to need slicing, a Courier, or four phases.
disable-model-invocation: true
argument-hint: "what you want built, fixed, or produced — small enough for one slice — or 'resume [gate answer]' / 'discard <slug>' for the one parked quick"
---

# Quick

`/capstan:quick` is a third front door beside `effort` and `setup`: one gate, one slice, no Courier. A full effort's claim, slice graph, knowledge-base note and log rotation have no use here — there is only ever one slice. A quick is two runs: the first ends at the gate, the second resumes past it to a close.

Read [`effort/SKILL.md`](../effort/SKILL.md) for the sections this flow points into rather than restates: [Precondition](../effort/SKILL.md#precondition-name-the-working-copy), [Document home](../effort/SKILL.md#document-home), [Before the first decision row](../effort/SKILL.md#before-the-first-decision-row), [Tracker](../effort/SKILL.md#tracker), [Files](../effort/SKILL.md#files), [Authority](../effort/SKILL.md#authority), and [Duties you owe](../effort/SKILL.md#duties-you-owe). Establish the working copy and the document home exactly as written there before anything else. This file only ever adds to what those sections say.

This flow ensures `.gitignore` carries `.capstan/quick/`, the way [Files](../effort/SKILL.md#files) has `effort` ensure its own line for `.capstan/effort/`. The two scratches never share a path: a full effort's `spec.md` and a quick's concept file cannot collide, and closing one never deletes the other's state.

## Lifecycle

`<working copy>/.capstan/quick/` holds at most one folder — a missing directory reads as empty. Its Tracker row is looked up by effort and slice both equal to the slug, never slug alone, per `TRACKER-GITHUB.md`'s rule for a full effort's rows.

**Reading the argument.** A folder whose row is not `planned` is settled by its table row before the argument is read.

It keys on its leading word: `resume` (or a bare invocation with one quick parked) resumes at step 5, its trailing text recorded per `decision-record` as the operator's gate answer. `discard <slug>` drops the parked quick: row `dropped`, a decision line naming slug and reason, the folder deleted last — it also applies to a `none` or `building` folder, never to a `merged` one. Anything else is a new request, starting fresh at step 1.

`resume` or `discard` with nothing parked, or a `resume` whose answer changes what gets built, stops: it says why, changes nothing, and prints only the forms that apply to the row it found. So does a request while any folder exists, naming the row whatever it says:

```
/capstan:quick resume
/capstan:quick discard <slug>
```

| Row status | On the next invocation | Exit |
|---|---|---|
| none | Folder present: a first run died before its gate — report it, offer the discard above. No folder: step 1 begins, under a checked slug. | `dropped`, escalates, or reaches the gate and becomes `planned`. |
| `planned` | Parked; resumed or discarded per **Reading the argument**. | `merged`, `dropped`, or stays `planned` on a step-5 conflict. |
| `building` | Merged only when `test "$(git -C <working copy> rev-parse quick/<slug>)" != "<concept.md's third line>" && git -C <working copy> merge-base --is-ancestor quick/<slug> HEAD` succeeds: treat as `merged` below, finishing whatever step 9 left undone. Otherwise report the worktree, branch and row, and offer the discard above, extended to remove the worktree first. | `merged` or `dropped`. |
| `merged` | Folder gone: closed, a red verify caught after merge stays here — step 10. Folder present: whatever step 9 left undone finishes — the worktree removal — before steps 10–11 run, with `concept.md`'s third line as baseline. | Final. |
| `dropped` | Closed; folder already gone. Nothing resumes it. | Final. |

## Flow

1. **Interview, at most two rounds.** Invoke `interview`, stopping after round two regardless of the frontier. What it still holds unasked is filed `assumed` at its recommended answer; what the interview itself filed `open` or `unformed` stays so. Every line goes into `decisions.md`, per `decision-record`.
2. **Escalate before writing the concept.** More than one slice of work, or anything [Authority](../effort/SKILL.md#authority) gates, stops here before the concept or a gate. Record the reason per `decision-record`, report it, and recommend `/capstan:effort`: this needs the phases and crew a quick run lacks.
3. **Write the concept.** A short slug, checked against every existing row, `quick/` branch and folder, in `plan.md`'s slice-naming style. One file, `<working copy>/.capstan/quick/<slug>/concept.md` — gitignored, repo-relative, never resolved against the document home. First line the slug, second the commit `HEAD` names now, re-read at resume, third, blank until step 5 fills it. Then: what is built and why, what is not, what shows it is done, and the Builder's seam. The only planning document a quick produces — no graph needed for one slice, so no `plan.md`.
4. **Post the gate and stop.** One gate, per `brief`'s gate-1 shape, naming the slug and printing the resume and discard forms verbatim. Write the Tracker row: effort and slice both the slug, status `planned`. Post it, then end the turn, per [Three gates](../effort/SKILL.md#three-gates).
5. **On resume, re-read, then create the worktree.** `<gate commit>` is `concept.md`'s second line.

   ```bash
   git -C <working copy> log --oneline <gate commit>..HEAD
   git -C <working copy> status --short
   ```

   Nothing touching the concept's work: move the row to `building`, write `HEAD` as `concept.md`'s third line, then branch from it now, by absolute path, outside the repository tree. That commit is the Reviewer's fixed point in step 7 and `verify`'s baseline in step 10.

   ```bash
   git -C <working copy> worktree add -q <worktrees-dir>/quick-<slug> -b quick/<slug> HEAD
   ```

   Something that already does the concept's work, or conflicts with it: stop instead, printing the resume and discard forms and reporting what moved. The quick stays `planned`; a later `resume` proceeds once its answer accepts what moved.
6. **Dispatch one Builder.** Spawn `capstan:builder` (plugin) or `builder` (manual), handing it by absolute path: the working copy, its worktree, the document home, and `concept.md` from the main working copy — never from inside the worktree, which lacks gitignored scratch. Every dispatch in this run reads the spec side only from `concept.md`: no `plan.md`, and any `.capstan/effort/` beside this quick belongs to a different effort, unread. Test-first, per `test-first`, against the concept's seam.
7. **Dispatch one Reviewer.** Never the Builder instance. Spawn `capstan:reviewer` (plugin) or `reviewer` (manual). Hand it, by absolute path: the diff — branch against the commit step 5 branched from — the concept file, and the document home. Two-axis, per `two-axis-review`.
8. **At most 2 fix dispatches.** A blocking or worth-doing finding is a new Builder task on the same branch, never to the Reviewer that found it or the Builder that built it. Every fix return goes to a fresh Reviewer, the same two-axis pass, and every finding is actioned or dismissed with its reason in `decisions.md`, per `decision-record`. A finding still open after the second dispatch stops the run, per **Stopping before merge**.
9. **Merge, move the row, then remove the worktree.**

   ```bash
   git -C <working copy> merge --no-ff quick/<slug>
   ```

   A conflicting merge follows `resolving-merge-conflicts`. `--no-ff` guarantees a merge commit even on a fast-forward. Move the row to `merged`, carrying the merge commit.

   ```bash
   git -C <working copy> worktree remove <worktrees-dir>/quick-<slug>
   ```

   The branch stays, for the operator to remove; step 11 names it.
10. **Verify.** Run `verify` against the integration, baseline the commit step 5 branched from. Its verified commit goes into step 11's brief; this run holds no claim for `verify`'s claim commands to read or write. A red check does not reopen this quick: row stays `merged`, a decision line names the check and the merge commit, per `decision-record`. The fix is the next quick, under a fresh slug.
11. **Post the closing brief.** Per `brief`'s gate-3 shape, naming the merge commit, the verified commit, the row's final state, and the merged branch for the operator to remove. Delete `<working copy>/.capstan/quick/<slug>/` last. Nothing resumes after this one.

**Stopping before merge.** Any stop from step 6 through 9 — a Builder finding the slice wrong, an [Authority](../effort/SKILL.md#authority) gate, the fix-dispatch cap, an unresolved merge — ends alike: worktree removed, row moved to `dropped`, a decision line naming worktree, branch and row, the concept folder deleted last. The unmerged branch stays, for the operator to remove. Report it and recommend `/capstan:effort`.

**Done when:**
- **the first run ends at the gate:** the concept is written, its row reads `planned`, and the gate-1 brief is posted;
- **it escalates:** the reason is reported and the decision row is written;
- **a request finds a folder:** reported by slug with the forms that apply, nothing changed;
- **it is discarded, parked or crashed, or it stops before merge:** worktree (if any) and folder are gone, the row reads `dropped`, and the decision line is written, per **Stopping before merge**;
- **step 5 finds a conflict:** what moved is reported, the row stays `planned`;
- **it completes:** merged, worktree removed, `verify` observed rather than assumed, the row `merged` (with its decision line if verify came back red), every review finding actioned or dismissed on the record, the concept folder gone, the closing brief posted.

## Kept from `effort`

No `git stash` and no branch switching in the main working copy, ever, for the same reason `agents/builder.md` bans both inside a worktree: a shared stash ref and a shared branch are exactly what a second run in flight would collide on.
