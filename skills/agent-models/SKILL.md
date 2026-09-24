---
name: agent-models
description: Tune the crew's model and effort settings for Claude and Codex — scout both current lineups, propose a table with a cited reason per row, and write the change only once you say yes.
disable-model-invocation: true
argument-hint: "absolute path to the repository (defaults to the current one)"
---

# Agent models

A fourth front door beside `effort`, `quick` and `setup`, operator-invoked only. Two runs and one gate, holding no claim: the first run scouts and proposes, then ends at the gate. Your yes, naming the seats that get a Claude override, starts the second run, which writes. Nothing here persists between separate invocations — a fresh invocation of `/capstan:agent-models` scouts and proposes again from scratch, rather than resuming a gate an earlier invocation left open.

Do not answer from memory. Every model name, alias, id and effort value below is discovered fresh in the run that uses it, from a Scout dispatched in that run.

## Precondition: establish the working copy

This skill needs a plugin install: it reads the installed plugin's own `.claude-plugin/plugin.json` to learn the current version, which the override marker names and the drift flag below compares against, and a manual install has no such file for it to read. Resolve `../../.claude-plugin/plugin.json` from this skill's own base directory: two directories up from this file, at the plugin's own root, wherever the session loaded it from. If that path does not exist, stop: this session is a manual install, `agent-models` needs the plugin install instead, and `docs/manual-install.md` says why.

Take the absolute path from the argument the operator typed after `agent-models`. If they typed none, use the session's own working directory. Confirm it is a repository:

```bash
git -C <abs-path> rev-parse --show-toplevel
```

Everything below refers to that path as `<working copy>`, addressed by absolute path, `git -C <working copy>` included, never by changing directory.

Then read `<working copy>/.claude-plugin/plugin.json`. If it exists and its `name` field is `capstan`, this run is inside **Capstan's own repository**: the writes below land directly in `agents/*.md`, `README.md` and `DESIGN.md`. Any other working copy — including one with no such file at all — is **a project with the plugin installed**, and the writes below are project-local overrides instead.

## Read the current seats

Resolve the installed plugin's own folder from this skill's own base directory, not from a guess: `../../agents/` and `../../.claude-plugin/plugin.json`, two directories up from this file, at the plugin's own root, wherever the session loaded it from. Read every `agents/<role>.md` there and the plugin version in that `plugin.json` — this is what an override's marker is compared against below, and, for a project with the plugin installed, the source an override copies from.

In Capstan's own repository, read `<working copy>/agents/*.md` instead of the installed copy: that file is the plugin's own source and may already be ahead of the cached install mid-development.

Read what already exists in the target, too, for all four roles: `<working copy>/.claude/agents/<role>.md`, whether or not it carries the `capstan-override` marker described below, and `<working copy>/.codex/agents/capstan-<role>.toml`, the same either way. Note the plugin version each marked one names — a seat carrying a marked override is currently running that override's own `model` and `effort`, not the installed plugin's. Name any unmarked file found at either path beside the proposal tables below: it is a file this skill did not write, and On yes below writes that seat's file only where the operator names that seat despite the warning.

## Scout both lineups

Fire two Scouts in parallel, spawned as [`effort`'s crew section](../effort/SKILL.md#the-crew) says.

- One establishes the current **Claude** lineup: the models available, their aliases, and which effort levels each supports, including its default.
- One establishes the current **Codex** lineup: model ids, the `model_reasoning_effort` values each supports, and the file format Codex reads for a custom agent.

Keep each return in this run's own context. Nothing here is written to disk: a proposal row cites the URL the return points to for its claim, not a filed copy of the return.

## Propose

One table per platform, seat by seat: seat, current value, proposed value, cited reason. Every row's reason names the URL the Scout's return cites for that claim, not this skill's own say-so.

Apply these standing rules to every row:

- Quality first on the Reviewer alone. Scout and Courier run as cheap as their output allows.
- The top tier on either platform — whichever model that platform's Scout return names as its most capable, today for example Fable on Claude or Astra on Codex, but check the return rather than this line — only for the Reviewer, and only on a capability gap the Scout's return names. Never on preference, never by default.
- Never propose an `effort` or `model_reasoning_effort` line on a model the Scout's return says does not support one.
- Name every Claude model by the alias its Scout return lists for that family, never a pinned id. Confirm every Codex id against platform.openai.com or the Codex models page, directly or through a return that cites one of those at high confidence; check again, before writing it, any id a return marks medium or low confidence.
- If the Codex return names a required field set or folder different from the one "On yes" below assumes, say so beside the table and write no Codex override this run.

Beside the tables, flag any Agent override or Codex override read above whose marker names a plugin version other than the one just resolved: it was copied from an older install and its body may already have drifted from what ships today.

**End the run here, at the gate.** Post both tables and the flags, then ask the operator to answer yes, naming which seats should get a Claude override — not necessarily every seat the table changed. Write nothing below this line until that yes arrives; the yes starts the second run.

## On yes

**Capstan's own repository.** Edit only the frontmatter of `agents/<role>.md` for every seat the table changed, and the same values in `README.md`'s "What this costs" section and in `DESIGN.md`'s role table. Nothing else changes, and no Codex override is ever written or committed here.

**Any other project.** For each seat the operator named in the yes, write `<working copy>/.claude/agents/<role>.md`, but only where that path is absent or already carries the marker; where it exists unmarked, write it only if the operator named that seat despite the warning raised above, and otherwise leave it alone. The write is a copy of the whole installed plugin file, frontmatter and body together, with only its `model` and `effort` lines changed, plus this line first in the body, immediately after the closing `---` of the frontmatter:

```
<!-- capstan-override: capstan@<plugin version> agents/<role>.md -->
```

A copied `permissionMode` line takes effect here in a way it would not for the namespaced plugin agent, which the plugin loader does not apply that line to. Say this beside the seats picked, so the operator knows the copy is not `model` and `effort` alone in what it does.

For all four seats, regardless of which got a Claude override, and unless Propose already flagged a Codex format mismatch, write `<working copy>/.codex/agents/capstan-<role>.toml` under the same absent-or-marked rule as above, its own marker as the file's first line:

```toml
# capstan-override: capstan@<plugin version> agents/<role>.md
name = "capstan-<role>"
description = "<the role's own one-line description>"
developer_instructions = '''
<the agent's body, inline, verbatim>
'''
model = "<Codex id confirmed above>"
model_reasoning_effort = "<value confirmed above>"
```

Use the literal `'''` form shown, not `"""`: the literal form does not process escapes, so the body lands byte for byte. If a body itself contains `'''`, stop and report rather than writing that file — a literal string cannot hold one.

Scout's and Reviewer's files additionally carry `sandbox_mode = "read-only"`.

## Record and recommend

Before writing anything below, invoke `decision-record`, taking the row's number from `capstan-log next <document home>`, at `../effort/bin/` from this skill's own base directory.

Resolve `<document home>` exactly as [`setup`'s "The ask"](../setup/SKILL.md#the-ask) resolves `capstan-document-home`. Write the decision row only where `decisions.md` already exists at that resolved home; where it does not, write no row, and say so in the close below.

Close with:

- one line recommending a model and effort for the Architect's own session — never written into any file, since no frontmatter governs a session, only a subagent;
- where any override was written, tell the operator to start a fresh session rooted in the working copy before the next `effort` or `quick` runs there: the crew's spawn rule only spawns an unscoped role name for an override the session has already loaded.

## Done when

- every seat named in the yes carries a file whose body opens with the marker and whose frontmatter differs from the installed file only in `model` and `effort`;
- every Codex override written parses as TOML and opens with the marker comment;
- the decision row is written, or the close states that the resolved document home has no `decisions.md` to write it into.

## What this run refuses

- An `effort` or `model_reasoning_effort` line on a model that does not support one.
- A settings key, a hook, or any mechanism for model selection other than the files this skill edits or creates directly.
- Editing the installed plugin's own cached files. Every write lands in the working copy itself, or in a project's own `.claude/` or `.codex/`.
- Committing a Codex override inside Capstan's own repository.
