# Document home

The document home is the one configured root Capstan resolves every path to its own durable artifacts against: the glossary, the decision log, the decision records, and, when the tracker is unset, the tracker itself. It defaults to `.capstan/` in the repository, next to your code.

## What Capstan writes

```
.capstan/
  CONTEXT.md      one line per term. committed. edited in place.
  decisions.md    open, assumed and unformed rows, plus the newest 50. committed.
  decisions/      a full record, only when one is earned. committed.
    archive/      rows rotated out of decisions.md, one append-only file per rotation. never edited.
  tracker.md      one row per slice: effort, slice, status, merge commit. committed. absent under a GitHub tracker.
  effort/         scratch: the lock, the claim, spec, plan, scout returns. gitignored.
  quick/          scratch for one parked /capstan:quick run. gitignored.
```

`effort` and `setup` both make sure `.capstan/effort/` is in your `.gitignore`, so you never have to add it by hand. That folder, and any copy a sync service makes of it (`effort 2`, `effort 3`), is deleted at delivery, because a stale spec is worse than no spec: the next agent reads it as current. The delete names those paths exactly, after checking the claim inside belongs to the effort being closed; anything else in `.capstan/` is left alone, whatever it is called.

`decisions.md` stays one file, read whole before every effort, however long a project runs. Once it passes 100 KB, `capstan-log rotate` moves every row that is not `open`, `assumed` or `unformed` out to `decisions/archive/`, keeping the newest 50 rows of any status behind. A rotated row still binds: it has just left the file an effort reads by default, so `effort/SKILL.md` also greps the archive for a run's own area terms before assuming a topic was never decided. See [record 0006](../.capstan/decisions/0006-rotate-the-decision-log.md) for the mechanism and why it works this way.

`tracker.md` answers what shipped, one row per slice, with the commit that merged it, and it is on by default, so you get it without configuring anything. See [tracker surface](tracker.md) for the GitHub alternative.

Capstan reads five keys from your own `CLAUDE.md` or `AGENTS.md` rather than hardcoding any of them. `capstan-document-home`, below, is one. `capstan-tracker` belongs to `capstan-board`, covered on the [tracker surface](tracker.md) page. `capstan-knowledge-base` is where the permanent per-effort note goes; see [knowledge base](knowledge-base.md). `capstan-max-builders` and `capstan-max-fix-dispatches` bound the fan-out inside one effort, default 3 and 5, and are yours to raise or lower; leave them out and the defaults apply.

## Choosing where it lives

By default, the glossary, the decision log, the decision records, and the tracker live in `.capstan/` in the repository, next to your code. The first effort you run writes that down as soon as you answer its one question with the default, rather than leaving anything unconfigured.

The effort scratch never moves, whichever layout you pick: the claim, the spec, the plan, and scout returns stay at `.capstan/effort/` in the repository under every configuration, and are deleted at delivery.

Some operators would rather keep a growing decision log out of the repository entirely, or keep one project's notes fully apart from another's. Three layouts cover that. `setup` asks the fork first, here in the repository or somewhere outside it, and only asks which of the two vault layouts you want if you choose outside:

- in the repository: the default above, nothing to configure, and the files sit next to the code they document.
- one vault per project: a dedicated vault for this project alone, for someone who wants it kept apart from every other project.
- one folder per project in a shared vault: one vault holding every project as its own folder, for someone who wants related projects visible together.

Capstan stores no difference between the last two. Both are an absolute path configured away from the default, and the list above exists to help you choose, not because Capstan branches on which one it is.

Run `/capstan:setup` to choose, and run it again later to change your mind. It asks the fork first and the vault layout only if you go outside the repository, confirms the path, creates the folder if it does not exist, checks whether anything is already sitting at the destination before it moves a thing, and moves the artifacts on your approval. That is four artifacts when the tracker stays on the default and `tracker.md` moves with the rest, three when the tracker is on GitHub and there is no `tracker.md` to move.

**Capstan never commits a configured document home, and it never runs git inside one.** It writes the files and stops; committing them from then on is yours, the same as committing anything else in that vault. Left uncommitted, a document home can sit that way for days before anyone notices, so weigh that before you switch it on.

A vault like that is often synced too, by iCloud, Dropbox, or Obsidian Sync. Only iCloud was tested, on macOS. Desktop & Documents sync is on, and the sync mechanism has already fired repeatedly on the vault used for the test. Dropbox and Obsidian Sync were not tested; both make their own conflict-copy names, different from iCloud's, so nothing here says how they behave.

Whichever one makes the copy, nothing in the vault catches it. Capstan runs no git in a configured document home, so a duplicated `decisions.md 2` sitting beside the real one has nothing to surface it. In the repository, `git status` does that job for the scratch Capstan writes there. In a vault, nothing does, and there is no guard against it. The only warning is this one, and it reaches you once, when you are choosing where the document home goes. It reaches nothing when an agent is actually writing there.

## Setting the key

`capstan-document-home` lives in this repository's own `CLAUDE.md` or `AGENTS.md`, the one at the root of this working copy, not a user-level file. A `~/.claude/CLAUDE.md` is never read for this key: set it only there and Capstan falls back to the default without telling you.

Taking the default writes the word `default`, not a path:

```markdown
capstan-document-home: default
```

Naming a folder outside the repository writes an absolute path instead:

```markdown
capstan-document-home: /Users/you/vault/YourProject
```

You should not need to write either line by hand: `setup` writes it once you answer its question, and answering default at the start of your first effort writes it the same way. `default` is what a reader taking the default sees committed, not their own filesystem layout. The value is always one of those two shapes: the literal `default`, resolving to `.capstan/` in the repository, or an absolute path. A file lives in exactly one location, never a copy in both places, and Capstan resolves every path to it against that one root.

The glossary (`CONTEXT.md`), the decision log (`decisions.md`), and the decision records (`decisions/`) resolve there from then on, along with `tracker.md` when the tracker stays on the default. Switching an existing project's document home runs through `setup`, which reports what it finds at the new destination and moves the artifacts once you approve, rather than leaving you with a stale copy in `.capstan/` and a fresh one in the vault.

An unreachable configured root stops the run rather than falling back to the default, since a missing source of truth would otherwise produce two records that quietly disagree.
