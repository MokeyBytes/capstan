---
name: decision-record
description: Record decisions so they survive without bloating anything. A one-line log by default, a full record only when it is earned, superseded rather than edited. Use whenever a decision is settled.
---

# Decision record

Three tiers, sorted by how long each thing needs to survive. Nearly everything stays in tier one.

The log, the records, the archive and the glossary are durable artifacts, and each carries one frontmatter property, `capstan_type`, prefixed because Obsidian types a property vault-wide by its name, naming what the note is (`decision-log`, `decision-record`, `decision-archive`, or `glossary`). The tracker carries `capstan_type: tracker` where the surface is `tracker.md`; where it is a GitHub board it lives outside the document home and carries none. That is the whole schema, and it exists so a vault can tell a Capstan note from any other one sitting beside it. The `effort` skill's `## Tracker` section owns which surface applies and the count that follows from it.

## Tier 1: the log

The decision log, `decisions.md` in the document home, which is `<working copy>/.capstan/` unless configured otherwise. One line per decision. Committed at the default; the operator's to commit otherwise.

```markdown
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 11 | 2026-08-20 | Failed uploads retry 3x then dead-letter. Revisit if the queue is ever non-empty | assumed |
| 10 | 2026-08-20 | Whether tenants share a schema or get one each | open |
| 7 | 2026-08-20 | Sessions expire server-side, not by JWT claim | accepted |
| 6 | 2026-08-19 | Single Postgres instance, no read replica yet | accepted |
| 5 | 2026-08-14 | Config lives in the database, not env vars | superseded by 9 |
```

This is what an agent reads when it opens the repository cold, and what you scan six months later. It stays scannable in one pass because it stays one file: past a size threshold, `<bin>/capstan-log rotate <document home>` moves every row that is not `open`, `assumed` or `unformed`, other than the newest N, out to an append-only file under `decisions/archive/` in the document home, one file per rotation, named `decisions-<lo>-<hi>.md` for the lowest and highest row number it holds. `<bin>` is the helper folder beside `skills/effort/bin/`. Rotation runs in phase 4, per `PHASE-4-DELIVER.md`; nothing in an ordinary session triggers it.

Write the line the moment the decision resolves, not batched at the end of a session. A decision that only exists in a context window is a decision that is about to be lost.

### Reading past a rotation

A rotated row still binds; it has just left the file scanned by default. Before trusting that a topic has never been decided, `grep -i` `decisions/archive/` in the document home for its area terms, the same way `effort/SKILL.md`'s "Before you start" does, and the way `two-axis-review` does before grading a standard the repository might have declined.

Archive files are append-only. A row that lands there is never edited again, its status cell included — an archived row does not get its status flipped to reflect a later decision. Superseding an archived row instead opens a new row in the active log, in the ordinary way, starting `Supersedes NNN.`; the archived row keeps whatever status it already carried. A row's real standing — whether something later replaced it — is answered by grepping every file for that phrase with `<bin>/capstan-log find <document home> <NNN>`, never by looking at the row's own status cell once it is archived.

### What a line records

The line records the decision and the reasoning that produced it. Write it so it still makes sense to someone who has never seen the surfaces the work touched.

Efforts reach outside the working copy: a knowledge base, a vault, a wiki, a ticket tracker — not Capstan's own Tracker, which the `effort` skill's `## Tracker` section owns. Those surfaces belong to the operator, and this log is committed and, for an open-source project, published. So a line about a fix made out there records what it taught the project, in the project's own vocabulary, and leaves the surface's own contents where they are. What it taught, not what it found.

| Write | Rather than |
|---|---|
| A note's tag names the project, and the Courier reads the folder it writes into rather than generalising from one example | The names of the folders, ventures, clients or people it read them from |
| Creating a taxonomy node in a knowledge base is the operator's, never the Courier's | Which node, in which taxonomy, across how many notes |
| A spike ran against a scratch repository outside the knowledge base | Its absolute path |
| The knowledge base's own health check could not be re-run, so its bar is expected rather than observed | The script's name and the rule's line number |

When a line already written breaks this, repair it in place. That is a factual repair rather than a decision change, so the number stays, the status stays, and nothing is superseded. Say in a new line that the repair happened and why.

### Statuses

| Status | Means |
|---|---|
| `accepted` | Decided. |
| `assumed` | Defaulted so the work could proceed. The line carries the condition that would make it worth reopening. |
| `open` | Raised and unsettled. Nobody has decided and no default is in force. |
| `unformed` | An area known to be unexplored, where the question itself cannot be phrased yet. Not a decision, and not answerable. |
| `superseded by NNNN` | Replaced. Stays in the file, out of the reading path. |

`open` and `assumed` are what an interview parks when a question will not resolve, and they are the reason the `interview` skill reads this file before its first round. A question the operator could not answer in March is worth putting to them again in June. Without a line here it is simply forgotten, because the spec that held it was deleted at delivery.

An `assumed` line is the cheaper half of that pair. It says work carried on under a default that nobody has blessed, which is a different thing from a decision, and the distinction is worth the extra word every time somebody asks why the code does that.

`unformed` is the one that is not a question. It names an area the effort will reach and nobody has thought about yet: an integration nobody has opened, a phase of the work whose shape is still fog. Written as `open` it gets asked, stalls because it needs work rather than an answer, and is parked a second time. Written nowhere it is a surprise in phase 3. It graduates: as the area comes into view the line is rewritten as a real `open` question, or several, and that rewrite is the one place a line changes rather than being superseded, because nothing was decided and there is no history to protect.

One use of the log is easy to miss: declining a standard that arrived with the plugin. A discipline preloaded on an agent was never consented to by the repository it is about to grade, so a repository that disagrees says so here, as one `accepted` line naming the standard and the scope it does not apply to. The Reviewer reads this file before it grades, which is what makes the line binding rather than a note.

## Tier 2: the record

A full document only when the decision passes **all three** gates:

1. **Hard to reverse.** Undoing it later costs real work.
2. **Surprising without context.** A competent person arriving fresh would ask why.
3. **A real trade-off.** Something genuine was given up.

All three, not any one. Most decisions fail at least one, so most efforts produce a handful of log lines and no records at all. That is the design working, not the discipline slipping. Writing a record for every decision is exactly how decision folders became the bloat you are trying to avoid.

Lives at `decisions/NNNN-short-slug.md` in the document home, which is `<working copy>/.capstan/` unless configured otherwise. Six sections, none longer than a paragraph:

```markdown
---
capstan_type: decision-record
---

# NNNN. Sessions expire server-side, not by JWT claim

**Status**: accepted
**Date**: 2026-08-20

## Context
What was true that forced a choice.

## Decision
What was chosen, stated plainly.

## Alternatives
What else was on the table, and what each one would have cost.

## Consequences
What this makes easy, and what it makes hard.

## Revisit when
The condition that would make this worth reopening. Write one, or admit there isn't one.
```

## Tier 3: the brief

Never stored. Generated per recipient at send time by the `brief` skill, which owns the shape.

## Never edit an accepted record

When a decision changes, write a new one that supersedes the old and cross-link both. Mark the old one `superseded by NNNN` and give the new one a `supersedes NNNN` line. Update both files, every time.

This is the mechanic that keeps the set honest. Editing an accepted record destroys the history of why the direction shifted, which is usually the most valuable thing in the folder.

Never delete a record. Superseded records stay, marked, out of the reading path.

## The glossary

The glossary, `CONTEXT.md` in the document home, which is `<working copy>/.capstan/` unless configured otherwise. One line per term. Committed at the default, the operator's to commit otherwise, and it persists for the same reason the log does: the project's own word for a thing is a decision about language, and re-deriving it costs a conversation every time.

Create it lazily, on the first term that resolves. A repository with no settled vocabulary needs no file.

```markdown
---
capstan_type: glossary
---

# Context

| Term | Means |
|---|---|
| Slice | A change that can be demonstrated on its own. Never a layer. |
| Effort | One run from concept to delivery, holding one claim. |
| Operator | The person at the gates. Never the crew. |
```

Vocabulary only. A glossary that starts explaining how something works has become a spec, and a spec that outlives delivery is the stale artifact this whole model exists to prevent.

**Edit it in place.** This is the one file here that is never superseded, because a glossary read archaeologically is a glossary nobody reads. It holds current truth and nothing else.

The *change* is what gets recorded. When a term shifts meaning, or one word splits into two, write a numbered line in the decision log, in the document home, saying so. Current definition in one file, history in the other, and neither doing the other's job.

## What does not go here

Specs, plans, research findings, review output, and checkpoint drafts all live in `.capstan/effort/`, which is gitignored, deleted at delivery, and never resolved against the document home. Only decisions persist.

## The permanent note

At delivery the Courier writes one note per effort into the knowledge base: what it was, what was decided, what was rejected, and links out to the code and the records. That note is the only thing that can answer what has been decided across every venture at once, which no single repository can.

**Done when** every decision this session settled is a line, every question it could not settle is `open`, `assumed` or `unformed`, and every line that passes all three gates has a record beside it.
