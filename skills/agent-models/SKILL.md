---
name: agent-models
description: Tune the crew's model and effort settings for Claude and Codex — scout both current lineups, propose a table with a cited reason per row, and write the change only once you say yes.
disable-model-invocation: true
argument-hint: "absolute path to the repository (defaults to the current one)"
---

# Agent models

A fourth front door beside `effort`, `quick` and `setup`, operator-invoked only. Two runs and one gate, holding no claim: the first run scouts and proposes, then ends at the gate. Your yes — outside Capstan's own repository, naming the seats that get a Claude override — starts the second run, which writes. Nothing here persists between separate invocations — a fresh invocation of `/capstan:agent-models` scouts and proposes again from scratch, rather than resuming a gate an earlier invocation left open.

Do not answer from memory. Every model name, alias, id and effort value below is discovered fresh by the Scouts this invocation's first run dispatches. The second run writes exactly what the operator approved at the gate.

## Precondition: establish the working copy

This skill needs a plugin install: it reads the installed plugin's own `.claude-plugin/plugin.json` to learn the current version, which the override marker names and the drift flag below compares against, and a manual install has no such file for it to read. Resolve `../../.claude-plugin/plugin.json` from this skill's own base directory: two directories up from this file, at the plugin's own root, wherever the session loaded it from. If that path does not exist, stop: this session is a manual install, `agent-models` needs the plugin install instead, and `docs/manual-install.md` says why.

Take the absolute path from the argument the operator typed after `agent-models`. If they typed none, use the session's own working directory. Confirm it is a repository:

```bash
git -C <abs-path> rev-parse --show-toplevel
```

Everything below refers to that path as `<working copy>`, addressed by absolute path, `git -C <working copy>` included, never by changing directory.

Then read `<working copy>/.claude-plugin/plugin.json`. If it exists and its `name` field is `capstan`, this run is inside **Capstan's own repository**: the writes below land directly in `agents/*.md`, `README.md` and `DESIGN.md`. Any other working copy — including one with no such file at all — is **a project with the plugin installed**, and the writes below are project-local overrides instead.

## Read the current seats

Read every `agents/<role>.md` in `../../agents/` from this skill's own base directory, the plugin root that also holds the Precondition's `.claude-plugin/`, and the plugin version in that `plugin.json` — this is what an override's marker is compared against below, and, for a project with the plugin installed, the source an override copies from.

In Capstan's own repository, read `<working copy>/agents/*.md` instead of the installed copy: that file is the plugin's own source and may already be ahead of the cached install mid-development.

Read what already exists in the target, too, for all four roles: `<working copy>/.claude/agents/capstan-<role>.md`, whether or not it carries the `capstan-override` marker described below, and `<working copy>/.codex/agents/capstan-<role>.toml`, the same either way. Note the plugin version each marked one names — a seat carrying a marked override is currently running that override's own `model` and `effort`, not the installed plugin's. Name any unmarked file found at either path beside the proposal tables below: it is a file this skill did not write; On yes below says when it is replaced.

## Scout both lineups

Fire two Scouts in parallel, spawned as [`effort`'s crew section](../effort/SKILL.md#the-crew) says.

- One establishes the current **Claude** lineup: the models available, their aliases, and which effort levels each supports, including its default.
- One establishes the current **Codex** lineup: model ids, the `model_reasoning_effort` values each supports, and the file format Codex reads for a custom agent.

Keep each return in context for the second run. Nothing here is written to disk: a proposal row cites the URL the return points to for its claim, not a filed copy of the return.

## Propose

One table per platform, seat by seat: seat, current value, proposed value, cited reason. Every row's reason names the URL the Scout's return cites for that claim, not this skill's own say-so.

Apply these standing rules to every row:

- Quality first on the Reviewer alone. Scout and Courier run as cheap as their output allows.
- The top tier on either platform — whichever model that platform's Scout return names as its most capable, today for example Fable on Claude or Astra on Codex, but check the return rather than this line — only for the Reviewer, and only on a capability gap the Scout's return names. Never on preference, never by default.
- Never propose an `effort` or `model_reasoning_effort` line on a model the Scout's return says does not support one.
- Name every Claude model by the alias its Scout return lists for that family, never a pinned id. Confirm every Codex id against platform.openai.com or the Codex models page, directly or through a return that cites one of those at high confidence; check again, before writing it, any id a return marks medium or low confidence. If a check before writing changes an approved id, stop and propose again rather than write it.
- If the Codex return names a required field set or folder different from the one "On yes" below assumes, say so beside the table and write no Codex override on yes.

Beside the tables, flag any Agent override or Codex override read above whose marker names a plugin version other than the one just resolved: it was copied from an older install and its body may already have drifted from what ships today.

**End the run here, at the gate.** Post both tables, the drift flags and every unmarked file named above. Outside Capstan's own repository, say that a Builder override applies `permissionMode: acceptEdits`, which the plugin Builder does not. Then ask the operator to answer yes, naming which seats get a Claude override, not necessarily every seat the table changed, and any unmarked Codex file named above that they want replaced. In Capstan's own repository, ask for a yes to the table's proposed changes as they stand. Write nothing below this line until that yes arrives; the yes starts the second run.

## On yes

Run every recheck that Propose asks for first, before any write.

**Capstan's own repository.** Edit only the frontmatter of `agents/<role>.md` for every seat the table changed, and the same values in `README.md`'s "What this costs" section and in `DESIGN.md`'s role table. Nothing else changes, and no Codex override is ever written or committed here.

**Any other project.** For each seat the operator named in the yes, write `<working copy>/.claude/agents/capstan-<role>.md`. The gate named any unmarked file at that path, so naming the seat is consent to replace it. The write is a copy of the whole installed plugin file, frontmatter and body together, with only its `name`, `model` and `effort` lines changed — `name` becomes `capstan-<role>` — plus this line first in the body, immediately after the closing `---` of the frontmatter:

```
<!-- capstan-override: capstan@<plugin version> agents/<role>.md -->
```

For all four seats, regardless of which got a Claude override, and unless Propose already flagged a Codex format mismatch, write `<working copy>/.codex/agents/capstan-<role>.toml` under the same consent rule as above — an unmarked Codex file is replaced only where the yes names that file — its own marker as the file's first line:

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

Resolve `<document home>` exactly as [`setup`'s "The ask"](../setup/SKILL.md#the-ask) resolves `capstan-document-home`. Where `decisions.md` does not already exist there, write no row, and say so in the close below.

Where it does exist, invoke `decision-record`, take the row's number from `capstan-log next <document home>` at `../effort/bin/` from this skill's own base directory, and write one row naming what changed and why: each seat's old and new values, the files written, and the URL behind each change.

Close with:

- one line recommending a model and effort for the Architect's own session — never written into any file, since no frontmatter governs a session, only a subagent;
- where any override was written, tell the operator to start a fresh session rooted in the working copy before the next `effort` or `quick` runs there: the crew spawns an override as `capstan-<role>` only once the session has loaded it;
- name any unmarked Codex file left in place.

## Done when

- Outside Capstan's own repository, every seat named in the yes carries `capstan-<role>.md` whose body opens with the marker and whose frontmatter differs from the installed file only in `name`, `model` and `effort`;
- every Codex override written parses as TOML and opens with the marker comment;
- In Capstan's own repository, each changed seat's `agents/<role>.md` frontmatter, README's "What this costs" and DESIGN's role table state the approved values, and no `agents/<role>.md` carries the marker;
- the decision row is written, or the close states that the resolved document home has no `decisions.md` to write it into;
- the close carries the Architect-session line, and the fresh-session line wherever an override was written.

## What this run refuses

- An `effort` or `model_reasoning_effort` line on a model that does not support one.
- A settings key, a hook, or any mechanism for model selection other than the files this skill edits or creates directly.
- Editing the installed plugin's own cached files. Every write lands in the working copy itself, or in a project's own `.claude/` or `.codex/`.
- Committing a Codex override inside Capstan's own repository.
