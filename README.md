# Capstan

Independent review with no Builder context. Hard gates where the run actually stops. Stop for consequence, never for ambiguity.

Capstan is a Claude Code plugin that takes work from concept to delivery. Five roles carry it: the Architect (your own session) runs the interview and the plan, a Builder builds one slice at a time in its own worktree, a Reviewer checks the diff on two independent axes with none of the Builder's reasoning, and a Courier packages what shipped. Three gates stop the run outright, so you decide whether it continues. Nothing polls, nothing runs on its own, and nothing asks in the background. Published by BytesNation, from the MokeyBytes repository; it installs as `capstan@bytesnation`.

This repository's own [glossary](.capstan/CONTEXT.md) defines every word it uses, and [`DESIGN.md`](DESIGN.md) holds the reasoning behind the shape.

## Install

```bash
claude plugin marketplace add MokeyBytes/capstan
claude plugin install capstan@bytesnation
```

Restart Claude Code once it finishes. Agent definitions load at session start, so nothing applies until you do. That installs at user scope, so the crew is available in every session. Add `--scope project` to write to the project's `.claude/settings.json` instead, which is what you want when a team shares one repository.

If you want slice state on a GitHub Projects v2 board instead of a plain file, install the tracker surface too:

```bash
claude plugin install capstan-board@bytesnation
```

That is optional and separate; see [tracker surface](docs/tracker.md) for what it does and what it costs.

Run `/capstan:setup` next, in the repository you plan to work in. It asks where the glossary, decision log, decision records and tracker file should live: in the repository by default, or in a vault outside it. See [document home](docs/document-home.md). Skip it and your first effort asks a narrower version of the same question: take the default, or stop and run `setup` to choose a folder outside the repository. You cannot name a vault path from inside an effort.

## Your first run

```
/capstan:effort add rate limiting to the public API
```

You are now talking to the Architect, and you keep talking to it for the rest of the run. It owns the interview, the spec, the slice graph and the decision log. It does not build and it does not review, because the Builder and the Reviewer do that.

What happens, in order:

1. **It interviews you.** Rounds of questions, each carrying a recommended answer, so most rounds are you confirming rather than composing.
2. **It stops at gate one** with a brief covering what it is building, why, and what it is deliberately not building. Protect this gate: a wrong turn is cheapest to catch here.
3. **Phase two plans.** It cuts the work into vertical slices, agrees where the tests go, and stops at gate two with the slice graph and everything it had to assume.
4. **Phase three builds.** One Builder per slice, each in its own git worktree, each writing a failing test first. A Reviewer reads every diff without the Builder's reasoning. Once the slices merge, your repository's own checks run against the integration. Gate three shows you what was built, what review found, and what verification showed.
5. **Phase four delivers.** The Courier packages the output and writes the permanent note. You commit it, once the note review passes. It never sends anything to anyone.

For anything smaller than that, `/capstan:quick` runs one slice through one gate instead of three; see [the disciplines](#the-disciplines) below.

| Gate | The brief answers | You decide |
|---|---|---|
| 1. Concept locked | What we are building, why, what we are explicitly not doing | Right thing? |
| 2. Plan locked | How, cut into slices, what runs parallel, what was assumed | Right shape? |
| 3. Ready to deliver | What was built, what review and verification found, what goes to whom | Ship? |

**The run ends at every gate.** Nothing polls, nothing waits in the background, and the crew never asks whether it should stop. The run being over is what makes the gate real. `.capstan/effort/CLAIM.md` records where the effort got to, so the next session picks up where the last one stopped, however many hours later. A lock beside it means a second session starting the same effort is refused and told who holds it, and only you decide whether that session resumes it or takes it over.

**Unclear requirements never stop the run.** The crew takes the most defensible reading, writes the assumption into the decision log, and keeps going. Every assumption surfaces at the next gate, where correcting one costs almost nothing. Four things do stop it: secrets and credentials, anything a third party will see, anything that costs money, and anything destructive or production-facing.

## The disciplines

Three front doors, invoked only by you, and none of them a discipline: [`effort`](skills/effort/SKILL.md) starts a full run, [`quick`](skills/quick/SKILL.md) runs one slice through a single gate for anything too small to need slicing or a Courier, and [`setup`](skills/setup/SKILL.md) configures where the artifacts live. Installing `capstan-board` adds a fourth, its own `/capstan-board:setup`, for the tracker surface alone.

| Skill | For |
|---|---|
| [`interview`](skills/interview/SKILL.md) | Rounds of questions, each carrying a recommended answer, so decisions stay yours. |
| [`spike`](skills/spike/SKILL.md) | A throwaway build, so a stalled design question gets something concrete to react to. |
| [`slicing`](skills/slicing/SKILL.md) | Cuts a locked plan into vertical slices with real blocking edges. |
| [`test-first`](skills/test-first/SKILL.md) | Red, green, refactor, tested only at seams agreed in advance. |
| [`diagnosing-bugs`](skills/diagnosing-bugs/SKILL.md) | A feedback loop that goes red on the bug before anyone theorises about the cause. |
| [`codebase-design`](skills/codebase-design/SKILL.md) | The words for structure, so a review can say a module is too shallow instead of that it feels wrong. |
| [`two-axis-review`](skills/two-axis-review/SKILL.md) | Standards and spec, reviewed independently, never blended into one verdict. |
| [`verify`](skills/verify/SKILL.md) | Runs the checks your repository declares against the merged result. |
| [`resolving-merge-conflicts`](skills/resolving-merge-conflicts/SKILL.md) | Integrating parallel Builders, where neither side of a conflict can be asked what it meant. |
| [`walkthrough`](skills/walkthrough/SKILL.md) | The one-time script that carries you through a manual procedure, stage by stage. |
| [`decision-record`](skills/decision-record/SKILL.md) | A one-line log by default, a full record only when one is earned. |
| [`brief`](skills/brief/SKILL.md) | Checkpoint and partner briefs, generated per recipient rather than maintained. |
| [`to-questionnaire`](skills/to-questionnaire/SKILL.md) | Turns a question nobody in the room can answer into a document for the person who can. |
| [`unslop`](skills/unslop/SKILL.md) | Cuts AI tells from prose a person reads. |
| [`writing-for-agents`](skills/writing-for-agents/SKILL.md) | Keeps a document an agent consumes flat and the same shape every run. |

## What a gate brief looks like

<!-- PLACEHOLDER: real gate brief from a bench/ Capstan-arm run -->

A real brief goes here once a `bench/` run produces one. Nothing above is invented; see [`bench/PROTOCOL.md`](bench/PROTOCOL.md) for how one gets measured.

## What this costs

The crew's models are pinned in `agents/*.md`, not repeated here where they could drift out of step: Builder runs `sonnet` at `high` effort, up to `capstan-max-builders` (3) at once. Reviewer runs `opus` at `xhigh` effort, once per slice and again on every fix round, up to `capstan-max-fix-dispatches` (5) per slice. Scout and Courier both run `sonnet` at `medium` effort; Scouts fan out in parallel, one per open question. The Architect is your own session, not a subagent.

What scales the bill: how many slices a plan cuts, how many fix rounds a slice needs before review is clean, and how many Scouts a phase fires. A one-slice `quick` run costs roughly one Builder and one Reviewer; a five-slice effort with a rough round of review costs several times that.

<!-- PLACEHOLDER: measured cost figures from bench/ -->

No dollar or token figure appears above until `bench/` measures one. See [`bench/PROTOCOL.md`](bench/PROTOCOL.md) for the benchmark that will produce it, run against plain Claude Code on the same task.

## Upgrading to 3.0.0

The GitHub tracker board moved out of core into its own plugin, `capstan-board`. If your project's `capstan-tracker` already names a GitHub project, install `capstan-board@bytesnation` before your next effort, or it stops before the interview with `surface not installed: install capstan-board@bytesnation`. A project that has never set `capstan-tracker` sees no change. See [upgrading](docs/upgrading.md) and [tracker surface](docs/tracker.md) for the rest.

## Known limits

**`/capstan:effort` cannot be invoked by a model.** It carries `disable-model-invocation: true`, so only you start an effort, the same as `quick` and `setup`. An agent that can start work on its own authority can commit you to work you never asked for.

**Bash is an escape hatch.** Builder, Reviewer and Courier all hold Bash, so their "never do X" rules are prose rather than enforcement. [`examples/`](examples/) ships a ready-made deny list for `settings.json`; even applied, it matches command text rather than the program underneath, so it cannot stop `/bin/rm -rf`, `bash -c '...'`, or a script that deletes files through its own code.

**Builder runs with `acceptEdits`.** File writes never prompt. Bash commands still can, which is where unattended fan-out tends to stall.

**Effort is not supported on Haiku.** Drop the `effort:` frontmatter line from any agent you point at a Haiku model.

**Fan-out does nothing for single-artifact work.** Parallel Builders need slices that own different files. A document, a video script, a single config file: each is one artifact and inherently one Builder.

**The helpers refuse; they do not intercept.** `capstan-claim` refuses a second owner, a sixth fix dispatch, or a fourth Builder only when the Architect calls it. Nothing stops an agent from running `rm -rf` or spawning a Builder by hand.

**The board read has been tested against a mock, not a live board, since the helper landed.** `capstan-board`'s `capstan-tracker` completeness check, repository scoping and diff are exercised by its own tests against a mock `gh` built from gh 2.101.0's own JSON shape. The first real migration through it is the integration trial still owed.

**The knowledge-base note is reviewed whole, when there is one.** The note is never committed, so it has no fixed point to diff against, and the Reviewer reads the whole file rather than a diff.

More: [document home and vault layouts](docs/document-home.md), [the tracker surface](docs/tracker.md), [the knowledge base](docs/knowledge-base.md), [upgrading and moving the marketplace](docs/upgrading.md), [installing by hand](docs/manual-install.md), [what CI runs](docs/checks.md).

## Licence

MIT. See [LICENSE](LICENSE). Take it, change it, ship it.

Some skills here are not ours. Every one is MIT, and every one is redistributed with its own licence and a `CREDIT.md` in its folder recording exactly what changed:

- [`skills/writing-for-agents/`](skills/writing-for-agents/): `SKILL.md` and `SKILL-MECHANICS.md` by [Matt Pocock](https://github.com/mattpocock/skills). `AUDIT.md` beside them is ours.
- [`skills/unslop/`](skills/unslop/): `SKILL.md` by [Lauren Tan](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop), via cursor/plugins. Two lines changed.
- [`skills/walkthrough/`](skills/walkthrough/): `template.sh` by [Matt Pocock](https://github.com/mattpocock/skills), forked: the library stops on closed input, validates keys, and refuses multi-line values, with every change listed in its `CREDIT.md`. `SKILL.md` beside it is ours, written fresh around the library.
- [`skills/diagnosing-bugs/`](skills/diagnosing-bugs/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Three lines repointed at Capstan's own paths and at `walkthrough`.
- [`skills/codebase-design/`](skills/codebase-design/): `SKILL.md`, `DEEPENING.md` and `DESIGN-IT-TWICE.md` by [Matt Pocock](https://github.com/mattpocock/skills). One line repointed; the other two files are byte-identical.
- [`skills/to-questionnaire/`](skills/to-questionnaire/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Two changes: the invocation flag, and where the document lands and where its answers go.
- [`skills/resolving-merge-conflicts/`](skills/resolving-merge-conflicts/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Two changes: where a hunk's intent is found, and one exception to never aborting.

Beyond those, nothing is vendored, though some ideas are borrowed, all from [Matt Pocock](https://github.com/mattpocock/skills). The prose is ours; the mechanics are his.

- The frontier in `interview`: a design tree, where a question depending on an open question waits for a later round. Sharpened from `grilling`.
- The `next` section in `CLAIM.md`: what the run after this one picks up, written for the agent that resumes rather than the person at the gate. From `handoff`, sized down to a field in a file that already exists.
- The `unformed` status in the decision log: an area nobody can phrase a question about yet. His fog of war from `wayfinder`, without the issue tracker it is charted on.
- Two moves in `interview`: challenging a term against the glossary rather than only within the session, and inventing an edge-case scenario when a relationship between concepts stays vague. From `domain-modeling`, minus its file layout.

<a href='https://ko-fi.com/G5C025L5FG' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
