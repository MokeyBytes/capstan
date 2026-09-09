---
name: test-first
description: Red-green-refactor discipline for building one slice at a time. Use whenever code is being written, whether it is a new feature or a bug fix.
---

# Test first

Write a test that fails for the right reason. Make it pass. Clean up. One slice at a time.

The value is not the test file. It is that a failing test forces you to state what "working" means before you have written anything, and a passing test you never saw fail proves nothing at all.

## The loop

**Red.** Write one test at the seam the plan already agreed. Run it. Watch it fail, and read the failure. A test that fails because of a typo, a missing import, or a misconfigured harness is not red, it is broken. The failure message should describe the behaviour that is missing.

**Green.** Write the least code that makes it pass. Not the design you intend to end up with, not the abstraction you can see coming. The least. Run it. Watch it pass.

**Refactor.** Now shape it properly, with the test holding you. This is where the design happens, and it is the step people skip.

Then the next test. Small steps, and the rate of feedback is the speed limit.

## Seams

A seam is the public boundary you observe behaviour at without reaching inside.

Test at the seam that was agreed in the plan. If no seam was agreed for this slice, stop and ask for one. Do not pick your own. A test bound to an invented seam is a test that gets deleted the first time the implementation moves, and deleting tests to make a refactor possible is how a suite stops meaning anything.

Prefer the highest seam that can still observe the behaviour. Testing three layers down couples the suite to a structure you will want to change.

When the interface itself is the question, rather than where to test it, call the `codebase-design` skill. It owns the words for that: module, interface, depth, seam, adapter. It is a reference to consult mid-slice, not a session to run.

## What makes a test worth keeping

- It fails when the behaviour is wrong, and only then.
- It survives a rewrite of the implementation underneath it.
- Its name says what should happen, not what the function is called.
- Reading it tells you the requirement without reading the code it tests.
- It does not assert on things nobody promised: field order, log text, an incidental data shape.

## Mocking

Mock at the boundary you do not own. A third-party HTTP call, the clock, the filesystem, a payment provider.

Do not mock your own modules to make a test easier. A test that mocks the thing next to it is testing the mock, and it will pass forever while the real integration is broken. If a module is hard to test without mocking your own code, the shape is wrong and that is a design finding, not a testing problem.

## Bugs

A bug fix starts with a test that reproduces the bug and fails. That test is the regression guard and it is the only proof the fix works.

If you cannot get a test to go red on the bug, you do not yet understand the bug. Keep working on the reproduction rather than guessing at the fix.

## Rhythm during a slice

Typecheck often. Run the single test file you are working in, repeatedly. Run the full suite once, near the end.

Running everything after every change is slow enough that people stop doing it, and that is worse than the discipline it was protecting.

If this repository has declared checks, find them the way `verify`'s **Find the checks the repository already declares** section does — the four sources it names. Its integration rule and its baseline step are the Architect's, not yours. You still have the commit your branch started from, though: run the check against it in a worktree of its own, and leave that worktree for the Architect. A check that comes back red for a reason predating your slice is a line in your report, not a thing to fix — noted and not acted on, the same as anything else you find that belongs to a different slice. Run them inside this loop, before you return, the same as the suite above.

You run declared checks against your own slice, in your own worktree, before anyone else sees it. `verify` runs them again once every slice has merged, against an integration your worktree could never see, and that later run is unchanged by this one.

## For slices with no code

The same discipline applies to a document, a rendered asset, or an infrastructure change. Before producing it, name what would show it is wrong: the check that fails now and passes when it is done. For infrastructure that means an observation of running state, never an exit code.
