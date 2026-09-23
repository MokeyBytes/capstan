# Capstan

Independent review with no Builder context. Hard gates where the run stops. Stop for consequence, never for ambiguity.

Capstan is a Claude Code plugin that takes work from concept to delivery. Five roles carry it: a Scout researches, the Architect, which is your own session, interviews and plans, each Builder builds one slice, a Reviewer checks two axes independently, and a Courier packages what ships. Nothing polls or runs unprompted. BytesNation publishes it from the MokeyBytes repository as `capstan@bytesnation`.

The [glossary](.capstan/CONTEXT.md) defines every word here; [`DESIGN.md`](DESIGN.md) holds the reasoning.

## Install

```bash
claude plugin marketplace add MokeyBytes/capstan
claude plugin install capstan@bytesnation
```

Restart Claude Code; agent definitions load at session start. This installs at user scope. Add `--scope project` for a shared repository.

For a GitHub Projects v2 board instead of a plain file, install the board plugin too:

```bash
claude plugin install capstan-board@bytesnation
```

Optional; see [tracker surface](docs/tracker.md) for the cost.

Run `/capstan:setup` to choose where the glossary, decision log, decision records and tracker file live. See [document home](docs/document-home.md). Skip it, and your first effort offers the default, or a stop to run `setup`.

## Your first run

```
/capstan:effort add rate limiting to the public API
```

You talk to the Architect throughout. It owns the interview, spec, slice graph and decision log, and never builds or reviews.

1. **It interviews you**, in rounds, each carrying a recommended answer.
2. **Gate one locks the concept**: what, why, and what you are not building.
3. **Phase two plans** slices and stops at gate two with what it assumed.
4. **Phase three builds and reviews** each slice, test-first, then runs your repository's checks against the merged result.
5. **Phase four delivers**: the Courier packages the output and writes the permanent note; you commit it once review passes.

For anything smaller, `/capstan:quick` runs one slice through a single gate; see [disciplines](#the-disciplines).

| Gate | The brief answers | You decide |
|---|---|---|
| 1. Concept locked | What we are building, why, what we are explicitly not doing | Right thing? |
| 2. Plan locked | How, cut into slices, what runs parallel, what was assumed | Right shape? |
| 3. Ready to deliver | What was built, what review and verification found, what goes to whom | Ship? |

**The run ends at every gate.** That is what makes the gate real. `.capstan/effort/CLAIM.md` records where the effort got to, so the next session resumes there. A lock beside it refuses a second session on the same effort and names who holds it; only you decide to resume or take over.

**Unclear requirements never stop the run.** The crew takes the most defensible reading, logs the assumption, and keeps going. Every assumption surfaces at the next gate, where correcting one costs almost nothing. Four things do stop it: secrets and credentials, anything a third party will see, anything that costs money, and anything destructive or production-facing. The one delete the crew makes on its own is the gitignored scratch, at delivery.

## The disciplines

Three front doors, invoked only by you, none a discipline: [`effort`](skills/effort/SKILL.md) starts a full run, [`quick`](skills/quick/SKILL.md) runs one slice through a single gate, [`setup`](skills/setup/SKILL.md) configures where the artifacts live. Installing `capstan-board` adds a fourth, `/capstan-board:setup`, for the tracker surface.

| Skill | For |
|---|---|
| [`interview`](skills/interview/SKILL.md) | Rounds of questions, each with a recommendation. |
| [`spike`](skills/spike/SKILL.md) | A throwaway build for a stalled design question. |
| [`slicing`](skills/slicing/SKILL.md) | Cuts a locked plan into vertical slices with blocking edges. |
| [`test-first`](skills/test-first/SKILL.md) | Red, green, refactor, tested only at agreed seams. |
| [`diagnosing-bugs`](skills/diagnosing-bugs/SKILL.md) | A feedback loop that goes red on the bug before any theory. |
| [`codebase-design`](skills/codebase-design/SKILL.md) | Words for structure, so a review can call a module too shallow. |
| [`two-axis-review`](skills/two-axis-review/SKILL.md) | Standards and spec, reviewed independently, never blended. |
| [`verify`](skills/verify/SKILL.md) | Runs the checks your repository declares against the merged result. |
| [`resolving-merge-conflicts`](skills/resolving-merge-conflicts/SKILL.md) | Integrating parallel Builders, where neither Builder can be asked its intent. |
| [`walkthrough`](skills/walkthrough/SKILL.md) | The one-time script for a manual procedure. |
| [`decision-record`](skills/decision-record/SKILL.md) | A one-line log by default, a full record only when earned. |
| [`brief`](skills/brief/SKILL.md) | Checkpoint and partner briefs, per recipient, never maintained. |
| [`to-questionnaire`](skills/to-questionnaire/SKILL.md) | Turns a question nobody present can answer into a document for whoever can answer it. |
| [`unslop`](skills/unslop/SKILL.md) | Cuts AI tells from prose a person reads. |
| [`writing-for-agents`](skills/writing-for-agents/SKILL.md) | Keeps a document an agent consumes flat and consistent. |

## What a gate brief looks like

<!-- PLACEHOLDER: real gate brief from a bench/ Capstan-arm run -->

A real brief goes here once `bench/` produces one. Nothing here is invented; see [`bench/PROTOCOL.md`](bench/PROTOCOL.md) for how one gets measured.

## What this costs

Models and effort come from each agent's frontmatter in `agents/*.md`: Builder runs `sonnet`/`high`, up to `capstan-max-builders` (3) at once. Reviewer runs `opus`/`xhigh`, once per slice and again per fix dispatch, up to `capstan-max-fix-dispatches` (5), plus once more on the knowledge-base note when configured. Scout and Courier both run `sonnet`/`medium`; the Architect is your own session, not a subagent.

What scales the bill: slices cut, fix dispatches per slice, and Scouts fired. A one-slice `quick` run costs one Builder and one Reviewer, plus up to two fix dispatches, each reviewed by a fresh Reviewer.

<!-- PLACEHOLDER: measured cost figures from bench/ -->

No dollar or token figure appears until `bench/` measures one. See [`bench/PROTOCOL.md`](bench/PROTOCOL.md) for the benchmark against plain Claude Code.

## Upgrading to 3.0.0

The GitHub tracker board moved out of core into its own plugin, `capstan-board`. If `capstan-tracker` already names a GitHub project, install `capstan-board@bytesnation` before your next effort or quick. Otherwise an effort stops before its interview, and a quick after its interview: `surface not installed: install capstan-board@bytesnation`. A project that has never set `capstan-tracker` sees no change. See [upgrading](docs/upgrading.md) and [tracker surface](docs/tracker.md) for the rest.

## Known limits

**`/capstan:effort` cannot be invoked by a model.** It carries `disable-model-invocation: true`, same as `quick` and `setup`, so only you start it.

**The `effort:` setting is not supported on Haiku.** Drop the `effort:` frontmatter line from any agent you point at a Haiku model.

**Bash is an escape hatch.** Builder, Reviewer and Courier all hold Bash, so their "never do X" rules are prose, not enforcement. [`examples/`](examples/) ships a `settings.json` deny list, but it matches text, not the program, so it can't stop `/bin/rm -rf`. Builder's `acceptEdits` skips file-write prompts; Bash still prompts, stalling fan-out.

**Fan-out does nothing for single-artifact work.** Parallel Builders need slices owning different files; a document, a video script, or a config file is one artifact and one Builder.

**The helpers refuse; they do not intercept.** `capstan-claim` refuses a second owner, a sixth fix dispatch, or a fourth Builder. Three efforts at once is the ceiling. The Architect enforces it by asking which to close first; no helper counts efforts. Nothing stops an agent from running `rm -rf` or spawning a Builder by hand. The tests prove what each helper does when called, not that every agent calls it.

**Reading a live board and tearing it down has been tested once, for real.** A live trial moved 42 items off a GitHub board: every item read back, the reconstruction diffed clean, every item removed and the open milestones closed. Moving onto a board, in its current form, has not run end to end against a real one. Its writes ran live under earlier releases, and the read-back check that now guards the delete has run live only on the way off.

**The knowledge-base note is reviewed whole, when there is one.** Capstan never commits it, so it has no fixed point to diff against.

More: [document home and vault layouts](docs/document-home.md), [tracker surface](docs/tracker.md), [knowledge base](docs/knowledge-base.md), [upgrading and moving the marketplace](docs/upgrading.md), [installing by hand](docs/manual-install.md), [what CI runs](docs/checks.md).

## Licence

MIT. See [LICENSE](LICENSE). Take it, change it, ship it.

Some skills here are not ours, most from [Matt Pocock](https://github.com/mattpocock/skills), MIT and redistributed with a `CREDIT.md` recording every change:

- [`skills/writing-for-agents/`](skills/writing-for-agents/): `SKILL.md`, `SKILL-MECHANICS.md`.
- [`skills/unslop/`](skills/unslop/): `SKILL.md`, by [Lauren Tan](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop) via cursor/plugins.
- [`skills/walkthrough/`](skills/walkthrough/): `template.sh`, forked.
- [`skills/diagnosing-bugs/`](skills/diagnosing-bugs/): `SKILL.md`.
- [`skills/codebase-design/`](skills/codebase-design/): `SKILL.md`, `DEEPENING.md`, `DESIGN-IT-TWICE.md`.
- [`skills/to-questionnaire/`](skills/to-questionnaire/): `SKILL.md`.
- [`skills/resolving-merge-conflicts/`](skills/resolving-merge-conflicts/): `SKILL.md`.

More ideas come from him: the frontier in `interview`, from `grilling`; the `next` field in `CLAIM.md`, from `handoff`; the `unformed` log status, from `wayfinder`; two `interview` moves, from `domain-modeling`.

<a href='https://ko-fi.com/G5C025L5FG' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
