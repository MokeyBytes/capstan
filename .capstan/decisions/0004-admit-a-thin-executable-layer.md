---
capstan_type: decision-record
---

# 0004. Admit a thin executable layer: three helpers, their tests, and CI

**Status**: accepted
**Date**: 2026-09-22

## Context

Capstan's rule since the first commit has been no operating layer: no scripts, no schemas, no hooks, prose only, because prose survives a model change and code has to be maintained. The decision log now holds the cases where prose did not survive contact with a run. 828 recorded that the declared tracker read truncates at thirty and left the instruction as it was. 792 recorded a claim two phases out of date. 517 and 808 recorded review returns not filed under a rule that had said to file them for months. A review of 86c2f91 then found seven defects in the same class, and the ones that matter are not wording: a check-then-write claim that two sessions can both pass, a delete written as a wildcard, one field in the claim doing two jobs, a version committed after the verification that was supposed to cover it, and a fan-out with no ceiling. Each is a rule an agent can read correctly and still get wrong, because the failure is in the sequence of operations rather than in the intent.

The operator authorised small executable helpers, regression tests and CI for this effort, overriding the prohibition for exactly this scope.

## Decision

Three helpers live in `skills/effort/bin/`, travel with the skill under either install, and are the only code the workflow runs: `capstan-claim` takes and records ownership, holds the baseline and the checkpoint apart, records the verified commit, and counts dispatches against two limits; `capstan-scratch-clean` deletes exact, verified paths; `capstan-tracker` reads a board completely or not at all and diffs it against `tracker.md`. The walkthrough library is forked to stop on closed input, per 0005. `tests/` holds behavioural tests for all of it and `.github/workflows/checks.yml` runs them on Linux and macOS with no credentials and no network.

A helper is admitted only where a rule has already failed on the record and the fix is one deterministic operation: take a lock, count, enumerate, delete a named path. Judgement stays in the skills. A fourth helper earns its place the same way, with the failure written in the log first.

## Alternatives

**Keep prose only and sharpen the wording.** Rejected. The wording for filing review returns was sharpened three times and failed a fourth. A check-then-write claim cannot be made atomic by describing it better.

**A full validation layer: schemas for every artifact, hooks on every write, a scheduler for the fan-out.** Rejected, and still refused. Each of those has to be maintained to keep the workflow alive, which is the cost the original rule was protecting against. The helpers here are called by the Architect when the skill says to, and the workflow still runs without a scheduler: a Builder returning is what frees a place.

**Put the helpers at the repository root.** Rejected because a manual install copies `skills/` and would leave the helpers behind. `skills/effort/bin/` is reached from the skill's own location under both installs.

## Consequences

Capstan now ships code that has to work on the operator's machine: bash 3.2, since that is what macOS ships, `git`, and `gh` where the board is in use. `jq` is needed only by the tests. A helper and the instruction that calls it can drift apart, and the tests are what hold them together; a change to either without the other is a review finding.

The README's claim that nothing here needs code running to stay alive is no longer true as written and is qualified rather than dropped: the run still needs no daemon, poller or hook, and a helper does nothing until an agent calls it.

Two instructions changed shape rather than wording. The claim is taken with `mkdir`, so a second session is refused rather than warned, and the fix-dispatch count is held in the record rather than in free text, so a limit can refuse rather than remind.

## Revisit when

A helper needs a dependency beyond bash, git and gh, or a fourth one is proposed without a logged failure behind it. Either is the operating layer arriving by increments, and the answer is to simplify the rule it serves rather than grow the layer.
