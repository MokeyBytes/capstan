---
capstan_type: decision-record
---

# 0002. Vendor the walkthrough library rather than write one

**Status**: superseded by 0005
**Date**: 2026-08-21

## Context

`effort` has always said that a human task step should produce "an interactive shell script that walks through the steps one at a time, waits for confirmation at each, and captures any values that come back." It says nothing about how, so every Architect improvises the script from scratch. The one generated during the rename effort handled roughly a third of what the instruction implies, and handled it badly.

Matt Pocock's `wizard` skill ships `template.sh`: 204 lines that already solve stage progress, confirmation gates, cross-platform URL opening including WSL, hidden entry for secrets, idempotent `.env` upserts, and `gh secret` writes. The skill's own prose is mostly instructions to author stages below a marker and never hand-edit the library above it.

This repository already vendors two files from that source under MIT with a `CREDIT.md`, so the posture exists.

## Decision

`template.sh` is vendored verbatim, with `CREDIT.md` and `LICENSE` beside it, exactly as `writing-for-agents` is. The prose around it is written fresh in Capstan's voice as the `walkthrough` discipline.

## Alternatives

**Reimplement it.** Rejected. Molding prose is one thing; molding 204 lines of working bash means rewriting it worse, and the existing hand-rolled script is the evidence. The value of this skill is the library, not the instructions.

**Keep the current prose-only instruction.** Free, and leaves a documented capability that has never once been delivered properly.

**Drop the whole idea.** Would mean human task steps stay improvised, which is the status quo that prompted this.

## Consequences

Capstan ships executable code for the first time, which makes the README's "Plain markdown. No scripts" line false as written. Decision 86 qualifies that line rather than dropping it: the rule Capstan actually holds is no *operating layer*, and a walkthrough is generated per use, handed to a person, and thrown away. That distinction was always implied and never stated.

A vendored file also means an upstream to track. `CREDIT.md` records exactly what was changed so a refresh is mechanical, which is the same contract the other two vendored files carry.

## Revisit when

The library needs Capstan-specific behaviour that upstream will not take, at which point the fork is real and should be declared rather than drifting quietly.
