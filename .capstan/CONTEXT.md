---
capstan_type: glossary
---

# Context

The words this repository uses, defined once. This describes Capstan itself; it is not a template or a file the plugin reads from your project.

| Term | Means |
|---|---|
| Effort | One piece of work from concept to delivery, spread across at least four Runs and holding one claim. Three in flight is the ceiling. |
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
| `capstan_type` | The frontmatter property naming which durable artifact a note is: `glossary`, `decision-log`, `decision-archive`, `decision-record` or `tracker`. Prefixed per the vault-wide typing rule. |
| `capstan-document-home` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` holding the Document home: either the literal `default` or an absolute path. Unset means the `effort` skill asks once, offering the default or Setup. |
| `capstan-knowledge-base` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` holding an absolute path to the Knowledge base. Unset means there is none, and the Courier writes no note. |
| `capstan-tracker` | The key in `<working copy>/CLAUDE.md` or `AGENTS.md` naming the Tracker surface, scheme-prefixed. Unset means `tracker.md` in the Document home. |
| Document home | Where the glossary, the log and the records live, and the tracker too when its surface is `tracker.md`. Defaults to `.capstan/` in the repository; configurable to a vault so they render outside it. Never both. |
| Tracker | The surface holding slice state through to completion. Always present; the default is `tracker.md` in the Document home, and `capstan-tracker` points it elsewhere. |
| Tracker surface | Which surface holds the Tracker for a Project: `tracker.md` in the Document home by default, or a GitHub Projects board when `capstan-tracker` names one. The choice, as against the artifact. |
| Teardown | Emptying a Tracker surface after its Rows have moved to another one. Closes issues and removes items; removing an item is a delete, so the operator approves it. |
| Conforming comment | A comment whose whole body matches the merge-commit format the `capstan-board` plugin's `tracker` skill declares. A `merged` Row's issue carries exactly one; anything else on it is ordinary discussion. |
| Restated Comment | A comment whose content is already visible in the code it sits above or beside. The thirteenth heuristic in `two-axis-review`'s smell baseline, and Capstan's own rather than Fowler's. Distinct from a Conforming comment, which is a GitHub issue comment and not code. |
| Row | One slice's entry in the Tracker, whatever surface holds it. A table row under `tracker.md`; an issue, its status value and, at merge, a comment under a board. |
| Setup | The `setup` skill. Configures where a Project's durable artifacts live, moves what is already there, and can be re-run. The Tracker surface is configured separately, by `capstan-board`'s own `setup`. Operator-invoked, never part of an Effort. |
| Agent override | A file in the working copy's `.claude/agents/`, named for a crew role and marked by its header as a Capstan override, naming the plugin version its body was copied from. Spawned by its unscoped name, without the Namespace, in place of `capstan:<role>`. Written by `agent-models`, never by hand-editing the plugin. |
| Front door | A skill the operator invokes directly, rather than one the model reaches for. Three: `effort` starts a run, `quick` runs single-slice work through one gate, `setup` configures where its artifacts live. The `capstan-board` plugin adds a fourth, its own `setup`, for the Tracker surface. None is a Discipline. |
| Walkthrough | The one-time script that carries the operator through a manual procedure, stage by stage, capturing what comes back. Discarded with the effort's scratch once run. |
| Spike | Throwaway work that answers one question: whether something behaves right or feels right. Never merged. |
| Stage | One step of a Walkthrough, confirmed with the operator before it is authored. Counted in `TOTAL_STAGES`. |
| Namespace | The `capstan:` prefix a plugin install puts on every skill and agent, and `capstan-board:` on the board plugin's. Absent under a manual install. |
| `.capstan/` | The folder holding the artifacts Capstan writes for itself: `CONTEXT.md`, `decisions.md`, `decisions/`, `tracker.md` on the default tracker surface, the effort scratch at `effort/`, and a Quick's scratch at `quick/<slug>/`. Distinct from the namespace above, which is a prefix rather than a folder. |
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
| Claim | Holding an Effort: the Lock that enforces it and the Claim record beside it, `<working copy>/.capstan/effort/CLAIM.md`, that explains it. Taken, resumed, released and taken over through `capstan-claim`, never by hand. |
| Lock | `<working copy>/.capstan/effort/.claim.lock/`, a directory taken with `mkdir` so exactly one session holds an Effort. Carries the Owner id. Enforcement, not a record. |
| Owner id | The string naming who holds a Claim, printed by `acquire` and presented on every later write. Carried between runs in the gate briefs. Age never stands in for it. |
| Takeover | Replacing a Lock's Owner id while naming the current one exactly. The operator's call; never authorised by a timestamp. |
| Base commit | `base_commit` in the Claim record: the commit the Effort started from, written once at acquire and never moved. The baseline `verify` classifies a red check against. Unknown on an adopted older claim, and reported as degraded rather than invented. |
| Checkpoint | `last_observed_head` in the Claim record: the commit the last run checked the repository against, moved at every gate. What re-reading the world diffs from. Never the Base commit. |
| Verified commit | `verified_commit` in the Claim record: the commit the integration's checks last passed against. What the gate-3 brief names and what phase 4 checks `HEAD` against before anything ships. |
| Drift | A change to the repository outside the Document home since the Verified commit, committed or not. Invalidates the verification; a change confined to the Document home does not. |
| Builder limit | `capstan-max-builders`, default 3: Builders in flight at once inside one Effort. Enforced by `capstan-claim dispatch` from `builders_in_flight` in the Claim record. |
| Fix-dispatch limit | `capstan-max-fix-dispatches`, default 5: Fix dispatches on one slice, or on the note, across every run of an Effort. Reaching it refuses the dispatch, keeps the count, and ends the run reporting what remains. |
| Helper | One of the executables admitted per 0004: `capstan-claim`, `capstan-scratch-clean` and `capstan-log` in core's `skills/effort/bin/`, and `capstan-tracker` in the `capstan-board` plugin's `tracker` skill. Does one deterministic thing when a skill calls it; judgement stays in the skill. |
| Active log | `decisions.md` in the Document home: every `open`, `assumed` and `unformed` row plus the newest rows, the one file read whole before an effort. |
| Archive | The files under `decisions/archive/` holding rows rotated out of the Active log. Append-only: a row there is never edited, its status included. Read by grep, not whole. |
| Rotate | Moving rows from the Active log into a new Archive file with `capstan-log rotate`, at delivery, when the Active log passes its threshold. |
| Quick | One single-slice piece of work run through `/capstan:quick`: two runs and one gate, no claim, one Tracker row. Not an Effort, and not counted against the three-effort ceiling. A `merged` Quick row is final. |
| Sync copy | A duplicate a sync service leaves beside the scratch, `effort 2`, `effort 3`, and so on. The only names `capstan-scratch-clean` deletes beside `effort` itself. |
| Verify | Running the checks the repository declares against the merged result, and reporting what they showed. Never an exit code alone. |
| Declared check | A check the repository itself declares, in a CI workflow, a task runner, a commit hook or a contributing guide. `verify` owns the order they are discovered in. A command an agent invents or runs ad hoc, a grep included, is not one. |
| Vendored | A skill taken from an upstream project under its own licence, carrying a `CREDIT.md` that states every local change and how to refresh it. A vendored file is not edited to add Capstan's own content; that content goes in a Capstan-authored file instead. `walkthrough`'s library is the declared exception, forked per 0005 with its changes listed and tested. |
| Axis | One of the two independent review questions: Standards (built right) and Spec (right thing). Never blended. |
| Fixed point | The commit, branch or tag a review diffs against. Supplied by whoever dispatches, never guessed. |
| `<working copy>` | The repository an effort's work lives in, established by absolute path at the Precondition and never assumed to be the session's own directory. The prefix that qualifies a scratch path, so an agent resolves it against that repository rather than wherever its session sits. |
| Fix dispatch | A task sent back on something already built once: a Builder on a slice, from a slice review or a verify return, or the Courier on the note. What the fix-dispatch count counts, rather than review returns filed. The one term; "fix round" and "fix task" mean this. |
| Run | One invocation that ends: an effort phase, bounded by the gate it ends at, a Setup invocation, or one of a Quick's two invocations. Four phases means at least four runs, and a run is never the whole effort. What "this run's first row" is counted against.  |
| Tier 2 | A full decision record in `decisions/`, earned only when a decision is hard to reverse, surprising without context, and a real trade-off. Tier 1 is the one-line log every effort writes. |
| Load point | The named moment at which a continuous discipline is invoked. Supplied because a duty true at all times attaches to no point in a run, so it never fires. |
| Glossed site | A scratch path left bare because the sentence around it already says which working copy in words. One of the four classes a path falls into, beside a bare instruction site, a folder the agent acts on, and the `.gitignore` entry that takes no prefix. |
| Live slice | A slice that can still receive a Fix dispatch: every status but `dropped`, while the effort is open. A merged slice stays live, because a verify return reopens it, and its count resumes rather than restarting. |
| Open | A log status. Raised and unsettled, with no default in force. |
| Assumed | A log status. Defaulted so work could proceed, carrying the condition that would reopen it. |
| Unformed | A log status. An area known to be unexplored, where the question itself cannot be phrased yet. Graduates into `Open` rather than being answered. |
