---
name: walkthrough
description: Build the one-time script that carries the operator through a manual procedure — a vendor dashboard, a hardware step, an account migration — stage by stage, confirming each and capturing what comes back. Steps the agent can complete unattended don't need this. Use for a human task step.
---

# Walkthrough

An Architect reaches for this the moment an effort hits a step only a person can do: a click sequence in someone else's console, a physical action, a change to an account that lives outside this repository. Pasting a paragraph of instructions and hoping the operator keeps the order straight, catches every value, and knows which parts are secret is what this discipline replaces with a single script that does that work for them.

`template.sh` in this folder supplies the machinery behind that script. See [CREDIT.md](CREDIT.md) for where it came from and what Capstan changed in it.

## Read the procedure before writing a stage

Two shapes of procedure come up often enough to name. One is gathering values a service already holds and a config already expects: check the `.env` file and its siblings, the README, any compose file, and whatever `secrets.*` or `vars.*` names turn up in CI, since each one names a value this walkthrough exists to produce. The other is carrying something across a boundary it cannot come back from, cutting a domain over, retiring an account, promoting an environment, where what matters is naming which parts of that crossing cannot be undone.

When the interface a stage depends on is unclear, check the vendor's own documentation rather than guess at a button that may not exist. A stage invented from memory gets discovered wrong only once the operator is staring at the real page, and that costs more than admitting the gap up front.

## Confirm the stage order with the operator

Before a single `stage()` gets written, show the operator the ordered list you intend to build and what each entry is expected to hand back. Let them reorder, cut, or add before any of it is authored. Catching that after the fact means rewriting stages that already worked.

## Author each stage against the library

Everything above the `STAGES` marker in `template.sh` is fixed. Never edit it. That is what makes the result feel the same no matter which procedure produced it, and since the agent has to open the file to write stages below the marker anyway, read the header comments there rather than have this document repeat them.

What varies stage to stage is which calls it reaches for:

- `ask` for a value the operator can read straight off a screen; `ask_secret` when it must never be visible. Enter keeps a value already in `.env`; Enter with nothing there asks before accepting an empty value, so an empty result is always one the operator chose.
- `write_env` when a value belongs in the local `.env`; `set_secret` or `set_var` when it belongs to a repository hosted elsewhere. A key is a variable name, `[A-Za-z_][A-Za-z0-9_]*`, and a value is one line: the library refuses a name outside that shape and a value holding a line break before it touches the file, so a stage that needs a multi-line value, a PEM key say, hands the operator a path to save it at rather than a value to paste.
- `pause` for a step with nothing to capture; `confirm` as a yes/no gate ahead of something risky.
- `open_url` right before the `ask` or `ask_secret` that captures what the opened page shows, so the operator lands on the page before being asked for the value it produces. Open it after the ask only when the value being asked for is itself what unlocks the page, such as a link that arrives by email.

Set `TOTAL_STAGES` to the count of stages actually written. The template's example block ships it at `1`, and an author who replaces the stages without updating that number gets "Stage 4 of 1" on every screen the operator sees.

Before any stage calls `write_env` on a secret, confirm the working directory's `.gitignore` actually covers the `.env` file about to be written. During an effort that directory is a Builder's worktree, and nothing in the library checks this on its own.

## Two guards before anything leaves this machine

`set_secret` and `set_var` push a captured value straight to whatever GitHub repository `gh` resolves from the current directory, with no confirmation and no statement of which repository that is. The library runs under `set -euo pipefail`, so `confirm` called bare on the line above a write is not a gate: `confirm` is a predicate, and a decline exits the entire script before the write, before `finish`, and before every stage still to come, with no record of which values already landed. A stage that calls `set_secret` or `set_var`, or that writes anywhere outside the local `.env`, or that does anything that cannot be undone, wraps the write in `if confirm "..."; then ... fi` instead, so a decline skips that one write and the run continues on to its `finish` summary.

That confirm names the target, and the target it names has to be the one the script will actually use, not one the author typed. `set_secret` and `set_var` write to whatever `gh` resolves from the operator's working directory at run time, which is not necessarily the repository an author had in mind while writing the stage. Print the resolved target before asking, for example with `gh repo view --json nameWithOwner -q .nameWithOwner`, so the question reads "Push API_KEY to acme/widgets?" using the name the script just looked up, not a literal it was told to say. A prompt naming the wrong repository is worse than a prompt naming none, since it reads as a check that already happened. Secrets and anything a third party will see are the operator's call, every time, never the agent's to wave through on the script's behalf.

The agent that authors a walkthrough never runs it. With no terminal attached, the first prompt finds its input closed, and the library stops there, saying so and listing what was already written, rather than reading silence as a value. That is the guard, not a way to test the script: a run that stops at stage one proves nothing about stage two. Trace the script by reading it. The operator is the one who executes it.

## Hand it off

A walkthrough is generated for one procedure and discarded with the rest of the effort's scratch once the operator has run it. Nothing about a script built for a single pass needs to outlive the run it was built for.

**Done when** the script is written, every stage naming its URL or action, where its value lands, and whether that value is secret; `TOTAL_STAGES` matches the stages actually present; any secret write checked its `.gitignore` first; every stage that calls `set_secret` or `set_var`, writes outside the local `.env`, or does anything that cannot be undone wraps that write in `if confirm "..."; then ... fi` and, before asking, prints the target the script resolves at run time rather than one the author typed; and the finished script has been handed to the operator to run themselves.
