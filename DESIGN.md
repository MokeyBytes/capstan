# Design

This document holds the reasoning behind Capstan's shape, and it is not needed to install or use the plugin.

No operating layer: no schemas, no hooks, no scheduler, nothing that has to run for the workflow to keep working. That is deliberate: anything that needs code to stay alive is something you will eventually maintain or abandon, and prose survives a model change in a way a validator does not. Two things look like exceptions. `walkthrough` builds a throwaway script for one run from a bash library it carries, forked and tested rather than vendored untouched since [0005](.capstan/decisions/0005-fork-the-walkthrough-library.md). And three small helpers under `skills/effort/bin/` take the effort's lock, delete its scratch, and rotate the decision log, per [0004](.capstan/decisions/0004-admit-a-thin-executable-layer.md) and the [last section here](#why-a-thin-executable-layer-exists). A fourth, `capstan-tracker`, reads a GitHub board and lives in the `capstan-board` plugin instead, on the same admission rule. None of them runs unless an agent calls it, and nothing polls, waits, or fires on its own.

## The crew

Roles are functions in a pipeline, not domains, so the same five handle a software feature, a client document, a video, or an infrastructure change.

| Role | Model | Owns | Never |
|---|---|---|---|
| **Scout** | sonnet / medium | Finding out. Primary sources, cited findings. Runs many in parallel. | Decides anything. Has no write tools at all. |
| **Architect** | your session | The interview, the spec, the slice graph, the decision log. | Builds or reviews. |
| **Builder** | sonnet / high | One vertical slice, test-first, in its own worktree. | Reviews itself. Touches a gated action. |
| **Reviewer** | opus / xhigh | Independent two-axis review of the diff. | Sees the Builder's reasoning. Fixes what it finds. |
| **Courier** | sonnet / medium | Packaging, recipient-specific briefs, the permanent record. | Sends anything. Commits the record. |

The Architect is the only role that talks to you between gates. Five roles reporting independently is five inboxes.

## Three gates

The run **stops** at each gate. There is no poller and nothing waits: the brief is posted and the run ends. You resume by invoking the next phase.

1. **Concept locked.** What we are building, why, and what we are explicitly not doing.
2. **Plan locked.** How, cut into slices, what runs parallel, what was assumed.
3. **Ready to deliver.** What was built, what review found, what goes to whom.

Gate one is the one to protect. It is where a wrong turn is cheapest to catch and the one that gets skipped.

Which is why phases 2, 3 and 4 live in their own files beside `skills/effort/SKILL.md` rather than inside it. A run genuinely ends at each gate, so that is a real context boundary, and a phase worked with the later phases sitting in view is a phase that gets rushed. Phase 1 stays in `SKILL.md`: hiding a step protects the step in front of it, not itself.

## Stop for consequence, never for ambiguity

The crew does not halt on unclear requirements. It takes the most defensible reading, writes the assumption down, and keeps moving, then surfaces every assumption at the next gate where correcting one is nearly free.

What does stop the line: secrets and credentials, anything a third party will see, anything that costs money, and anything destructive or production-facing. The one delete the crew makes on its own authority is the gitignored scratch, at delivery.

## The disciplines

The disciplines the roles pull in. Three front doors sit outside this table and are not disciplines: `effort` starts a full run, `quick` runs one slice through a single gate, and `setup` configures where the artifacts live. Only the operator invokes any of them. Three agents preload the disciplines they need via `skills:` frontmatter, so the discipline is in context before the first turn rather than hopefully invoked.

| Skill | Used by | For |
|---|---|---|
| `interview` | Architect | Rounds of questions, each carrying a recommended answer. Facts are the agent's job, decisions are yours. Questions you cannot answer get parked in the log rather than lost. |
| `spike` | Builder | A throwaway spike that settles whether something behaves right or feels right, for a design question the interview could not resolve. Never merged. |
| `slicing` | Architect | Vertical slices with real blocking edges. Includes the expand-migrate-contract exception for wide refactors. |
| `test-first` | Builder | Red, green, refactor. Tests at pre-agreed seams only. |
| `resolving-merge-conflicts` | Architect | Integrating parallel Builders. Intent comes from the plan, not from commit messages, and a conflict that can only be resolved by inventing behaviour is a slicing defect rather than a merge to force. Vendored from Matt Pocock. |
| `diagnosing-bugs` | Builder | A feedback loop that goes red on the bug before any hypothesis. Owns a bug slice up to the fix, where `test-first` takes over. Vendored from Matt Pocock. |
| `walkthrough` | Architect | The one-time script for a human task step, stage by stage, confirming each and capturing what comes back. Vendors Matt Pocock's `wizard` library rather than reimplementing it. |
| `decision-record` | Architect, Courier | A one-line log by default, a full record only when it earns one, superseded rather than edited. Owns the glossary, the one artifact edited in place. |
| `brief` | Architect, Courier | BLUF checkpoint briefs, and partner briefs generated per recipient rather than maintained. |
| `to-questionnaire` | Architect | The other direction: open questions out to whoever holds the answers, aimed at the gap between what they know and what the effort needs. Vendored from Matt Pocock. |
| `two-axis-review` | Builder, Reviewer | Standards and spec, answered independently, never blended into one verdict. |
| `verify` | Architect | Runs the checks the repository declares against the merged result. A Reviewer reads a diff and skips what a typechecker would catch, on the grounds that CI catches it. This is that CI. |
| `codebase-design` | Builder, Reviewer | The words for structure: module, interface, depth, seam, adapter, leverage, locality. Supplies them while building, and gives the standards axis something to judge interface shape against. Vendored from Matt Pocock, see [0003](.capstan/decisions/0003-adopt-deep-modules-as-the-design-standard.md). |
| `unslop` | Anything writing prose | Cuts AI tells from writing a person will read. |
| `writing-for-agents` | You, editing this repo | The levers that make a document an agent consumes behave the same way every run. |

## Two kinds of prose

Writing for a person and writing for an agent want opposite things, and one rule for both produces bad versions of each. A brief wants voice, rhythm, and an opinion. A `SKILL.md` wants none of that: flat, deduplicated, and the same shape every run.

So the two skills split by reader, and the routing belongs in your own `CLAUDE.md`:

```markdown
Always apply the `unslop` skill to prose a person reads: chat, documents, READMEs,
commit messages, briefs. Prose an agent consumes goes to `writing-for-agents`
instead: SKILL.md files, CLAUDE.md, AGENTS.md, subagent prompts, and an effort's
spec.md and plan.md.
```

Without that line you get `unslop` announcing it must always apply and nothing telling it where to stop.

## Why decisions, the words for them, and the tracker persist

Three tiers of decision, sorted by lifespan, the glossary standing beside them, and the tracker recording outcomes rather than reasoning.

- **Glossary**: one line per term, `CONTEXT.md` in [the document home](docs/document-home.md). The only file here edited in place rather than superseded, because a glossary you have to read archaeologically is a glossary nobody reads. Every agent that writes or reviews code reads it; a name that contradicts it is a review finding.
- **Log**: one line per decision, `decisions.md` in the document home. Stays one file, scanned in one pass, by rotating out to `decisions/archive/` past a size threshold, per [0006](.capstan/decisions/0006-rotate-the-decision-log.md).
- **Record**: a full document only when a decision is hard to reverse *and* surprising without context *and* a real trade-off. All three, so most efforts produce none.
- **Tracker**: one row per slice, carrying the effort, the slice, its status and the commit that merged it. Unset, that's `tracker.md` in the document home; configured, it's the board [described below](#why-the-tracker-gained-a-second-surface) instead. Nothing else here records what shipped, so it is the one place that question stays answerable once the plan that shipped it is gone.
- **Brief**: generated per recipient at send time, never stored, never maintained.

The log carries unsettled questions too. A question the interview could not resolve becomes an `open` line, or an `assumed` one when the crew picked a default to keep moving. Both get reported at every gate, neither blocks one, and the next interview reads them back before its first round. Without that, a hard question asked in March dies with the spec that held it.

A third status covers what is not yet a question at all. An `unformed` line names an area the effort will reach and nobody has looked at, and it exists because the other two mishandle it: asked as an `open` question it stalls twice and gets parked, and left out entirely it arrives as a surprise in phase 3. It is the one line that gets rewritten rather than superseded, since nothing was decided and there is no history to protect. The idea is Matt Pocock's fog of war, from `wayfinder`, without the issue tracker it is built on.

Everything else lives in `.capstan/effort/`, the one gitignored piece of `.capstan/`, and is deleted at delivery. A stale spec or an old research file is worse than none, because the next agent reads it as current.

The reason external documentation becomes unreadable is almost always that one artifact was made to serve two audiences with opposite needs. An internal record is dense and assumes context. A partner brief is short and assumes nothing. Do not maintain the second one. Regenerate it.

## Why the document home is one root, never two copies

Some operators would rather read the glossary, the log, the records, and the tracker in a markdown viewer they already use than find them sitting in the repository beside the code. The document home answers that with one configured root, resolved everywhere, defaulting to the repository so an operator who configures nothing notices no difference.

The alternative, writing to the repository and mirroring into the vault, was rejected outright. Two copies of the same file is a sync problem, and a sync problem needs an operating layer to keep the copies from drifting apart, which is exactly the kind of thing this project refuses to build and maintain. One root means a file exists in exactly one place, and "where is the real one" is never a question anyone has to ask.

The same reasoning is why the effort scratch never follows the document home wherever it points. `CLAIM.md`, `spec.md`, `plan.md`, scout returns, and review output are per-run and thrown away at delivery. A vault is somewhere an operator keeps things; filling it with dead specs is the exact staleness the document home exists to get away from.

The log stays a single file for a related reason, even inside a vault where one note per item is the native shape. Scanning every decision on one screen, in order, is the entire value of the log, and one note per decision is the bloat `decision-record` was designed to prevent. Splitting it up in a vault would buy back the ability to query decisions like data, at the cost of the property that makes the log worth keeping. We chose that trade in the log's favour. Once the log grew past the size a session should read whole, we paid for that choice a different way. `capstan-log rotate` moves every row that is not `open`, `assumed` or `unformed` out to an append-only file under `decisions/archive/`, keeping the newest 50 rows of any status behind, so the file an effort reads by default stays small and nothing already decided is thrown away. See [0006](.capstan/decisions/0006-rotate-the-decision-log.md) for why rotation, not a query layer, is the fix. The log's value was never being queryable. It was being read whole in one pass, and the active log still holds that property. The archive gives up being read whole. An effort greps it for its own area terms instead.

## Why the knowledge base sits outside the document home

The document home holds this project's records. The knowledge base holds what the operator knows across every project, and the difference is not filing. A repository can answer what this project decided. Nothing inside it can answer what was decided across every venture at once, because each repository only ever sees itself. The Courier writes one note per effort into that second place, and it is the only thing Capstan produces whose value comes from sitting beside notes from work this repository has never heard of.

So it gets its own key rather than a corner of the document home. The two settings behave differently in every way that matters. The document home has a default, so unset is ambiguous and `setup` writes the answer down either way. The knowledge base has none, so unset is a complete answer. There is no knowledge base, the Courier writes no note, and it says so in the close-out. That branch lived as prose the Courier read out of the same two files, and prose degraded badly. A Courier finding nothing reported no knowledge base and skipped, which reads exactly like a correct outcome and stays invisible until somebody notices the notes stopped arriving.

**Capstan never runs git in there.** Not a commit, not a stage, not a branch. This started life as a vault-detection step, working out whether the folder was a repository and behaving differently if it was, and one flat rule beat two branches outright. The operator commits the note, once, after it passes review.

That choice costs something worth naming. Because the note is never committed, its review has no fixed point to diff against, so the Reviewer reads the whole file and says in its report that it did. A degraded review every time beats a clean review that only works where someone happened to keep their notes under version control.

The frontmatter belongs to the folder rather than to Capstan. A knowledge base carries conventions Capstan did not write and cannot safely infer, so the Courier reads the folder it is writing into instead of generalising from one example somewhere else. The rule that keeps biting is copy versus derive. A link to the folder's own map is a property of the folder, so it gets copied. The date, the note's type, and every tag naming the work are facts about this effort, so they get derived. Copying where the rule says derive is never obviously wrong, because a neighbour's value is always plausible, and nothing surfaces the mistake until one search returns two projects at once.

Two things Capstan will not do in someone else's vault, both of which it did once. It does not create a node in their taxonomy, because deciding that a knowledge base needs a new branch is the operator's call. And it does not edit neighbouring notes to satisfy the vault's own health check, a rule that lives in their configuration and can push a Courier into changing notes an earlier decision told it to leave alone.

## Why the tracker gained a second surface

`tracker.md` shipped first and stayed the only surface for a long stretch, not because a second one was ruled out but because nothing forced the question until an operator asked for a board. The surface lives in its own plugin, `capstan-board`, rather than in core, per [896](.capstan/decisions.md). Every install carrying code that reads and writes GitHub state, whether or not that operator ever turns it on, is the same shape of cost the thin-executable-layer rule exists to keep bounded, and a board is the kind of thing most projects never touch. Core keeps only the key parsing and the stop that names the plugin when it is missing.

What a board buys is entirely for people. An agent building or reviewing a slice already has `tracker.md` open, offline, at the commit it is reading. Pointing that agent at a board instead would gain it nothing. What a board gives you is a link a teammate can open without cloning the repository, and an issue: the one project-item kind GitHub lets a pull request or a linked commit close, which is why this surface maps a slice onto an issue rather than a bare project item. That is a real want, and it belongs to whoever typed `/capstan-board:setup`, not to the crew that reads the file underneath it.

The trade is named rather than hidden. `tracker.md` at any commit is always the same table: read it twice against that commit and the rows come back identical, which is what lets a resumed phase check what it expected against what is there. A Projects board has no such point to stand on. It is live, mutable state on someone else's server, and two reads a minute apart can disagree with nothing recording why. That is the same degradation the knowledge-base note already carries, and here it costs more: the note is written once, at delivery, and left alone from then on. The tracker is written on every slice transition, planned to building to merged or dropped, so the board's missing fixed point gets paid on every move a slice makes, not once.

This was accepted with the cost named, not solved. Nothing here makes a board diffable the way a committed file is. An operator who wants that guarantee keeps the tracker on `tracker.md`. An operator who wants the board takes this trade knowingly.

## Why the Architect creates worktrees by hand

Subagents support `isolation: worktree` in frontmatter. This crew deliberately does not use it.

That field resolves against the **session's** working directory rather than the repository the work lives in. A session rooted anywhere else fails outright with "not in a git repository", however correct the paths handed to the Builder are. Since one session often works across several repositories, that is the normal case rather than an edge case.

So the Architect runs `git -C <repo> worktree add ...` itself, hands each Builder an absolute path, and removes the worktree after the merge. Nothing ever changes directory, and the flow works from a session rooted anywhere, including somewhere with no repository at all.

The related trap: `.capstan/effort/` is gitignored, so an effort's spec, plan, and research do not exist inside any worktree. Builders get absolute paths into the main working copy for those. A Builder that cannot find its brief will invent one.

## Why a thin executable layer exists

Prose holds intent well and sequence badly. The decision log has a run of rules that were read correctly and still failed, because the failure was in the order of operations rather than the words: a claim checked and then written, so two sessions could both pass the check; a tracker read that returned thirty rows and exited zero, so a partial board looked complete; a delete written as `effort*`, which reached `effort-archive`; one claim field standing for both the baseline a check is classified against and the checkpoint a run resumes from, so the baseline moved at every gate; a version committed after the verification meant to cover it; a fan-out with no ceiling and a fix loop counted in free text. Sharpening the wording had been tried on more than one of them.

So a bounded amount of code is admitted, under a rule for what qualifies. A helper replaces a rule that has already failed on the record, and does one deterministic thing when a skill tells it to: take a lock with `mkdir`, count a dispatch against a limit, delete a path it has verified, rotate a log's rows out to an archive. It never decides anything. The skill still says when to call it and what the exit code means, and the judgement about what to do next stays in prose. Three exist in core, sharing one folder that travels with the `effort` skill under either install: `capstan-claim`, `capstan-scratch-clean`, and `capstan-log`, the newest, which rotates `decisions.md` per [0006](.capstan/decisions/0006-rotate-the-decision-log.md). A fourth, `capstan-tracker`, reads a board until its own completeness check passes; it lives in the `capstan-board` plugin instead of core, on the same admission rule, because most projects never install that plugin at all. `tests/` plus CI, in each plugin, are what keep every helper and its instruction in step.

What stays out is the same as before: no scheduler, because a Builder returning is what frees a place and the run still ends at the gate; no hooks, because nothing should fire without an agent asking; no schemas, because a spec with a validator is a spec someone will stop editing. The cost is real and recorded in 0004: bash 3.2 to keep working on, `gh` to track, and a README sentence that had to be qualified.
