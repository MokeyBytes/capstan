---
capstan_type: decision-record
---

# 0007. Move the GitHub board surface to a second plugin

**Status**: accepted
**Date**: 2026-09-23

## Context

Every install of Capstan carried the GitHub Projects v2 tracker surface. That meant the board reference, the `capstan-tracker` helper, the board steps of `setup` (the surface question, the scope check, and both migrations), and their tests, fixtures and mock `gh`. Most projects never set `capstan-tracker`, and this repository left its own board at 879. An external review asked whether the surface belongs in core. The operator settled the question at gate 1 of `external-review` (886, 896).

## Decision

The surface moves to `capstan-board`, a second plugin listed in the same marketplace, `source: "./plugins/capstan-board"`. It declares core as a dependency and starts at 1.0.0 (899). It carries two skills. `tracker` is model-invoked and holds the board reference and `bin/capstan-tracker`. `setup` is operator-invoked as `/capstan-board:setup` and holds the surface question, the scope check and both migrations. Core keeps reading `capstan-tracker`. A `github:` value whose board skill cannot load stops with `surface not installed: install capstan-board@bytesnation`, then says to reload plugins and re-run the phase (942). An effort checks this before taking its claim. The board is plugin-install only (943). Core goes to 3.0.0.

## Alternatives

**Keep it in core.** No project breaks on upgrade, but every install carries about 600 lines of board procedure and helper that only board users run. Core `setup` also keeps asking a question most operators never need.

**Remove it.** Core gets smaller still. But the migration back off a board lives in the code that would be removed, so anyone still on a board would be stranded with no supported way home.

## Consequences

Core is smaller, and core `setup` asks only where the document home lives. A project whose `capstan-tracker` names GitHub stops on upgrade until `capstan-board` is installed, which is why this is a major version. A plugin cannot read another plugin's files, so the board skills carry their own copy of the document-home key rules. Keeping that copy in step with core is now a maintenance cost, and it was the first review's blocking finding (941). The root plugin, `source: "./"`, also ships the nested plugin's files in its cache copy. That is harmless, but the layout is untidy. A manual install cannot have the board at all, because its `setup` skill would collide with core's.

## Revisit when

A third surface is proposed, and the board's pattern either holds for it or needs a shared layer the two plugins can both read. Or a manual-install user asks for the board.
