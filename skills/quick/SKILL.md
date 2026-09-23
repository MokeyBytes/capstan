---
name: quick
description: Run one single-slice piece of work past a single gate, for anything too small to need slicing, a Courier, or four phases.
disable-model-invocation: true
argument-hint: "what you want built, fixed, or produced — small enough for one slice"
---

# Quick

`/capstan:quick` is a third front door beside `effort` and `setup`: one gate instead of three, one slice instead of a graph, no Courier. Everything a full effort keeps around for a multi-slice run — the claim, the slice graph, the knowledge-base note, log rotation — this flow has no use for, because there is only ever one slice. A quick is two runs, not one: the first ends at the gate, the second resumes past it and carries the work to a close.

Read [`effort/SKILL.md`](../effort/SKILL.md) for the sections this flow points into rather than restates: [Precondition](../effort/SKILL.md#precondition-name-the-working-copy), [Document home](../effort/SKILL.md#document-home), [Before the first decision row](../effort/SKILL.md#before-the-first-decision-row), [Tracker](../effort/SKILL.md#tracker), [Files](../effort/SKILL.md#files), [Authority](../effort/SKILL.md#authority), and [Duties you owe](../effort/SKILL.md#duties-you-owe). Establish the working copy and the document home exactly as written there before anything else. This file only ever adds to what those sections say, with two exceptions it states plainly where they occur: step 10 runs `verify` without the claim that section assumes, and the resume below re-reads the world its own way rather than by that section's commands, which a run with no claim cannot issue.

This flow ensures `.gitignore` carries `.capstan/quick/`, the way [Files](../effort/SKILL.md#files) has `effort` ensure its own line for `.capstan/effort/`. The two scratches never share a path: a full effort's `spec.md` and a quick's concept file cannot collide, and closing one never deletes the other's state.

## New quick versus resume

Before round one, list `<working copy>/.capstan/quick/` — a missing directory reads the same as an empty one. For each folder found, read its slug's row on the Tracker: `planned` means the quick is parked at the gate, resumable; `dropped` means it is a closed record and never resumed. A folder with no matching row, or no `concept.md` inside it, is neither — leave it untouched and name it in the report as an anomaly.

An invocation carrying a new request always starts a new quick at step 1 under a new slug, and reports every parked quick it finds so the operator knows what else is waiting; a stray or dropped folder never intercepts it. A resume either names the slug it means, or carries no new request while exactly one quick is parked — either way it skips straight to step 5, the worktree not yet created. Naming a slug that is not parked, or carrying no request while none or several are parked, stops here and says what is parked and why nothing was resumed.

The operator discards a parked quick by naming its slug together with an instruction to drop it: that deletes the folder, moves its row to `dropped`, and writes a line in `decisions.md`, per `decision-record`, naming the slug and the reason. That is the only way a declined gate ever closes; nothing else removes a parked folder.

## Flow

1. **Interview, at most two rounds.** Invoke the `interview` skill. Unlike a full effort, do not run rounds until the frontier is empty — stop after round two regardless. Whatever the frontier still holds unasked at that point, file it `assumed` at its recommended answer; whatever the interview itself already parked as `open` or `unformed` stays that way. Every line goes into `decisions.md` in the document home, per `decision-record`.
2. **Escalate before writing the concept.** If the interview shows more than one slice of work, or touches anything gated under [Authority](../effort/SKILL.md#authority), stop here without writing the concept and without posting a gate. Record the reason in `decisions.md`, per `decision-record`, the same as anything else this run decides. Report it and recommend the operator run `/capstan:effort` instead: this shape of work needs the phases and the crew a quick run does not have.
3. **Write the concept.** Choose a short slug for the work, the same style a slice in `plan.md` is named. One file, `<working copy>/.capstan/quick/<slug>/concept.md` — gitignored scratch, repo-relative, never resolved against the document home. Its first line is the slug; its second is the commit `HEAD` names right now, the base commit this quick's branch, diff and verify step all measure against. After that it carries what is being built and why, what is explicitly not being built, what can be demonstrated once it is done, and the seam the Builder tests at. This is the only planning document a quick run produces: one slice needs no graph beside it, so there is no `plan.md`.
4. **Post the gate and stop.** One gate, per the `brief` skill's gate-1 shape, naming the slug. Write the tracker row now, per [Tracker](../effort/SKILL.md#tracker) for which surface holds it: effort and slice both the slug, status `planned`. Post the brief, then end the turn — the same mechanic as each of `effort`'s three gates, per [Three gates](../effort/SKILL.md#three-gates). The operator resumes by invoking `/capstan:quick` again.
5. **On resume, re-read then create the worktree.** `<base>` is `concept.md`'s second line. Check what moved since it was written:

   ```bash
   git -C <working copy> log --oneline <base>..HEAD
   git -C <working copy> status --short
   ```

   If `HEAD` has moved, read what landed before going further — something may already have changed underneath this concept. Then create one worktree, by absolute path, outside the repository tree, its branch pinned at that same base commit so nothing landing in between can enter this quick's diff:

   ```bash
   git -C <working copy> worktree add -q <worktrees-dir>/quick-<slug> -b quick/<slug> <base>
   ```

6. **Dispatch one Builder.** Move the tracker row to `building` now. Spawn it as `capstan:builder` under a plugin install, `builder` under a manual one. Hand it, by absolute path: the working copy, the worktree it is to work in, the resolved document home, and `concept.md` in the main working copy — never inside its worktree, which does not carry the gitignored scratch. Say plainly that `concept.md` is the whole spec side, that there is no `plan.md`, and that anything under `.capstan/effort/` belongs to a different effort, if one is running beside this quick, and is not to be read. It works test-first, per `test-first`, against the seam the concept names.
7. **Dispatch one Reviewer.** Never the Builder instance. Spawn it as `capstan:reviewer` under a plugin install, `reviewer` under a manual one. Hand it, by absolute path: the diff — the slice's branch against the base commit `concept.md` names — the concept file, and the resolved document home. `concept.md` is the whole spec side here, and anything under `.capstan/effort/` belongs to a different effort and is not to be read. Two-axis, per `two-axis-review`.
8. **At most 2 fix dispatches.** A blocking or worth-doing finding goes back as a new Builder task on the same branch, never to the Reviewer instance that found it and never to the Builder instance that built it. Every fix dispatch's return goes to a fresh Reviewer, the same two-axis pass as step 7. Every finding is actioned or dismissed with the reason in `decisions.md`, per `decision-record`, never left unresolved on the page. A finding still open after the second fix dispatch's review, or a check that comes back red after it (see step 10), stops the run here: report what is outstanding and recommend `/capstan:effort` to carry it further. A run never keeps patching past 2 dispatches.
9. **Merge, then remove the worktree.**

   ```bash
   git -C <working copy> worktree remove <worktrees-dir>/quick-<slug>
   ```

   A merge that conflicts follows `resolving-merge-conflicts`, the same discipline a full effort uses. Move the tracker row to `merged`, carrying the merge commit.
10. **Verify.** Run the `verify` discipline against the integration branch. This run holds no claim, so there is no recorded baseline to read: the baseline is the base commit `concept.md` names, and the verified commit goes into the closing brief rather than into a claim record nothing here keeps. A red check here is a fix dispatch counted against the cap in step 8, not a free pass around it: recreate the worktree on the existing branch, with no `-b`,

    ```bash
    git -C <working copy> worktree add -q <worktrees-dir>/quick-<slug> quick/<slug>
    ```

    then repeat steps 7, 9 and 10 — review, merge, verify — against the fix.
11. **Post the closing brief and clean up.** Per `brief`'s gate-3 shape, naming the merge commit, the verified commit, and the tracker row's final state. Delete `<working copy>/.capstan/quick/<slug>/` — gitignored scratch, and nothing else in `.capstan/` is touched. Done — nothing resumes after this one.

**Done when:**
- **the first run ends at the gate:** the concept is written and the gate-1 brief is posted;
- **it escalates:** the reason is reported and the decision row is written;
- **it stops after dispatch:** per [Stopping after dispatch](#stopping-after-dispatch), covering the fix-dispatch cap along with every other case there;
- **it completes:** the slice is merged, its worktree removed, `verify` has been observed rather than assumed, the tracker row reads `merged`, every review and verify finding is actioned or dismissed on the record, the concept folder is gone, and the closing brief is posted.

## Stopping after dispatch

Once step 5 has created a worktree, a stop before merge is never silent. A Builder that finds the slice is wrong, or hits anything [Authority](../effort/SKILL.md#authority) gates, has no second gate to escalate to the way a full effort's Builder does — so any such stop, and any stop from here through step 9 for another reason, including the fix-dispatch cap, ends the run the same way: report the worktree's absolute path, the branch, and the tracker row; move that row to `dropped`; and write a line in `decisions.md`, per `decision-record`, naming the worktree, the branch and the row, so the next thing to touch this repository — another quick, a full effort, the operator by hand — finds them named rather than mysterious. The concept folder is left in place as part of that record; it is deleted only at the close, step 11, or at an explicit discard per [New quick versus resume](#new-quick-versus-resume).

After merge, the only stop left is a red check at step 10, and it works differently: the merge already shipped, so the row stays `merged` with its commit, and the run reports the red check rather than dropping anything. A fix for it follows step 10's own recipe, not this section's.

## Kept from `effort`

- No `git stash` and no branch switching in the main working copy, ever, for the same reason `agents/builder.md` bans both inside a worktree: a shared stash ref and a shared branch are exactly what a second run in flight would collide on.

## What this flow never does

No Courier: the closing brief is the only packaging this work gets.
