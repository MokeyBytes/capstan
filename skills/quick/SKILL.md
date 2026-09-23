---
name: quick
description: Run one single-slice piece of work past a single gate, for anything too small to need slicing, a Courier, or four phases.
disable-model-invocation: true
argument-hint: "what you want built, fixed, or produced — small enough for one slice"
---

# Quick

`/capstan:quick` is a third front door beside `effort` and `setup`: one gate instead of three, one slice instead of a graph, no Courier. Everything a full effort keeps around for a multi-slice run — the claim, the slice graph, the knowledge-base note, log rotation — this flow has no use for, because there is only ever one slice. A quick is two runs, not one: the first ends at the gate, the second resumes past it and carries the work to a close.

Read [`effort/SKILL.md`](../effort/SKILL.md) for the sections this flow points into rather than restates: [Precondition](../effort/SKILL.md#precondition-name-the-working-copy), [Document home](../effort/SKILL.md#document-home), [Every phase begins by re-reading the world](../effort/SKILL.md#every-phase-begins-by-re-reading-the-world) (the second run opens with it), [Before the first decision row](../effort/SKILL.md#before-the-first-decision-row), [Tracker](../effort/SKILL.md#tracker), [Files](../effort/SKILL.md#files), [Authority](../effort/SKILL.md#authority), and [Duties you owe](../effort/SKILL.md#duties-you-owe). Establish the working copy and the document home exactly as written there before anything else. This file only ever adds to what those sections say; it never contradicts them.

This flow ensures `.gitignore` carries `.capstan/quick/`, the way [Files](../effort/SKILL.md#files) has `effort` ensure its own line for `.capstan/effort/`. The two scratches never share a path: a full effort's `spec.md` and a quick's concept file cannot collide, and closing one never deletes the other's state.

## Flow

Before round one, list `<working copy>/.capstan/quick/`. **Empty** means this is the first run: continue at step 1. **One folder holding a `concept.md`** means this is the second run, a resume: read it whole, re-read the world by the pointer above, confirm it is the concept the gate approved, then skip to step 5. **More than one** — report every folder found and ask the operator which slug this resumes; quick holds no lock to settle that on its own.

1. **Interview, at most two rounds.** Invoke the `interview` skill. Unlike a full effort, do not run rounds until the frontier is empty — stop after round two regardless. Whatever the frontier still holds unasked at that point, file it `assumed` at its recommended answer; whatever the interview itself already parked as `open` or `unformed` stays that way. Every line goes into `decisions.md` in the document home, per `decision-record`.
2. **Escalate before writing the concept.** If the interview shows more than one slice of work, or touches anything gated under [Authority](../effort/SKILL.md#authority), stop here without writing the concept and without posting a gate. Record the reason in `decisions.md`, per `decision-record`, the same as anything else this run decides. Report it and recommend the operator run `/capstan:effort` instead: this shape of work needs the phases and the crew a quick run does not have.
3. **Write the concept.** Choose a short slug for the work, the same style a slice in `plan.md` is named. One file, `<working copy>/.capstan/quick/<slug>/concept.md` — gitignored scratch, repo-relative, never resolved against the document home. Its first line is the slug; its second is the commit `HEAD` names right now, the base commit this quick's diff and its own verify step will both measure against. After that it carries what is being built and why, what is explicitly not being built, what can be demonstrated once it is done, and the seam the Builder tests at. This is the only planning document a quick run produces: one slice needs no graph beside it, so there is no `plan.md`.
4. **Post the gate and stop.** One gate, per the `brief` skill's gate-1 shape, naming the slug. Write the tracker row now, per [Tracker](../effort/SKILL.md#tracker) for which surface holds it: effort and slice both the slug, status `planned`. Post the brief, then end the turn — the same mechanic as each of `effort`'s three gates, per [Three gates](../effort/SKILL.md#three-gates). The operator resumes by invoking `/capstan:quick` again.
5. **On resume, create one worktree.** By absolute path, outside the repository tree:

   ```bash
   git -C <working copy> worktree add -q <worktrees-dir>/quick-<slug> -b quick/<slug>
   ```

6. **Dispatch one Builder.** Move the tracker row to `building` now. Spawn it as `capstan:builder` under a plugin install, `builder` under a manual one. Hand it, by absolute path: the working copy, the worktree it is to work in, the resolved document home, and `concept.md` in the main working copy — never inside its worktree, which does not carry the gitignored scratch. Say plainly that there is no `plan.md`: the concept file carries the slice and the seam a full effort's plan would otherwise supply. It works test-first, per `test-first`, against the seam the concept names.
7. **Dispatch one Reviewer.** Never the Builder instance. Spawn it as `capstan:reviewer` under a plugin install, `reviewer` under a manual one. Hand it, by absolute path: the diff — the slice's branch against the base commit `concept.md` names — the concept file, and the resolved document home. No Builder context goes with it, which is what "only the diff and the concept" means; it is not a ban on the document home a Reviewer needs to grade Standards at all. Two-axis, per `two-axis-review`.
8. **At most 2 fix dispatches.** A blocking or worth-doing finding goes back as a new Builder task on the same branch, never to the Reviewer instance that found it and never to the Builder instance that built it. Every fix dispatch's return goes to a fresh Reviewer, the same two-axis pass as step 7. Every finding is actioned or dismissed with the reason in `decisions.md`, per `decision-record`, never left unresolved on the page. A finding still open after the second fix dispatch's review, or a check that comes back red after it (see step 10), stops the run here: report what is outstanding and recommend `/capstan:effort` to carry it further. A run never keeps patching past 2 dispatches.
9. **Merge, then remove the worktree.**

   ```bash
   git -C <working copy> worktree remove <worktrees-dir>/quick-<slug>
   ```

   A merge that conflicts follows `resolving-merge-conflicts`, the same discipline a full effort uses. Move the tracker row to `merged`, carrying the merge commit.
10. **Verify.** Run the `verify` discipline against the integration branch. This run holds no claim, so there is no recorded baseline to read: the baseline is the base commit `concept.md` names, and the verified commit goes into the closing brief rather than into a claim record nothing here keeps. A red check here is a fix dispatch counted against the cap in step 8, not a free pass around it.
11. **Post the closing brief and clean up.** Per `brief`'s gate-3 shape, naming the merge commit and the tracker row's final state. Delete `<working copy>/.capstan/quick/<slug>/` — gitignored scratch, and nothing else in `.capstan/` is touched. Done — nothing resumes after this one.

**Done when:**
- **the first run ends at the gate:** the concept is written and the gate-1 brief is posted;
- **it escalates:** the reason is reported and the decision row is written;
- **a fix dispatch hits the cap:** the outstanding findings are reported and `/capstan:effort` is recommended;
- **it completes:** the slice is merged, its worktree removed, `verify` has been observed rather than assumed, the tracker row reads `merged`, every review and verify finding is actioned or dismissed on the record, the concept folder is gone, and the closing brief is posted.

## Stopping after dispatch

Once step 5 has created a worktree, a stop is never silent. A Builder that finds the slice is wrong, or hits anything [Authority](../effort/SKILL.md#authority) gates, has no second gate to escalate to the way a full effort's Builder does — so any such stop, and any stop from here through step 10 for another reason, ends the run the same way: report the worktree's absolute path, the branch, and the tracker row; move that row to `dropped`; and write a line in `decisions.md`, per `decision-record`, naming the worktree, the branch and the row, so the next thing to touch this repository — another quick, a full effort, the operator by hand — finds them named rather than mysterious. The concept folder is left in place as part of that record; it is deleted only at the close, step 11.

## Kept from `effort`

- The [Authority](../effort/SKILL.md#authority) table and stop-for-consequence, unchanged. Uncertainty is still never a reason to stop; only consequence is.
- [Precondition](../effort/SKILL.md#precondition-name-the-working-copy) and [Document home](../effort/SKILL.md#document-home) resolution, unchanged.
- No `git stash` and no branch switching in the main working copy, ever, for the same reason `agents/builder.md` bans both inside a worktree: a shared stash ref and a shared branch are exactly what a second run in flight would collide on.
- A line in `decisions.md`, per `decision-record`, for anything this run decides — the escalation call included, when it fires.

## What this flow never does

No lock: the first run either ends at the gate or escalates away from it; the second either resumes past the gate to a close or stops per [Stopping after dispatch](#stopping-after-dispatch) above. Nothing here needs to survive a crash the way a multi-week effort does. No `slicing` skill: a single slice needs no graph, no blocking edges, and no frontier of parallel Builders. No Courier: the closing brief is the only packaging this work gets. No knowledge-base note: nothing here outlives the tracker row and whatever landed in `decisions.md`. No log rotation: that belongs to phase 4 of a full effort, never to this one.
