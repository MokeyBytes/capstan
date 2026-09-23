---
capstan_type: decision-record
---

# 0006. Rotate the decision log

**Status**: accepted
**Date**: 2026-09-23

## Context

`decisions.md` reached 882 rows and about 392 KB, roughly half a context window to read whole. 883 records `external-review`'s own Architect skipping that whole read and working from a partial one instead: the last 100 rows, every `open`, `assumed` and `unformed` row, a handful of named rows, and a grep for broad terms. That override is the risk that item 1 of `external-review` was set to remove, by making a narrower read the normal one rather than an exception one operator approved once.

## Decision

The active log keeps every `open`, `assumed` and `unformed` row, plus the 50 most recent rows of any status. Everything else moves out to `decisions/archive/decisions-<lo>-<hi>.md` in the document home, one append-only file per rotation, newest-first and byte-identical to what left the active log. Rotation runs in phase 4, after the Courier, once the active log passes 100 KB, and it runs through a helper, `capstan-log`, rather than an Architect moving rows by hand. Row numbers stay global: a new row takes the highest number across the active log and every archive, plus one. Archived rows are never edited, their status cell included. A row superseding an archived one opens with `Supersedes NNN.` and leaves the archived row exactly as it stood. An archived row's status cell reading `superseded by NNN` is authoritative. Any other archived status may be stale, so the Architect runs `capstan-log find` and reads each row it lists to confirm it supersedes, since `find` matches text rather than intent.

## Alternatives

**One file forever**, what the log did until now. Rejected: 883 already shows an Architect skipping the whole read at 392 KB, and the file only grows from there.

**One note per decision.** Rejected once already, at 223: a decision log's value is scanning every row on one screen, and a note per row is exactly the bloat `decision-record` exists to prevent.

**Rotation by fixed number ranges**, every 200 rows regardless of status, say. Rejected: `interview` and `brief` read only `open` and `assumed` rows from the active log, never the archive, so a fixed range could carry one of those rows into the archive before it resolves and hide it from both for good. Rotating by status instead is what keeps every `open`, `assumed` and `unformed` row on the active page regardless of its number.

**Prose-only rotation**, an Architect moving rows by hand instead of a helper doing it. Rejected per 898: this is a mechanical move of table rows over hundreds of rows, the same shape of operation where an agent's ad hoc script collapsed an empty field (879), and the claim that matters here, every row byte-identical with no number lost or doubled, is one a test can hold and prose cannot.

## Consequences

`decision-record`'s "update both files" rule for a superseding decision now has one exception: an archived row keeps its old status forever, and only the new row records the relationship. That is the price of an archive nothing ever rewrites.

History no longer sits inside the one file an agent reads by default. Anyone checking whether an area was ever decided also greps the archive, by area terms, the same way 883's override already did over the whole log. A decision phrased without the terms someone thinks to grep for can still be missed.

## Revisit when

An Architect misses a binding archived decision that a grep by area terms would not have found. That is the failure this design accepts as the cost of keeping the active log small, and it is the signal that the trade stopped paying off.
