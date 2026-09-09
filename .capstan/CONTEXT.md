---
capstan_type: glossary
---

# Context

The words this repository uses, defined once. This describes Capstan itself; it is not a template or a file the plugin reads from your project.

| Term | Means |
|---|---|
| Effort | One run of work from concept to delivery, holding one claim. Three in flight is the ceiling. |
| Gate | A point where the run *ends* and the operator decides. Three per effort. Never a pause. |
| Operator | The person at the gates. Never the crew, and never an agent. |
| Crew | The five roles: Architect, Scout, Builder, Reviewer, Courier. |
| Architect | Owns the interview, the spec, the slice graph, the decision log and the tracker. Your session, not a subagent. |
| Scout | Read-only reconnaissance. Returns cited findings and never decides. |
| Builder | Builds exactly one slice in its own worktree. Never reviews its own work. |
| Reviewer | Reviews one slice's diff without the Builder's reasoning. Reports, never fixes. |
| Courier | Packages a delivered effort, writes the knowledge-base note, which the operator commits. Never sends. |
| Knowledge base | The operator's own surface outside the working copy, holding what they know across every Project. Capstan writes one note into it per Effort and never runs git there. |
| Knowledge-base note | The one permanent note per effort the Courier writes at delivery. Written by Capstan, committed by the operator. |
| Discipline | A skill the roles pull in, as opposed to a role itself. |
| Project | The work an Effort belongs to and outlives. One Project holds many Efforts, its own Document home, and, once built, its Tracker. |
| `capstan_type` | The frontmatter property naming which durable artifact a note is: `glossary`, `decision-log`, `decision-record` or `tracker`. Prefixed per the vault-wide typing rule. |
| `capstan-document-home` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` holding the Document home: either the literal `default` or an absolute path. Unset means the `effort` skill asks once, offering the default or Setup. |
| `capstan-knowledge-base` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` holding an absolute path to the Knowledge base. Unset means there is none, and the Courier writes no note. |
| `capstan-tracker` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` naming the Tracker surface, scheme-prefixed. Unset means `tracker.md` in the Document home. |
| Document home | Where the glossary, the log and the records live, and the tracker too when its surface is `tracker.md`. Defaults to `.capstan/` in the repository; configurable to a vault so they render outside it. Never both. |
| Tracker | The surface holding slice state through to completion. Always present; the default is `tracker.md` in the Document home, and `capstan-tracker` points it elsewhere. |
| Tracker surface | Which surface holds the Tracker for a Project: `tracker.md` in the Document home by default, or a GitHub Projects board when `capstan-tracker` names one. The choice, as against the artifact. |
| Teardown | Emptying a Tracker surface after its Rows have moved to another one. Closes and removes; never deletes. |
| Conforming comment | A comment whose whole body matches the merge-commit format `TRACKER-GITHUB.md` declares. A `merged` Row's issue carries exactly one; anything else on it is ordinary discussion. |
| Restated Comment | A comment whose content is already visible in the code it sits above or beside. The thirteenth heuristic in `two-axis-review`'s smell baseline, and Capstan's own rather than Fowler's. Distinct from a Conforming comment, which is a GitHub issue comment and not code. |
| Row | One slice's entry in the Tracker, whatever surface holds it. A table row under `tracker.md`; an issue, its status value and, at merge, a comment under a board. |
| Setup | The `setup` skill. Configures where a Project's durable artifacts live, moves what is already there, and can be re-run. Operator-invoked, never part of an Effort. |
| Front door | A skill the operator invokes directly, rather than one the model reaches for. Two: `effort` starts a run, `setup` configures where its artifacts live. Neither is a Discipline. |
| Walkthrough | The one-time script that carries the operator through a manual procedure, stage by stage, capturing what comes back. Discarded with the effort's scratch once run. |
| Spike | Throwaway work that answers one question: whether something behaves right or feels right. Never merged. |
| Stage | One step of a Walkthrough, confirmed with the operator before it is authored. Counted in `TOTAL_STAGES`. |
| Namespace | The `capstan:` prefix a plugin install puts on every skill and agent. Absent under a manual install. |
| `.capstan/` | The folder holding the artifacts Capstan writes for itself: `CONTEXT.md`, `decisions.md`, `decisions/`, `tracker.md` on the default tracker surface, and the effort scratch at `effort/`. Distinct from the namespace above, which is a prefix rather than a folder. |
| Slice | A change that can be demonstrated on its own once it is done. |
| Layer | A horizontal cut that nothing can demonstrate until other cuts land. What a slice must never be. |
| Duplication | One rule written in two places, which drift apart because nothing keeps them in step. Distinct from co-location, the within-file case `writing-for-agents` names. The reason a rule gets one home and a pointer rather than a second copy. |
| Wide refactor exception | The one shape that breaks the vertical rule: a single mechanical change whose blast radius fans across the codebase, sequenced as expand, migrate, contract. Named for `slicing`'s own heading, against which "the expand-migrate-contract exception" is the same thing described by its sequence. |
| Owns | The files one slice, and only that slice, touches. Every file the change touches is owned by exactly one slice, so nothing is left for no slice to fix and no two Builders collide. |
| Demonstrated | What a reader or user can observe once a slice is done. A slice with no answer is a Layer. |
| Seam | The test boundary agreed in the plan before the build, so a Builder never picks its own. |
| Red at base | The evidence a slice's seam check failed before that slice started. Without it a criterion can pass by having always been true. |
| Blocked by | The slices that must land before this one can be built or verified. An edge that only feels tidier is not one. |
| Frontier | Every decision whose prerequisites are already settled: the questions askable now. |
| Claim | `<working copy>/.capstan/effort/CLAIM.md`. Marks an effort as held, so a second Architect stops rather than starting. |
| Verify | Running the checks the repository declares against the merged result, and reporting what they showed. Never an exit code alone. |
| Declared check | A check the repository itself declares, in a CI workflow, a task runner, a commit hook or a contributing guide. `verify` owns the order they are discovered in. A command an agent invents or runs ad hoc, a grep included, is not one. |
| Vendored | A skill taken from an upstream project under its own licence, carrying a `CREDIT.md` that states every local change and how to refresh it. A vendored file is not edited to add Capstan's own content; that content goes in a Capstan-authored file instead. |
| Axis | One of the two independent review questions: Standards (built right) and Spec (right thing). Never blended. |
| Fixed point | The commit, branch or tag a review diffs against. Supplied by whoever dispatches, never guessed. |
| `<working copy>` | The repository an effort's work lives in, established by absolute path at the Precondition and never assumed to be the session's own directory. The prefix that qualifies a scratch path, so an agent resolves it against that repository rather than wherever its session sits. |
| Fix dispatch | A task sent back on something already built once: a Builder on a slice, from a slice review or a verify return, or the Courier on the note. What the fix-dispatch count counts, rather than review returns filed. The one term; "fix round" and "fix task" mean this. |
| Run | One invocation that ends: an effort phase, bounded by the gate it ends at, or a Setup invocation. Four phases means at least four runs, and a run is never the whole effort. What "this run's first row" is counted against.  |
| Tier 2 | A full decision record in `decisions/`, earned only when a decision is hard to reverse, surprising without context, and a real trade-off. Tier 1 is the one-line log every effort writes. |
| Load point | The named moment at which a continuous discipline is invoked. Supplied because a duty true at all times attaches to no point in a run, so it never fires. |
| Glossed site | A scratch path left bare because the sentence around it already says which working copy in words. One of the four classes a path falls into, beside a bare instruction site, a folder the agent acts on, and the `.gitignore` entry that takes no prefix. |
| Live slice | A slice that can still receive a Fix dispatch: every status but `dropped`, while the effort is open. A merged slice stays live, because a verify return reopens it, and its count resumes rather than restarting. |
| Open | A log status. Raised and unsettled, with no default in force. |
| Assumed | A log status. Defaulted so work could proceed, carrying the condition that would reopen it. |
| Unformed | A log status. An area known to be unexplored, where the question itself cannot be phrased yet. Graduates into `Open` rather than being answered. |
