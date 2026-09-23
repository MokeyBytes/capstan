---
name: two-axis-review
description: Review a diff on two independent axes, standards and spec, without blending them into one verdict. Use when reviewing built work, and read it before building to know what you will be judged on.
---

# Two-axis review

Two questions about the same diff. They are answered independently and they are never merged.

**Standards: is it built right?** Does this follow how this repository writes code.

**Spec: is it the right thing?** Does this do what the slice and the spec asked for.

## Why they never merge

A change can pass one axis and fail the other, in both directions. Code that follows every convention while implementing the wrong feature passes Standards and fails Spec. Code that does exactly what the slice asked while breaking every convention does the reverse.

Report a worst finding per axis. Never name a single worst finding across both, and never produce a blended score. A blend lets the passing axis hide the failing one, which is the exact outcome the split exists to prevent.

## The fixed point

Someone supplies the fixed point. Never guess one. Two forms exist, plus a case where there is none.

**A range in the effort's own repository.** Review `git diff <fixed-point>...HEAD`, where the fixed point is a commit, a branch, or a tag.

**A single commit in any repository, including one that is not the effort's.** The dispatcher supplies the repository and the commit; the fixed point is that commit's parent. Reach it with `git -C <repo>`, never by changing directory: `git -C <repo> show <commit>` or `git -C <repo> diff <commit>^...<commit>`.

**Some artifacts live in no repository, so there is no fixed point at all.** Read the file whole, by absolute path. Say in the report that no fixed point was available, so a degraded review is never mistaken for a clean one.

For either of the first two forms, confirm the ref resolves and the diff is non-empty before starting. Note that `...HEAD` excludes staged and working-tree changes, so an empty diff on work you were told exists usually means nothing was committed. Say that rather than reporting a clean review.

## Standards

The repository is the primary source and **the repository always overrides**. Read whatever it documents: the glossary, `CONTEXT.md` in the document home, which is `<working copy>/.capstan/` unless configured otherwise, if the repository keeps one, a standards file, a contributing guide, the conventions visible in neighbouring code.

A review that does not know the repository's own rules flags what was deliberate and misses the invariants the codebase actually depends on. That failure is the reason this axis reads local documentation first.

Some standards arrive with the plugin rather than the repository. `codebase-design` is one: it is loaded before you see a diff, so nothing in the repository consented to it. The override still holds, and the repository states its objection the same way it states everything else, as a line in the decision log, `decisions.md` in the same document home. Read that file in full, then, before grading Standards, `grep -ri` `decisions/archive/` in the same document home for the name of each standard you are about to grade against. A decline moves out of `decisions.md` once it ages past rotation, so the active log alone is not enough to prove a standard was never refused. A decline found this way carries its own status cell, checked the same way `decision-record` checks an archived row's standing: a cell reading `superseded by NNN` is authoritative, and any other status may be stale, so run `capstan-log find <document home> <NNN>`, at `../effort/bin/` from this skill's own base directory, and read each listed row before honouring the decline. A decision declining an imported standard, or narrowing it to part of the tree, wherever it is found and confirmed still standing, binds this axis, and grading against a standard the repository has already refused is itself the finding.

Absent such a line, an imported standard applies. Silence is not an objection, or every standard would need adopting twice.

The glossary is the repository stating what it calls things, so it gives this axis its one citable naming rule. The rule splits in two, and only one half is a finding.

**A name that contradicts the glossary.** Cite the term. Blocking when other code depends on the name: a type, an export, a column, anything public. Worth doing when it is local to one file. This is Mysterious Name with the rule already written down.

**A name for something the glossary does not hold.** Not a defect, and grade nothing; the smell baseline below does not reopen it. The interview settles the words it anticipated; the build discovers the things nobody thought to name. Report it as a vocabulary gap for the Architect to settle.

Where the repository documents nothing about the thing in front of you, fall back on a smell baseline: Fowler's smells, plus Capstan's own.

Mysterious Name, Duplicated Code, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun Surgery, Divergent Change, Speculative Generality, Message Chains, Middle Man, Refused Bequest, **Restated Comment**.

**Restated Comment** is a comment whose content is already visible in the code it sits above or beside. Fix: keep a comment where it carries something the code cannot say for itself — the reason behind a choice, the constraint it satisfies, the case that looks wrong until you know why it isn't — and drop the rest.

Each is a labelled heuristic, never a hard violation. Say "possible Feature Envy" and state what it is followed by how to fix it, so the finding arrives with a move attached rather than a complaint.

Skip anything a linter or typechecker already enforces. Reporting what CI would have caught wastes the one pass someone will actually read.

Where the artifact is prose rather than code, name a writing standard rather than assume one. The condition that picks between them is who reads the artifact, not who wrote it.

**`unslop` grades prose a person reads.** The default for anything a human opens.

**`writing-for-agents` grades a document an agent consumes.** A skill, an `AGENTS.md`, a `CLAUDE.md`. Applying the wrong standard is itself a finding.

Invoke whichever one applies with the `Skill` tool and grade against its body, not its one-line description — graded against, never applied.

## Spec

Read the originating slice and the spec. Look for three things:

- A requirement missing or only partly implemented.
- A requirement implemented, but not the way it was specified.
- Scope nobody asked for. Extra work is a defect on this axis, not a bonus.

Every finding cites the line of the spec it comes from. With no spec available, skip this axis and say "no spec available". Do not invent requirements to grade against.

## Findings

Each one carries an axis, a severity, one sentence stating the defect, the file and hunk, a citation, and the move that would fix it.

Severity is blocking, worth doing, or noted. Be honest about the split. Marking everything blocking is the same as marking nothing.

A finding with no citation is an opinion. Find the rule it breaks or drop it.

## Independence

The reviewer never has the builder's reasoning, and should not ask for it. The context that produced the work is precisely the context an independent reviewer would lack, and an agent reviewing its own output is confirmation bias with extra steps.

Do not delegate the review onward, and do not spawn subagents to help. Review agents that rediscover their own tooling fan out into dozens of overlapping runs.

Do not fix what you find. Report it. Someone else decides what gets acted on, and a reviewer that fixes things has become a second builder with nobody reviewing it.

## A clean review is a good outcome

If an axis is clean, say so in one line and stop. Padding a review with nitpicks to look thorough trains the reader to skim, and a skimmed review catches nothing.
