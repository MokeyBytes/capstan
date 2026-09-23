# Benchmark protocol

What this measures: whether Capstan's gates and review catch more real defects than plain Claude Code on the same task, and at what cost in tokens, time and operator attention. Nothing here has been run yet. Every number in `RESULTS-TEMPLATE.md` stays blank until a real run produces it.

## Candidate repositories

Three repositories, plus one spare, from `.capstan/effort/scout/bench-candidate-repos.md`, chosen per decision 900.

1. **pallets/click** (Python), issue [#373](https://github.com/pallets/click/issues/373), "argument groups for --help". BSD-3-Clause. Roughly 20-30k lines by the scout's byte-count estimate. Tests run through `pytest`/`tox`, no network. Confidence: high on license and activity, medium on the issue splitting cleanly into 2-4 slices.
2. **spf13/cobra** (Go), issue [#739](https://github.com/spf13/cobra/issues/739), "pass unknown flags through to the command". Apache-2.0. Roughly 10-12k lines. Tests run through `go test ./...`, no network. Its last code push was about 2.5 months before this effort started, at the edge of the "active" bar the scout was asked to check. Confirm it is still current before using it.
3. **tj/commander.js** (JavaScript), issue [#2346](https://github.com/tj/commander.js/issues/2346), "fill name/version/description from the nearest package.json". MIT. Roughly 15-20k lines. The scout could not confirm the test command or whether it needs network access; this is the first thing to check in pre-flight.
4. **sharkdp/bat** (Rust), issue [#1611](https://github.com/sharkdp/bat/issues/1611), "step increments for --highlight-line", the spare. Apache-2.0. Roughly 12-15k lines. Tests run through `cargo test --locked`, no network for the base suite. Use this in place of cobra or commander.js if either fails its pre-flight check below.

## Task statements

Written once per repository. Give the operator's session the exact text below, unedited, in both arms.

**click (#373):** "Add support for grouping related options under named headings in `--help` output, the way argparse's `add_argument_group` does. Commands that do not opt in must keep rendering options exactly as they do today. Cover the grouping API, the help-text rendering of the groups, and tests for both."

**cobra (#739):** "Add an opt-in mode where a command collects flags it does not recognize instead of failing on them, and exposes the collected flags to the command's `Run` function. A command that does not opt in must keep failing on an unknown flag exactly as it does today."

**commander.js (#2346):** "Add a `usePackageJson()` option that finds the nearest `package.json` from the caller and fills in the program's `name`, `version` and `description` from it, without overriding any of those fields the caller already set. Cover both ESM and CJS entry points."

**bat (#1611, spare):** "Extend `--highlight-line` to accept a `start:end:step` range that highlights every step-th line in the range, while keeping the existing `start:end` syntax working unchanged."

## The two arms

**Baseline arm.** Plain Claude Code, same model as the Capstan arm, the Capstan plugin disabled for the session. Give it the task statement above and nothing else. Let it work until it says it is done, or gets stuck.

**Capstan arm.** Run `/capstan:effort <task statement>` with the same text. Answer the interview and the gates as the operator normally would, and record every answer given (see "What transcripts to keep" below).

Same repository, same starting commit, same model, for both arms. Run the arms in either order; nothing here depends on which goes first.

## Pre-flight, once per repository before either arm runs

1. Clone the repository fresh. Record the exact commit SHA of `HEAD` right after cloning: this is the pinned commit both arms build from. Do not update either clone once a run starts.
2. Run the repository's own test command (from the table above) with no network access and time it. It must finish inside five minutes. If it does not, or if it needs network access, drop that repository and use the spare (bat) instead, and note the failure and its reason in `RESULTS-TEMPLATE.md`.
3. Open `bench/pricing.tsv` and check its figures against the live pricing page named at the top of that file. Confirm the model the session will actually run under has a row keyed to its exact `message.model` string; add or correct a row if not, and note the source and fetch date the same way the existing rows do. A run under an unconfirmed or missing price prints "unpriced", never a false $0.

## Run order

Repeat this for each of the three chosen repositories.

1. Complete pre-flight above.
2. Make two fresh clones of the pinned commit, one for each arm, so neither arm's work touches the other's.
3. Run the baseline arm in its clone. Record wall-clock time from the first message to the model's final answer.
4. Run the Capstan arm in its clone. Record wall-clock time from the first message to the closing brief.
5. For each arm, run `bench/bin/session-usage <session.jsonl-or-session-dir>` against every Claude Code session the run used. A Capstan run that spans a resume after gate 1 may use more than one session file; run `session-usage` on each and add their totals per model by hand.
6. For each arm, run the repository's own declared test command against the result and record pass or fail.
7. For the Capstan arm, read the Reviewer's findings from that slice's review and count how many caught a real defect, by the rule below.
8. Count gates reached and operator interventions for each arm, by the rules below.
9. Fill in one row per arm per repository in `RESULTS-TEMPLATE.md`, from what steps 3-8 actually measured. Leave a cell blank rather than guess at it.
10. Copy the raw session files and the `session-usage` output for both arms into `bench/transcripts/<repo>-<arm>/`, per "What transcripts to keep" below.

## What gets recorded, and how

- **Tokens and cost, by model.** From `session-usage`, per the previous section. `session-usage` reports a model absent from `pricing.tsv` as unpriced rather than $0; carry that into `RESULTS-TEMPLATE.md` as "unpriced", not as zero.
- **Wall-clock time.** From the first message the operator sends to the last message that ends the run, for each arm.
- **Gate count.** How many gates the Capstan arm's run stopped at before delivery. The baseline arm has none, by definition.
- **Operator interventions.** Count one intervention for every operator message that is not a bare approval ("yes", "looks good", "proceed", a single accepted default) and not a gate answer given verbatim from a recommended default. A free-form correction, added constraint, or steering message counts, in either arm, whether it comes during an interview round, a gate, or while the model is mid-task.
- **Declared checks.** Whether the target repository's own test command (confirmed in pre-flight) passes against each arm's final result. Record pass, fail, or "not run" with the reason.
- **Review findings that caught a real defect.** A finding counts as real when the behaviour it flags would fail the repository's declared test command, or contradicts the task statement's stated requirement, once fixed. A style preference, a suggestion outside the task statement's scope, or something the repository's own linter already catches does not count. The baseline arm has no review step, so this cell is always blank there, not zero.

## What transcripts to keep

For each repository and arm, save under `bench/transcripts/<repo>-<arm>/`:
- every session `.jsonl` file the run used, and its `subagents/` directory if it has one
- the `session-usage` output for each
- for the Capstan arm, the text of every gate brief and the operator's answer to it

These are raw records of real runs, not synthetic fixtures, so they may contain real task content. `bench/transcripts/` has no `.gitignore` entry of its own yet beyond `.gitkeep`; check with the operator before committing anything placed here.

## The one rule that matters

Nothing goes into `RESULTS-TEMPLATE.md` that this protocol did not measure. A blank cell means "not run yet". It never means zero, and it is never filled from a guess, a similar-looking prior run, or what seems plausible.
