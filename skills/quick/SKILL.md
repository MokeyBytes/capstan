---
name: quick
description: Run one single-slice piece of work past a single gate, for anything too small to need slicing, a Courier, or four phases.
disable-model-invocation: true
argument-hint: "what you want built, fixed, or produced — small enough for one slice"
---

# Quick

`/capstan:quick` is a third front door beside `effort` and `setup`: one gate instead of three, one slice instead of a graph, no Courier. Everything a full effort keeps around for a multi-slice run — the claim, the slice graph, the knowledge-base note, log rotation — this flow has no use for, because there is only ever one slice and one session sees it through.

Read [`effort/SKILL.md`](../effort/SKILL.md) for the sections this flow points into rather than restates: [Precondition](../effort/SKILL.md#precondition-name-the-working-copy), [Document home](../effort/SKILL.md#document-home), [Tracker](../effort/SKILL.md#tracker), [Authority](../effort/SKILL.md#authority), and [Duties you owe](../effort/SKILL.md#duties-you-owe). Establish the working copy and the document home exactly as written there before anything else. This file only ever adds to what those sections say; it never contradicts them.

## Flow

1. **Interview, at most two rounds.** Invoke the `interview` skill. Unlike a full effort, do not run rounds until the frontier is empty — stop after round two regardless. Whatever is still `open`, `assumed` or `unformed` at that point goes into `decisions.md` in the document home the same way the interview skill already files it, per `decision-record`.

2. **Escalate before writing anything down.** If the interview shows more than one slice of work, or touches anything the Authority table above gates — a secret, a third party, money, an infrastructure change, anything hard to reverse — stop here. Write no concept, post no gate. Report the reason and recommend the operator run `/capstan:effort` instead: this shape of work needs the phases and the crew a quick run does not have.

3. **Write the concept.** One file, `<working copy>/.capstan/effort/spec.md` — the same gitignored, repo-relative scratch path a full effort uses, not resolved against the document home. It carries what is being built and why, what is explicitly not being built, what can be demonstrated once it is done, and the seam the Builder tests at. This is the only planning document a quick run produces: one slice needs no graph beside it, so there is no `plan.md`.

4. **Post the gate and stop.** One gate, per the `brief` skill's gate-1 shape: what is being built, why, what is explicitly not, the assumptions section, the open-questions section. Post it, then end the turn. This is exactly how each of `effort`'s three gates ends its own run: there is no poller and no scheduler, and the gate is enforced by the run being over, not by anything waiting on an answer. The operator resumes by invoking `/capstan:quick` again.

5. **On resume, create one worktree.** By absolute path, outside the repository tree:

   ```bash
   git -C <working copy> worktree add -q <worktrees-dir>/quick-<slug> -b quick/<slug>
   ```

   Write the tracker row now, per [Tracker](../effort/SKILL.md#tracker) above for which surface holds it: effort and slice both `<slug>`, status `planned`.

6. **Dispatch one Builder.** Spawn it as `capstan:builder` under a plugin install, `builder` under a manual one. Hand it, by absolute path: the working copy, the worktree it is to work in, the resolved document home, and `.capstan/effort/spec.md` in the main working copy — never inside its worktree, which does not carry the gitignored scratch. It works test-first, per `test-first`, against the seam `spec.md` names.

7. **Dispatch one Reviewer.** Never the Builder instance. Spawn it as `capstan:reviewer` under a plugin install, `reviewer` under a manual one. Hand it only the diff — the slice's branch against the commit it started from — and `spec.md`. Two-axis, per `two-axis-review`.

8. **At most 2 fix rounds, counted in prose.** A blocking or worth-doing finding goes back as a new Builder task on the same branch, never to the Reviewer instance that found it and never to the Builder instance that built it. A third finding worth fixing — on the round that would be the third dispatch — stops the run here instead of sending it: report what is outstanding and recommend `/capstan:effort` to carry it further. A run never keeps patching past 2 rounds.

9. **Merge, then remove the worktree.**

   ```bash
   git -C <working copy> worktree remove <worktrees-dir>/quick-<slug>
   ```

   Move the tracker row to `merged`, carrying the merge commit.

10. **Verify.** Run the `verify` discipline against the integration branch, the same as a full effort's phase 3 step 9.

11. **Post the closing brief.** What was built, in behaviour. What review found on each axis and what was done about it. What verify showed. The merge commit and the tracker row. Done — nothing resumes after this one.

## Kept from `effort`

- The [Authority](../effort/SKILL.md#authority) table and stop-for-consequence, unchanged. Uncertainty is still never a reason to stop; only consequence is.
- [Precondition](../effort/SKILL.md#precondition-name-the-working-copy) and [Document home](../effort/SKILL.md#document-home) resolution, unchanged.
- No `git stash` and no branch switching in the main working copy, ever, for the same reason `agents/builder.md` bans both inside a worktree: a shared stash ref and a shared branch are exactly what a second run in flight would collide on.
- A line in `decisions.md`, per `decision-record`, for anything this run decides — the escalation call included, when it fires.

## What this flow never does

No lock and no claim record: one run either finishes at the gate or resumes past it, and nothing here needs to survive a crash the way a multi-week effort does. No `slicing` skill: a single slice needs no graph, no blocking edges, and no frontier of parallel Builders. No Courier: the closing brief is the only packaging this work gets. No knowledge-base note: nothing here outlives the tracker row and whatever landed in `decisions.md`. No log rotation: that belongs to phase 4 of a full effort, never to this one.
