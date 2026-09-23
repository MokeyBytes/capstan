# Benchmark protocol

What this measures, per repository and per arm:

- whether the repository's own test command passes against the result
- for the Capstan arm, how many review findings caught a real defect
- tokens and cost by model
- wall-clock time
- gate count
- operator interventions

Nothing here has been benchmarked yet. Every number in `RESULTS-TEMPLATE.md` stays blank until a real benchmark run produces it.

## Candidate repositories

Three repositories, plus one spare, from `.capstan/effort/scout/bench-candidate-repos.md`, chosen per decision 900.

1. **pallets/click** (Python), issue [#373](https://github.com/pallets/click/issues/373), "Equivalent of argparse's add_argument_group, help sections". BSD-3-Clause. Roughly 20-30k lines by the scout's byte-count estimate. Confidence: high on license and activity. Confidence: medium on the issue splitting cleanly into 2-4 slices.
2. **spf13/cobra** (Go), issue [#739](https://github.com/spf13/cobra/issues/739), "Option to pass unknown flags to command". Apache-2.0. Roughly 10-12k lines. Confidence: low on line count, per the Scout. Its last code push was about 2.5 months before this effort started, inside the Scout's three-month activity bar. Pre-flight step 1 below confirms it is still current before it is used.
3. **tj/commander.js** (JavaScript), issue [#2346](https://github.com/tj/commander.js/issues/2346), "Feature request: automatically use `name`, `version` and `description` fields in nearest package.json". MIT. Roughly 15-20k lines. Confidence: low on line count, per the Scout.
4. **sharkdp/bat** (Rust), issue [#1611](https://github.com/sharkdp/bat/issues/1611), "Support increments with `--highlight-line`", the spare. Apache-2.0. Roughly 12-15k lines. Confidence: low on line count, per the Scout. Use this in place of any repository above that fails its pre-flight check below.

## Task statements

Written once per repository. Give the operator's session the exact text below, unedited, in both arms.

**click (#373):** "Add support for grouping related options under named headings in `--help` output, the way argparse's `add_argument_group` does. Commands that do not opt in must keep rendering options exactly as they do today. Cover the grouping API, the help-text rendering of the groups, and tests for both."

**cobra (#739):** "Add an opt-in mode where a command collects flags it does not recognize instead of failing on them, and exposes the collected flags to the command's `Run` function. A command that does not opt in must keep failing on an unknown flag exactly as it does today."

**commander.js (#2346):** "Add a `usePackageJson()` option that finds the nearest `package.json` from the caller and fills in the program's `name`, `version` and `description` from it, without overriding any of those fields the caller already set. Cover both ESM and CJS entry points."

**bat (#1611, spare):** "Extend `--highlight-line` to accept a `start:end:step` range that highlights every step-th line in the range, while keeping the existing `start:end` syntax working unchanged."

## Test commands, one per repository, from its own CI

- **click:** `TOX_ENV=py3.14 uv run --locked --no-default-groups --group dev tox run`, or `TOX_ENV=py<version>` for whichever Python interpreter the operator has installed. Source: `.github/workflows/tests.yaml` on `pallets/click`, fetched 2026-09-23: the job sets `TOX_ENV: ${{ matrix.tox || format('py{0}', matrix.python) }}` before this same command, which is what picks one tox environment per CI job rather than tox's full twelve-environment list.
- **cobra:** `make richtest`. Source: `.github/workflows/test.yml` on `spf13/cobra`, fetched 2026-09-23. That job installs `richgo` first; see the dependency-install step below.
- **commander.js:** `npm test`, which runs `node --test && npm run check:type:ts`. Source: `.github/workflows/tests.yml` and `package.json` on `tj/commander.js`, fetched 2026-09-22.
- **bat, spare:** `cargo test --locked`. Source: the `build` job in `.github/workflows/CICD.yml` on `sharkdp/bat`, fetched 2026-09-23, which runs `cargo test --locked --target=<platform>` with no asset rebuild. That job also checks out submodules first; see the dependency-install step below.

Use the exact command above for a repository's declared-checks measurement in every arm. Each command is a declared check in CONTEXT.md's sense, because it comes from the repository's CI rather than picked ad hoc.

## The two arms

**Baseline arm.** Plain Claude Code, the Capstan plugin disabled, given the task statement above and nothing else. Let it work until it says it is done, or gets stuck.

**Capstan arm.** Run `/capstan:effort <task statement>` with the same text. Answer the interview and the gates as the operator normally would. Record every answer given. "What transcripts to keep" below says where.

**What is held identical between the two arms:**

- the repository and the pinned starting commit
- the task statement, given verbatim
- the main session's model, pinned the same way in both arms with `claude --model <full model id>`, for example `claude --model claude-opus-5-5` rather than the alias `opus`. An alias can resolve to a different version between the two arms if `claude` updates in between. A full model id cannot. Record the model used and the output of `claude --version` in `RESULTS-TEMPLATE.md`'s Notes, for each arm. The Capstan arm's crew still runs its own frontmatter models regardless of this flag: the `sonnet` and `opus` aliases in `agents/*.md`, which carry the same resolve-over-time risk. Take each crew role's actual model from the model column that `bench/bin/session-usage` prints for its transcript, not from the frontmatter alias. Record those resolved ids in Notes too, so a cost difference between arms is never read as a same-model comparison when it is not.

**What is not held identical, by design:** every other plugin and skill available to the session. The baseline session keeps the operator's global `CLAUDE.md` and every other installed plugin; only the Capstan plugin itself is disabled. If the operator's global `CLAUDE.md` instructs a skill that only Capstan provides, such as `capstan:unslop`, that instruction cannot be carried out in the baseline arm; note that in Notes rather than treating it as a baseline defect.

**Disabling the Capstan plugin for the baseline arm:** before starting the baseline session, write to `.claude/settings.local.json` inside the baseline clone:

```json
{ "enabledPlugins": { "capstan@bytesnation": false } }
```

Use `false`, not a missing entry. A missing entry falls back to the user-level setting, which enables it.

**Arm order:** run the baseline arm first, then the Capstan arm, for every repository. This is a fixed order, not alternated, so the same variable is held constant across all three repositories. Note in `RESULTS-TEMPLATE.md` that this is the order used. Running baseline first means the operator answering the Capstan arm's interview and gates has already seen that repository's own baseline result, including where it went wrong. That knowledge can help the arm being measured; record in `RESULTS-TEMPLATE.md`'s Notes that the Capstan arm's answers came after watching the baseline.

## Pre-flight, once per repository before either arm runs

1. Confirm the repository is still current. Check its GitHub page for a push within the last three months, the Scout's own activity bar. If it is not current, use the spare (bat) instead, and note the swap and the reason in `RESULTS-TEMPLATE.md`. If bat is not current either, stop and reopen decision 900 rather than picking a fifth repository.
2. Clone the repository fresh at its default branch. Record the exact commit SHA:
   ```
   git clone <url> <dir>
   git -C <dir> rev-parse HEAD
   ```
   That SHA is the pinned commit both arms build from. Do not run `git pull` or otherwise update either clone once a run starts.
3. Install dependencies, network allowed:
   - click: `uv sync --locked` in the clone.
   - cobra: `go mod download` in the clone, then `go install github.com/kyoh86/richgo@latest` and add `$HOME/go/bin` to `PATH`, the way `.github/workflows/test.yml` does.
   - commander.js: `npm ci` in the clone.
   - bat, spare: `git submodule update --init --recursive`, then `cargo fetch`, in the clone.
4. Run the repository's test command from the table above once with the network on, to warm caches. Do not time this run. Then disconnect the network: turn off Wi-Fi, or unplug the network cable. Run the same command again, timed:
   ```
   time <test command>
   ```
   It must finish inside five minutes with the network off. If it fails only because it still needs network, or does not finish in five minutes, reconnect the network, drop that repository, and use the spare (bat) instead. If bat then fails the same way, stop and reopen decision 900 rather than dropping a second repository silently. Note the failure and its reason in `RESULTS-TEMPLATE.md`. Reconnect the network before continuing either way.
5. Open `bench/pricing.tsv` and check its figures against https://platform.claude.com/docs/en/about-claude/pricing, the page named at the top of that file. Confirm the model the session will actually run under has a row keyed to its exact `message.model` string. Add or correct a row if not, and note the source and fetch date the same way the existing rows do. Never invent a price. Leave a rate blank when no source gives one. A benchmark run under a blank or missing price prints "unpriced" for that model or that cost component, never a false $0.

## Run order

Repeat this for each of the three chosen repositories.

1. Complete pre-flight above.
2. Make two fresh clones of the pinned commit, one for each arm, so neither arm's work touches the other's:
   ```
   git clone <url> <dir>
   git -C <dir> checkout <pinned-sha>
   ```
3. In the baseline clone, write `.claude/settings.local.json` as shown above, then start the baseline arm with `claude --model <full model id>` and give it the task statement. Record `claude --version` and the wall-clock time from the first message to the model's final answer.
4. In the Capstan clone, start the Capstan arm with `claude --model <full model id>`, the same id used in the baseline arm, then run `/capstan:effort <task statement>`. Record `claude --version` and the wall-clock time from the first message to the closing brief. Before answering gate 3, copy `<clone>/.capstan/effort/review/` to `bench/transcripts/<repo>-capstan/review/`; phase 4 deletes that directory before the closing brief, so it must be copied here rather than later at step 8.
5. Locate each arm's session file. By default it is at:
   ```
   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<escaped-cwd>/<session-id>.jsonl
   ```
   where `<escaped-cwd>` is the clone's absolute path with every character that is not a letter or digit replaced by `-`. Find the newest one for a clone with:
   ```
   escaped=$(cd <clone> && pwd | sed 's/[^A-Za-z0-9]/-/g')
   ls -t "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$escaped"/*.jsonl | head -1
   ```
   The Capstan arm spans at least four runs, one per phase, ended at the three gates plus delivery. Each run may write its own session file if the operator's Claude Code session was closed and reopened between gates; if it was not, all four runs share one file. List every `.jsonl` file under that project directory with a modification time inside the arm's wall-clock window, and treat each as a session for the next step.
6. Run `bench/bin/session-usage` once per arm, passing every session file located in step 5 as separate arguments in one call: `bench/bin/session-usage <session1.jsonl> <session2.jsonl> ...`. It dedupes by `message.id` across every file given. That matters when the operator's session was closed and reopened with `/branch` or `--continue --fork-session`, since both copy a session's opening turns into the new file. Passing every file in one call avoids counting those copied turns twice. Running each file separately and adding totals by hand would not.
7. For each arm, run the repository's test command against the result and record pass or fail.
8. For the Capstan arm, read every slice's review, every round, from the `review/` copy made at step 4, and count how many findings caught a real defect, by the rule below.
9. Count gates reached and operator interventions for each arm, by the rules below.
10. Fill in one row per arm per repository in `RESULTS-TEMPLATE.md`, from what steps 3-9 actually measured. Leave a cell blank when this protocol has not measured it yet. Write "n/a" in a cell that does not apply to that arm, such as the baseline arm's review-findings cell.
11. Copy the raw session files and the `session-usage` output for both arms into `bench/transcripts/<repo>-<arm>/`, per "What transcripts to keep" below.

## What gets recorded, and how

- **Tokens and cost, by model.** From `session-usage`, per the previous section. `session-usage` reports a model absent from `pricing.tsv` as unpriced rather than $0, and a model with one blank rate as partial rather than a silently short total. Carry either word into `RESULTS-TEMPLATE.md` exactly as `session-usage` printed it.
- **Wall-clock time.** For each arm, sum the span of every session file located in step 5: each file's own span from `first_timestamp` to `last_timestamp`, as `bench/bin/session-usage` prints when run on that one file by itself. Time the operator's Claude Code session was closed between files, for example overnight between gates, does not count toward this total.
- **Gate count.** How many gates the Capstan arm stopped at before delivery. Write "n/a" for the baseline arm. It has no gates by definition, which is different from a gate count of zero.
- **Operator interventions.** An operator message counts as an intervention unless it is one of two things: a bare approval such as "yes", "looks good", "proceed", or a single accepted default; or a gate answer given verbatim from the recommended default. Every other operator message counts, in either arm, whether it comes during an interview round, a gate, or while the model is mid-task: a free-form correction, an added constraint, or a steering message.
- **Declared checks.** Whether the repository's test command, confirmed in pre-flight, passes against each arm's final result. Record pass, fail, or "not run" with the reason.
- **Review findings that caught a real defect.** A finding counts as real under either rule below.
  - Rule one: the flagged behaviour would fail the repository's test command as the result stood before the fix, and applying the fix makes that command pass.
  - Rule two: the flagged behaviour contradicts a requirement stated in the task statement, and applying the fix resolves the contradiction.
  - A style preference does not count. A suggestion outside the task statement's scope does not count. A finding the repository's own linter already catches does not count.
  - Write "n/a" for the baseline arm. It has no review step, which is different from a count of zero.

## What transcripts to keep

For each repository and arm, save under `bench/transcripts/<repo>-<arm>/`:
- every session `.jsonl` file the arm used, and its `subagents/` directory if it has one
- the `session-usage` output for each
- for the Capstan arm, the copied `review/` directory from step 4 above, and the text of every gate brief and the operator's answer to it

These are raw session transcripts of real runs, not synthetic fixtures. A transcript can carry the operator's email address, their global `CLAUDE.md` persona text, and whatever real content passed through the task, not only the repository's own code. `bench/transcripts/` is gitignored down to its own `.gitignore` and `.gitkeep`; nothing placed here is committed by default. Check with the operator before deliberately committing anything from this directory.

## The one rule that matters

Nothing goes into `RESULTS-TEMPLATE.md` that this protocol did not measure. A blank cell means "not measured yet"; it never means zero. "n/a" means the cell does not apply to that arm. Neither is ever filled from a guess, a similar-looking prior benchmark, or what seems plausible.
