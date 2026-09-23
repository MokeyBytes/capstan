---
name: setup
description: Configure the tracker surface for a project already using Capstan, moving slice state onto a GitHub Projects v2 board or back to tracker.md.
disable-model-invocation: true
argument-hint: "absolute path to the repository (defaults to the current one)"
---

# Setup (board)

This configures the **tracker surface**: whether slice state stays in the document home as `tracker.md`, or moves to a GitHub Projects v2 board instead. It is a separate question from the **document home** itself — where the glossary, the decision log and the decision records live — which core's `setup` skill configures. Run that one first if the document home has never been set; this skill reads whatever it settled on and never moves it.

The operator types `/capstan-board:setup` to run this. Nothing else reaches for it on its own reading of a sentence. Relocating a project's tracker on a guess is worse than the operator typing one command.

It is safe to run more than once. See **Re-running** at the end.

## Precondition: establish the working copy

Take the absolute path from the argument the operator typed after `/capstan-board:setup`. If they typed none, use the session's own working directory. Either way, confirm it is a repository:

```bash
git -C <abs-path> rev-parse --show-toplevel
```

Everything below refers to that path. It is not necessarily the session's working directory when an argument was given, and it must never be assumed to be. Address every file by absolute path, `git -C <path>` included, and the session's own location stops mattering.

## Read the document home

This plugin cannot read core's files, so it reads `capstan-document-home` itself rather than pointing at core's own copy of this logic. Read the key from `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md`, both addressed by absolute path against the working copy above: a bare `capstan-document-home: <value>` line, never frontmatter. Reject three shapes rather than resolve past them, in either file: the key appearing twice in one file, an empty value, and a value that is neither the literal `default` nor itself an absolute path. Each ends the run: report what was found and ask the operator to fix the file by hand before running this again. Both files carrying the key with different values also stops the run, reported so the operator can fix the file by hand — the same "two records that disagree" outcome core's `effort` skill stops for. Unset, or the literal `default`, resolves to `<working copy>/.capstan`; otherwise it is the absolute path found, stripped of any trailing slash. A document home configured away from the default that does not exist on disk stops the run too: a missing source of truth is not something to fall back past. Call this **the document home** below.

This skill never writes or moves `capstan-document-home`, and never moves the artifacts core's `setup` skill owns.

## The tracker-surface ask

Before asking, read `capstan-tracker` from `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md`, both by absolute path, under the same bare-line rule as `capstan-document-home` above: a bare `capstan-tracker: <value>` line, never frontmatter. Reject the key appearing twice in one file and an empty value, the same way and for the same reason as above; each ends the run, reported so the operator can fix the file by hand. Report the value currently in force before asking anything else, under "Currently:": "`tracker.md` in the document home." when unset, the value itself when one file carries it, or, when they differ, "`CLAUDE.md` says `<value>`. `AGENTS.md` says `<value>`.", asking which is correct before anything else and treating that answer as the value in force from here on.

Ask where slice state should live:

- **The default.** `tracker.md` in the document home, unchanged from every project today.
- **GitHub.** A Projects v2 board on the working copy's own remote.

**On the default.** When nothing is currently recorded, there is nothing to write: this run writes no `capstan-tracker` line, because an unset key already means `tracker.md`. When a `capstan-tracker` line already exists from an earlier run and the operator is choosing the default back, say plainly that this carries every row the board holds back into `tracker.md` and then tears the board down, under **Back to `tracker.md`** below, once what that step finds on the board has been read. The key is not removed here — that step removes it, once it is done.

**On GitHub.** If the project already has a `tracker.md`, say plainly that choosing GitHub carries every row it holds onto the board and then deletes the file, under **Onto the board** below, once the scope check has passed and the operator has approved the batch — every repository's delete needs that approval, a public one's writes too.

Ask for the project number alone; the owner and repository are never asked for, they come from the working copy's own remote. Resolve that remote without assuming its name is `origin`, since a repository can call its GitHub remote `upstream`, `github`, or anything else:

```bash
git -C <working copy> remote -v
```

Read `<owner>/<repo>` out of whichever remote's URL has `github.com` as its host. No remote does, or the working copy has no remote at all, means this surface cannot be reached from this working copy at all: say so and stop, before asking for a project number nothing can use.

The tracker value to write is `github:<owner>/<repo>#<project-number>`. It is not written yet: the scope check that must pass first runs next, not here. Running it here would walk the operator through granting a scope for a run that a later refusal could still abort before writing anything.

## Then, in order

### 1. Confirm the scope, on GitHub

Reached whenever this ask settled on GitHub, or settled on the default while the value currently in force named a board. Either direction reads or writes the same board, so both need the same scope. Check whether the token in force can reach Projects v2 by calling the thing the surface itself will call, rather than by reading the scope list `gh auth status` reports:

```bash
gh project list --owner <owner>
```

**It succeeds.** The token already reaches Projects v2. Continue below.

**It fails naming a missing scope.** Reading a board needs a scope this token does not carry. Hand off to the `walkthrough` skill for one stage: it tells the operator to run `gh auth refresh -s project` themselves, since granting a scope is an auth change and never this skill's to run, then stops and waits for the operator to confirm they ran it. Once confirmed, re-run the same `gh project list --owner <owner>` call. It succeeding now is the grant landing; continue below. It failing again is not a step to loop on: stop the run here and report what still fails.

**It fails any other way.** A network failure, an expired token, a rate limit, or `gh` itself missing all land here, along with anything else that is not the missing-scope error above. Say so and stop, no retry. `gh auth refresh -s project` fixes none of these, so do not send the operator to run it on the strength of this failure.

### 2. Before writing, on a migration

Reached only when the tracker-surface ask settled on GitHub this run and `tracker.md` exists at the document home, deferred behind the scope check above for the same reason: an approval asked here should not outlive a run that check could still stop before anything is written. The write below and the delete below are gated separately, not by one check: only the write depends on visibility.

```bash
gh repo view <owner>/<repo> --json visibility -q .visibility
```

Either way, describe the batch before writing anything — how many rows, how many milestones, that `tracker.md` is deleted once every row carries an issue — and ask for one approval covering the whole migration: a public repository's writes need it too; a private repository's do not, but the delete needs it either way. Refusing stops the run here: do not write the key and do not commit.

### 3. Write `capstan-tracker`

Address `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md` by absolute path:

- **The tracker-surface ask found the two files disagreeing on this key.** The operator already picked which one is correct there; write into that file, and do not ask again.
- **Neither `CLAUDE.md` nor `AGENTS.md` exists.** Create `AGENTS.md`, since both Claude Code and Codex read it; `CLAUDE.md` is never created by this step.
- **Exactly one of the two exists.** Write into that one.
- **Both exist, and nothing above settled it.** Ask which file should carry `capstan-tracker`.

**On GitHub**, write `capstan-tracker: github:<owner>/<repo>#<project-number>` from the value the tracker-surface ask settled on. **On the default**, the opposite: if the chosen file carries a `capstan-tracker` line, remove it; if it carries none, write nothing. Unset already means `tracker.md`, so nothing here needs distinguishing a project that was never asked from one that was asked and chose the default.

Where a line is written: if the chosen file already carries a `capstan-tracker` line, replace that line in place; never append a second one. A file with no existing key gets the line appended at the end, under no heading. A file this step creates, per "Neither `CLAUDE.md` nor `AGENTS.md` exists" above, holds one sentence above the key line saying what the file is, for example:

```
This file carries configuration read by Capstan and by other agents working in this repository.

capstan-tracker: github:<owner>/<repo>#<project-number>
```

The removal on the default does not run yet when the value currently in force named a board: removing that line here, before **Back to `tracker.md`** below has read what the board still holds, would strand a resumed run with nothing left pointing at it. That step removes the line itself, once every row it found is torn down.

If the other of `CLAUDE.md` or `AGENTS.md` still carries a `capstan-tracker` line, remove it entirely, and remove the introductory sentence too if that file now carries neither `capstan-tracker` nor `capstan-document-home` and nothing else, whichever run wrote that sentence — it names configuration no longer there, stray the same way the line was, even where other content in that file survives it. A stray line or sentence left standing states a second, contradicting answer for a project that now has one settled. Once `capstan-tracker` has settled where it lives, or been removed, and the sentence removed where it applied, delete the file itself if it now carries neither `capstan-tracker` nor `capstan-document-home`, and nothing else — never delete a file still carrying the document-home key, which is core's, or any other content, rather than leave an empty file behind. This rule applies wherever this skill removes `capstan-tracker`, step 4's reverse-migration removal below included.

### 4. Migrate the tracker surface

**Onto the board.** Reached only when the tracker-surface ask settled on GitHub this run and `tracker.md` exists at the document home — step 2 already secured the approval and step 3 already wrote the key, before any row moves. Nothing to do otherwise: continue to step 5.

Follow the write path in this plugin's own `tracker` skill for every row, finding each row's own milestone by title and its own issue by title within that milestone before touching it. A migrated issue's body departs from that path only in what it carries: where the row came from and nothing else.

A row is resumed on whether its work is **complete**, never on whether its issue exists: a `planned` or `building` row is complete once steps 3 through 5 of that write path have run for it and it sits open; a `merged` or `dropped` row is complete only once steps 3 through 6 have run and it is closed. An issue existing is step 3 alone — a row can have an issue, a status and a posted comment, and still be short of step 6's close. Test each row against this before creating anything for it, and carry forward whatever steps its own status still needs rather than stopping at the first one it already has; this is what makes an interrupted run resume rather than duplicate or stall.

Once, before creating the first issue, take the working copy's own head commit as the one every migrated issue's body names — `git -C <working copy> rev-parse HEAD` — the commit this migration is actually running from, and an answer even where the document home is not a repository, or holds `tracker.md` untracked, neither of which a read scoped to that file can give:

```
Migrated from `tracker.md` at commit <sha>.
```

Delete `tracker.md` only once every row it held is complete by that same test, never before — an interrupted run leaves the file in place, and the next run resumes into whichever rows above are still short of it. Before the delete, prove the board holds what the file holds by reading it back rather than trusting the writes: `<bin>/capstan-tracker diff --owner <owner> --repo <repo> --project <project-number> --tracker-md <path to tracker.md>`, `<bin>` resolved as this plugin's `tracker` skill declares, has to exit 0, every row `same`. Any other exit leaves the file where it is and reports what the diff printed: exit 4 names the rows that differ, and 1, 2 and 3 are the read failing, per that skill's reading-back section.

**Back to `tracker.md`.** Reached whenever the tracker-surface ask settled on the default this run and the value currently in force, read at the top of that ask, named a board. Step 1 already confirmed the token can reach Projects v2, above, before this step reads anything, though that confirmation does not carry forward to this read, since the limit can exhaust in between — and left `capstan-tracker` untouched rather than removing it; this step decides whether there is a key to remove at all. Parse `<owner>`, `<repo>` and the project number out of that same value, `github:<owner>/<repo>#<project-number>` — the reverse runs on this ask's default branch, which never binds them the way the GitHub branch does.

Read the board back through the helper this plugin's own `tracker` skill's reading-back section declares, with commits: `<bin>/capstan-tracker read --owner <owner> --repo <repo> --project <project-number> --with-commits`. It returns only issues in `<owner>/<repo>` carrying a `Capstan Status` — everything else on the board is left exactly as it is, named in the report from the helper's own summary — and it validates every row before printing any: a status outside the four, a row with no milestone, and a `merged` row whose issue carries zero or more than one conforming comment each exit 3 with the row named, and the run stops here reporting that. Exit 1 is unreachable and exit 2 is a read the helper could not prove complete: both stop here and report what was printed, per that skill's **Unreachable stops the run** section, and neither ever reads as zero rows. Exit 0 with no rows is a genuine empty result: there is nothing to migrate — remove the key and continue to step 5. Nothing here is checked against git history — the board is what this reads.

Test resuming against completion, never existence: `tracker.md` already existing at the document home is not enough on its own — an interrupted forward migration leaves that same file behind, with rows the board has since moved past. Run `<bin>/capstan-tracker diff` against the file at the document home. This run is resuming an interrupted teardown only when every row the board still carries comes back `same` — matched on effort and slice together, never slice alone, since two efforts can each hold a `docs`, with the same status and, on a `merged` row, the same commit — and the only differences are `file-only` rows, which are rows already torn down; skip straight to teardown against whatever the board still carries. A `status-changed`, `commit-changed` or `board-only` line means the file is not this board's, and the run stops here reporting the diff rather than tearing anything down against it.

Describe the batch before writing anything — how many rows, how many milestones, that the board is torn down once `tracker.md` is written and verified — and ask for one approval covering the whole teardown before writing, closing, or removing anything below: removing an item is a delete, so the operator approves it every time, on a public repository or a private one; and commenting on and closing issues in a public repository is visible to third parties, whether or not the delete would already have needed the approval. Declining says instead how many rows are on the board and that leaving `capstan-tracker` as it is strands them; anything step 3 changed above this point stays uncommitted — the run stops there, `tracker.md` is not written, and the key is not removed.

On approval: write `tracker.md` whole at the document home, one row per validated slice, under the column mapping this plugin's own `tracker` skill declares — `Commit` blank except on a `merged` row, where it carries the SHA its one conforming comment names. Verify it by running `<bin>/capstan-tracker diff` against the written file, on every branch: it has to exit 0, every row `same`, before any teardown begins. Any other exit leaves the board untouched and reports what was printed. At the default document home, add and commit `tracker.md` by path alone, before touching the board — whatever else this run has already changed does not ride along with it. At a configured document home, `tracker.md` is left there for the operator, per step 6; nothing here runs git there, per core's `effort` skill.

Once, before tearing down the first row, take the working copy's own head commit as the one every teardown comment names — `git -C <working copy> rev-parse HEAD` — the same source the forward leg uses for the same reason, an answer wherever the effort runs regardless of what the document home is or holds.

Tear down one row at a time, issue closed before item removed so a crash between the two still leaves the row on the board to find on retry: comment on its issue naming the commit taken above, in the format this plugin's own `tracker` skill declares under **The teardown comment format** — never the merge-commit format above it in that same skill — close it with reason `completed` — even a row already closed under a different reason, a `dropped` row's `not planned` among them, is reclosed here, so every torn-down row ends the same way rather than carrying two reasons for one outcome — then remove its item from the board. That item is the one delete this leg makes; the issue, the board and the `Capstan Status` field are not touched.

Once every row under a milestone is torn down, close that milestone if it now carries no open issues at all. Resolve `<milestone-number>` from the milestone's own title first — the read-back projects `.milestone.title`, never a number:

```bash
gh api repos/<owner>/<repo>/milestones -q '.[] | select(.title=="<effort>") | .number'
gh api repos/<owner>/<repo>/milestones/<milestone-number> -q .open_issues
gh api -X PATCH repos/<owner>/<repo>/milestones/<milestone-number> -f state=closed
```

Once every row this read found is torn down, remove `capstan-tracker` from wherever it lives, under step 3's delete rule above: remove the introductory sentence too, and the file itself, where that rule says to. Step 5 commits that removal as its own commit — a second one, since the reconstruction above already went in on its own.

### 5. Commit everything, once

Commit every change this run made to the working copy as a single commit, ordinary unattended work: the `capstan-tracker` key written, replaced, or removed, and a second file's line removed alongside it if step 3 found one; `tracker.md` deleted if this run finished migrating it onto the board. Subject it `Configure tracker surface`. Do not commit anything at a configured document home outside the working copy — that is the operator's, always, per step 6.

One case commits twice, and only at the default document home. When the reverse migration tore rows down there, `tracker.md` was already added and committed by its own path alone, the moment it was written and verified, before teardown began. This step's commit follows it as a second, later commit, not a rewrite of the first. `tracker.md` itself is the only thing already committed, and so the only thing this second commit excludes.

Nothing to commit is a valid outcome. Confirming the same answer back changes none of the working copy's own files, and this step is then a no-op.

### 6. Say the vault is theirs to commit

When the document home is a folder outside the repository, tell the operator that the vault is theirs to commit for whatever this run wrote or deleted there — this step ran no git outside the working copy.

**Done when** at most one `capstan-tracker` line exists across `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md` combined, and where one is present it reads `github:<owner>/<repo>#<project-number>`; and, when this run settled on GitHub, no `tracker.md` remains at the document home; and, when this run left GitHub for the default, the board carries no row with a `Capstan Status` value left on it.

## Re-running

Running this a second time is not a special mode. It is the same skill, and the read at the top of **The tracker-surface ask** is what makes re-running work: it reports the current value, or the disagreement between the two files if there is one, before offering its own fork again. Confirming GitHub back re-checks the `project` scope and replaces the key line with the same value; moving from the default to GitHub writes it for the first time. Moving from GitHub to the default runs **Back to `tracker.md`** instead of removing the key outright: the key comes out only once that leg finds nothing left on the board. Confirming GitHub back also re-runs **Onto the board**: any row not yet complete by that test picks up at whichever step it stopped on. Moving from GitHub to the default resumes the same way on its own leg: a `tracker.md` already written and verified is not rebuilt, and teardown picks up against whatever the board still carries. A run interrupted partway through either direction finishes it on the next run rather than repeating it or leaving it stuck open.
