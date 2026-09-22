# Phase 2: Plan

Begin by re-reading the world, per [`SKILL.md`](SKILL.md). Then:

1. Cut the work into vertical slices per the `slicing` skill.
2. For every slice, answer "what can be demonstrated when this is done?" A slice with no answer is a layer. Recut it.
3. Write `<working copy>/.capstan/effort/plan.md`. Open with a preamble stating why the cut is this shape. Then, per slice, write these five parts:
   - **Owns**: the files this slice, and only this slice, touches.
   - **Demonstrated**: what a reader or user can observe once the slice is done.
   - **Seam**: the boundary a check observes this slice's behaviour at.
   - **Red at base**: the evidence that the seam's check failed before this slice started.
   - **Blocked by**: which other slices must land first, or nothing.

   Close with a **Graph** showing the blocking edges between slices. This graph is yours and it never leaves the effort folder.
4. Open one row per slice in the Tracker at `planned` and no merge commit recorded yet — `tracker.md` in the document home when `capstan-tracker` is unset, the board `TRACKER-GITHUB.md` describes when it names one; see `## Tracker` in `SKILL.md`. Open it now, not when the slice merges: a row that only appears on merge cannot show a slice stalled between here and there.
5. Agree each slice's seam and its red-at-base evidence here, in the plan, not during the build. The spec already states what checks the repository declares at all; the plan is where that turns into a seam and evidence per slice. A Builder handed no seam will pick one.
6. Checkpoint the claim, `<bin>/capstan-claim checkpoint <working copy> --owner <id> --phase plan --next "<what phase 3 picks up>"`, `<bin>` and `<id>` as `SKILL.md` establishes, then post the gate-2 brief, naming `<id>`. End the run.

**Done when** every slice in `plan.md` carries Owns, Demonstrated, Seam, Red at base and Blocked by, the Graph accounts for every slice, and every slice has a row in the Tracker at `planned`.
