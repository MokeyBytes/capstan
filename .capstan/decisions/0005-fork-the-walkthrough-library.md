---
capstan_type: decision-record
---

# 0005. Fork the walkthrough library rather than vendor it verbatim

**Status**: accepted, supersedes 0002
**Date**: 2026-09-22

## Context

0002 vendored Matt Pocock's `template.sh` byte-identical and named the condition for revisiting it: the library needing Capstan-specific behaviour upstream will not take, at which point the fork should be declared rather than drift. That condition arrived as a defect. Every prompt in the library read stdin with `|| true`, so a closed input produced an empty value, `write_env` wrote it, `set_secret` pushed it, and the summary printed success. `write_env` also accepted a value with a line break and left its second line behind on the next replace, and nothing validated a key.

The failure sits inside the functions a stage calls, so it cannot be wrapped from below the marker without every stage author knowing to.

## Decision

`template.sh` is a declared fork. The library above the `STAGES` marker stops on closed input and says what was already written, validates keys, refuses a value holding a line break before touching the file, keeps every other line of `.env` in place, and refuses to push an empty secret. `CREDIT.md` lists each change, and `tests/test_walkthrough.sh` covers each one. The stages section below the marker stays upstream's. The licence and the credit stay.

## Alternatives

**Report upstream and wait.** Worth doing and not sufficient: the defect is live in every walkthrough generated meanwhile, and the refresh contract in `CREDIT.md` already assumed a diff before replacing.

**Reimplement the library.** Rejected at 0002 and still: the value is the working machinery, and the changes here are a few dozen lines against it.

**Guard in the stages instead.** Rejected. Every author would have to remember it, which is the failure mode the library exists to remove.

## Consequences

A refresh from upstream is no longer a re-fetch. It is a re-fetch, the change list re-applied, and the tests run. The tests are what make that mechanical rather than a merge from memory. `walkthrough`'s "never edit above the marker" rule still holds for authors; only this record and its credit file change the library.

## Revisit when

Upstream ships equivalent handling of closed input and invalid values, at which point the fork collapses back to a verbatim copy and this record is superseded.
