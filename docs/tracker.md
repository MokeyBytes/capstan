# Tracker surface

Slice state lives in `tracker.md` in the [document home](document-home.md) by default: one row per slice, carrying the effort it belongs to, the slice itself, its status and the commit that merged it. Set `capstan-tracker` and slice state moves to a GitHub Projects v2 board instead: an issue per slice, a milestone per effort, a custom status field, and the merge commit posted as a comment once the slice lands.

The value is for people, not agents. An agent building or reviewing a slice already has `tracker.md` open, offline, at the commit it is reading. A board gives a teammate something to open without cloning the repository, and an issue that closes the moment its slice merges or drops, with the merge commit recorded on it as a comment. [`DESIGN.md`](../DESIGN.md#why-the-tracker-gained-a-second-surface) says more about that trade, including the cost it does not solve: a board has no fixed point the way a committed file does.

## Installing the board

The board is a second plugin, `capstan-board`, not part of core:

```bash
claude plugin install capstan-board@bytesnation
```

Restart Claude Code, then run `/capstan-board:setup` in the repository. It asks for the GitHub project number, checks the token can reach Projects v2, and hands you to a walkthrough for `gh auth refresh -s project` if it can't. It writes `capstan-tracker` only once you approve the migration.

`capstan-board` is a plugin-install-only feature. There is no manual-install form: a `tracker` skill copied under `~/.claude/skills/` would collide with core's own `setup` skill sitting there under the same name, and there is no `capstan-board@bytesnation` namespace to invoke without the plugin. See [manual install](manual-install.md) for what a manual install does carry.

If `capstan-tracker` names a GitHub surface and the plugin is not installed, `effort` stops before the interview rather than guessing:

```
surface not installed: install capstan-board@bytesnation
```

Install the plugin, reload plugins, and re-run the phase that stopped. Do not run `/capstan-board:setup` for this: that command is for changing which surface is in force, and a project reaching this stop already has one configured.

```markdown
capstan-tracker: github:your-org/your-repo#3
```

Leave the key out and nothing changes. Every project has run on `tracker.md` since the tracker existed, and unset keeps it that way for anyone who never asks.

## What it costs

Four things worth knowing before you turn this on:

- **A public repository asks for confirmation on every write.** Every write to the board there is third-party-visible, so the operator confirms it, the same as any other third-party-visible action; a private repository writes unattended, the same as `tracker.md` always has. The tracker is written on every slice transition, so this is the cost that changes daily operation most.
- **GitHub unreachable stops the run.** No retry, no backoff, no bounded wait. A rate limit and an expired token end it the same way.
- **Reading the full tracker costs more.** `tracker.md` is one file read. A board reconstructs the effort, the slice and the status in one call, but the merge commit lives in a comment on each issue, so a full read costs one call plus one more per merged slice. The read is complete or refused: it checks what came back against the count the board reports, and a board it cannot read whole stops the run rather than passing off part of it as all of it.
- **Moving onto GitHub deletes your `tracker.md`.** Choosing GitHub on a project that already has a `tracker.md` carries every row onto the board as an issue, then deletes the file once a read of the board back matches it row for row, status and merge commit included. `/capstan-board:setup` describes the batch first, how many rows and how many milestones, and asks for one approval covering the whole thing, before either key is written, so refusing writes no key and leaves the rows where they are. That delete needs the operator's approval on a public repository and a private one alike; the per-write confirmation above is the only part that depends on whether the repository is public.

## Moving back

Run `/capstan-board:setup` again and choose the default. It reconstructs `tracker.md` from the board and tears the board down, on your approval, the same shape in reverse:

- **It needs your approval, the same way.** The skill describes the batch first, how many rows and how many milestones are on the board, before closing or removing anything. Decline and it tells you the same thing: how many rows are on the board and that leaving them there strands them. The run stops there and writes no key.
- **It closes every issue and removes every item from the board.** That removal is the only delete the reverse makes, and it starts only after the rebuilt `tracker.md` has been read back against the board and matched row for row. The issues stay, closed rather than gone. The board stays too, untouched apart from the removals. Each milestone closes, once every row under it is back, rather than being deleted.
- **An interrupted run can leave rows on both surfaces until you run `/capstan-board:setup` again.** That is deliberate. A row nobody can get back is worse than a duplicate a second run clears up.

## Upgrading from 2.x

Before 3.0.0, the board lived in core. A project whose `capstan-tracker` already named a GitHub project must install `capstan-board@bytesnation` after upgrading core, or its next effort stops at the message above. See [upgrading](upgrading.md).
