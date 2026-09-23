# Benchmark results

Filled in from real benchmark runs of `bench/PROTOCOL.md`, one row per arm per repository. Every cell starts blank. A blank cell means the arm has not measured it yet. It is never filled with a guess. "n/a" means the cell does not apply to that arm, such as the baseline arm's gate count and review-findings cells, which have no gates and no review step by definition. A blank and "n/a" mean different things: never write one for the other.

| Repository | Issue | Arm | Pinned commit | Tokens (model: in/out/cache-write-5m/cache-write-1h/cache-read) | Cost (model: $) | Wall-clock time | Gates reached | Operator interventions | Declared checks pass? | Review findings that caught a real defect | Transcript path |
|---|---|---|---|---|---|---|---|---|---|---|---|
| | | baseline | | | | | | | | | |
| | | capstan | | | | | | | | | |
| | | baseline | | | | | | | | | |
| | | capstan | | | | | | | | | |
| | | baseline | | | | | | | | | |
| | | capstan | | | | | | | | | |

## Notes

Record anything that does not fit a cell here: a repository swapped for the spare, a pre-flight failure, a check that could not run and why.
