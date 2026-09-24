---
name: agent-models
description: Tune the crew's model and effort settings for Claude and Codex — scout both current lineups, propose a table with a cited reason per row, and write the change only once you say yes.
disable-model-invocation: true
argument-hint: "absolute path to the repository (defaults to the current one)"
---

# Agent models

A fourth front door beside `effort`, `quick` and `setup`, operator-invoked only. One run, no claim, no gates (964): it scouts, proposes, stops, and on your yes it writes. Nothing here persists between separate invocations — replying "yes" later in the same conversation continues the run; a fresh invocation of `/capstan:agent-models` scouts and proposes again from scratch.

Do not answer from memory. Every model name, alias, id and effort value below is discovered fresh each run, from a Scout dispatched in this run, never carried over from a previous one or copied out of a spec or a decision record.

## Precondition: establish the working copy

Take the absolute path from the argument the operator typed after `agent-models`. If they typed none, use the session's own working directory. Confirm it is a repository:

```bash
git -C <abs-path> rev-parse --show-toplevel
```

Everything below refers to that path as `<working copy>`, addressed by absolute path, `git -C <working copy>` included, never by changing directory.

Then read `<working copy>/.claude-plugin/plugin.json`. If it exists and its `name` field is `capstan`, this run is inside **Capstan's own repository**: the writes below land directly in `agents/*.md`, `README.md` and `DESIGN.md`. Any other working copy — including one with no such file at all — is **a project with the plugin installed**, and the writes below are project-local overrides instead.

## Read the current seats

Resolve the installed plugin's own folder from this skill's own base directory, not from a guess: `../../agents/` and `../../.claude-plugin/plugin.json` sit beside this file wherever the session loaded it from. Read every `agents/<role>.md` there and the plugin version in that `plugin.json` — this is what an override's marker is compared against below, and, for a project with the plugin installed, the source an override copies from.

In Capstan's own repository, read `<working copy>/agents/*.md` instead of the installed copy: that file is the plugin's own source and may already be ahead of the cached install mid-development.

Read what already exists in the target, too: every `<working copy>/.claude/agents/*.md` carrying the `capstan-override` marker described below, and every `<working copy>/.codex/agents/capstan-*.toml`. Note the plugin version each one's marker names.

## Scout both lineups

Fire two Scouts in parallel — `capstan:scout` or `scout`, whichever your install produced:

- One establishes the current **Claude** lineup: the models available, their aliases, and which effort levels each supports, including its default.
- One establishes the current **Codex** lineup: model ids, the `model_reasoning_effort` values each supports, and the file format Codex reads for a custom agent.

File each return verbatim, unsummarised, at `<working copy>/.capstan/agent-models/claude-models.md` and `<working copy>/.capstan/agent-models/codex-models.md`. This folder is scratch: the write step below deletes it once every file it proposed is written. Add `.capstan/agent-models/` to `<working copy>/.gitignore` if no existing line already covers it — the repository's own ignore rule reaches only `.capstan/effort/`, and one more line is simpler than borrowing an Effort's scratch for a run that holds no claim on anything.

## Propose

One table per platform, seat by seat: seat, current value, proposed value, cited reason. Every row's reason cites the Scout return that supports it, not this skill's own say-so.

Apply these standing rules to every row:

- Quality first on the Reviewer alone. Scout and Courier run as cheap as their output allows (961).
- The top tier on either platform — Fable on Claude, Astra on Codex — only on a capability gap the Scout's return actually names. Never on preference, never by default (961, 971).
- Never propose an `effort` or `model_reasoning_effort` line on a model the Scout's return says does not support one. Haiku is the standing example on Claude (969); Codex has its own gaps per lineup and per model.
- Name every Claude model by alias (`opus`, `sonnet`, `haiku`, `fable`), never a pinned id (962). Confirm every Codex id against the Scout's return, or platform.openai.com or the Codex models page directly, at run time — never take one from this skill's own text, from any spec, or from any decision record read above (971).

Beside the tables, flag any Agent override or Codex file read above whose marker names a plugin version other than the one just resolved: it was copied from an older install and its body may already have drifted from what ships today.

**End the run here.** Post both tables and the flags, then stop. Write nothing below this line until the operator answers yes.

## On yes

**Capstan's own repository.** Edit only the frontmatter of `agents/<role>.md` for every seat the table changed, and the same values in `README.md`'s "What this costs" section and in `DESIGN.md`'s role table. Nothing else changes, and no Codex TOML is ever written or committed here (970).

**Any other project.** The operator picks which seats get a Claude override — not necessarily every seat the table changed. For each one, write `<working copy>/.claude/agents/<role>.md`: a copy of the installed plugin's `agents/<role>.md` body (973), with its `model` and `effort` frontmatter lines replaced by the proposed values, and this line first in the body, immediately after the closing `---` of the frontmatter:

```
<!-- capstan-override: capstan@<plugin version> agents/<role>.md -->
```

For all four seats, regardless of which got a Claude override, write `<working copy>/.codex/agents/capstan-<role>.toml`, its own marker as the file's first line (970, 971):

```toml
# capstan-override: capstan@<plugin version> agents/<role>.md
name = "capstan-<role>"
description = "<the role's own one-line description>"
developer_instructions = """
<the agent's body, inline, verbatim>
"""
model = "<Codex id confirmed above>"
model_reasoning_effort = "<value confirmed above>"
```

Scout's and Reviewer's files additionally carry `sandbox_mode = "read-only"`.

## Record and recommend

Where the project has a Capstan document home, write one decision row naming what changed and why (975). Resolve the document home exactly as `setup`'s "The ask" section reads `capstan-document-home`: unset or `default` means `<working copy>/.capstan/`, an absolute path means that path, and a project carrying neither `CLAUDE.md` nor `AGENTS.md` at all has no document home and gets no row.

Close with one line recommending a model and effort for the Architect's own session (966). Never write it into any file — no frontmatter governs a session, only a subagent.

## What this run refuses

- Fable or Astra on any seat without a capability gap the Scout just cited.
- An `effort` or `model_reasoning_effort` line on a model that does not support one.
- A settings key, a hook, or any mechanism for model selection other than the files this skill edits or creates directly.
- Editing the installed plugin's own cached files. Every write lands in the working copy itself, or in a project's own `.claude/` or `.codex/`.
- Committing Codex TOML inside Capstan's own repository.
