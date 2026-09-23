---
name: setup
description: Configure where a project's durable artifacts live, in this repository or in a folder outside it, move what is already there, and change the answer later.
disable-model-invocation: true
argument-hint: "absolute path to the repository (defaults to the current one)"
---

# Setup

This configures the **document home**: the one root Capstan resolves every path to its own durable artifacts against, the glossary, the decision log and the decision records. The default is `<working copy>/.capstan/`, and unset means nothing has chosen yet. `tracker.md`, the tracker's own file on the default surface, moves with the document home below whenever `capstan-tracker` is unset.

Where slice state lives — `tracker.md` on the default surface, or a GitHub Projects v2 board instead — is a separate question this skill no longer asks. When `capstan-tracker` is set, this skill leaves it exactly as it is and says to use `/capstan-board:setup` for anything about that surface; when it is unset, there is nothing to say.

The operator types `setup` to run this. Nothing else reaches for it on its own reading of a sentence. Relocating someone's decision log on a guess is worse than the operator typing one command.

It is safe to run more than once. See **Re-running** at the end.

## Precondition: establish the working copy

Take the absolute path from the argument the operator typed after `setup`. If they typed none, use the session's own working directory. Either way, confirm it is a repository:

```bash
git -C <abs-path> rev-parse --show-toplevel
```

Everything below refers to that path. It is not necessarily the session's working directory when an argument was given, and it must never be assumed to be. Address every file by absolute path, `git -C <path>` included, and the session's own location stops mattering.

## The ask

Before asking anything, read `capstan-document-home` from `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md`, both addressed by absolute path against the working copy above. The key is a bare line, `capstan-document-home: <value>`, never frontmatter: reading it means finding that line, not parsing YAML. A file that does not exist and a file that exists but carries no such line reach the same result everywhere below: no value found there.

Reject three shapes rather than resolve past them, in either file: the key appearing twice in one file, an empty value, and a value that is neither the literal `default` nor itself an absolute path (resolving a relative one would mean assuming the session's own directory, exactly what the Precondition above forbids). Each ends the run: report what was found and ask the operator to fix the file by hand before running this again. A file already carrying two contradictory lines is not made safe by guessing which one to keep.

Strip any trailing slash from a value found before comparing it to anything else; `<working copy>/.capstan` and `<working copy>/.capstan/` name the same path. Call whatever this settles to **the home currently in force**: `<working copy>/.capstan` when neither file carries the key or the value found is the literal `default`, or the absolute path found otherwise. A value of `default` still counts as "a key was found" everywhere below that distinction matters; it only collapses to the same path as the absent case, not to the same history.

Report the home currently in force before asking anything else, always under the same word, "Currently:". If the two files carry the key with different values, there is no single value to put there; report both under it instead, "Currently: `CLAUDE.md` says `<value>`. `AGENTS.md` says `<value>`.", and ask which one is correct before anything else. The answer becomes the home currently in force, and step 4 removes the key from the file that lost, without asking again which file that is. Otherwise, "Currently: `<value>`." carries the single value, whether a file carries the key or not: an operator who has never run this before sees the default stated as plainly as one changing an existing answer does. Whenever `capstan-tracker` is set, in either file, add to this same report that the tracker surface is `/capstan-board:setup`'s question, not this skill's. Then continue below regardless, since changing an existing answer runs the same procedure as setting it the first time.

Check too, in the same breath, whether the home currently in force exists on disk right now, before step 1 gets the chance to create the confirmed path and erase the signal. If it does not and a key was found for it in either file, say so plainly: it held something once and that is gone now. If it does not and no key was found anywhere, there is nothing recorded to say it ever held anything; the "Currently:" line above already covers it, and nothing more is added here. This is a fact about the home in force itself, true regardless of which path gets confirmed below or which branch the run takes from there, so it is said once, here, rather than inside whichever branch happens to notice it later.

The layout ask below is two steps, never a three-way menu: someone who wants the default should not read two paragraphs about vault layouts to get there. Step 4 can ask a further question, which file `capstan-document-home` lives in, whenever both `CLAUDE.md` and `AGENTS.md` exist and nothing above already settled it; a disagreement already resolved above does not ask again, and either way that is a separate ask that does not turn this one into three.

**First, the fork.** Ask where the glossary, the decision log and the decision records should live:

- In the repository, at `.capstan/`. Where they already sit if nothing has been configured elsewhere.
- In a folder outside the repository, such as an Obsidian vault.

**Second, only on "outside."** Describe the two layouts the operator can choose between, one line each, then ask for an absolute path. Describe them; do not coin a short name for either, because Capstan stores neither choice and a coined name would be vocabulary for a distinction nothing persists:

- One vault per project, where the absolute path is that vault's own root.
- One folder per project in a shared vault, where the absolute path is this project's own folder inside it.

Both resolve to the same thing from here on, an absolute path configured away from the default. The description above exists to help a person choose; nothing below branches on which one they picked.

## Then, in order

### 1. Confirm the path, and make sure it exists

The confirmed path is `<working copy>/.capstan` for "in the repository," written and compared without a trailing slash from here on even though the rest of this document spells the directory `.capstan/` to mark it as one, or the path the operator just gave for "outside." An absolute path only. A relative one is rejected right here, before it gets the chance to stop a later step on an assumption about the session's own directory. Strip any trailing slash before comparing it to the home currently in force below; the two are compared by path, not by spelling.

Create the confirmed path if it does not already exist, before anything below can branch on it. Without this, choosing a folder outside the repository fails on its first run every time: a project folder named for the first time inside a vault is unreachable by definition. It also closes the case a re-confirmed key can otherwise reach: a folder deleted since the last run, waved through by every branch below because each one continues past this point rather than through it. This runs whether the confirmed path matches the home already in force or not, and whether the collision check below finds all the artifacts, some, or none: the guarantee is a property of the confirmed path itself, not of whichever branch happens to ask for it first.

Created empty, it can still be empty when this run ends, most often a fresh repository choosing the default with nothing yet to move into it, or a later step that stops before anything moves. Git does not track an empty directory, so step 6 commits nothing for it, and there is nothing to unwind either way: an empty directory left here is the same expected outcome as a fresh repository choosing the default, and the operator removes it by hand if they would rather it were gone.

### 2. Check the destination

The artifacts this step and step 3 track are `CONTEXT.md`, `decisions.md` and `decisions/`, always, plus `tracker.md` too when `capstan-tracker` is unset across `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md` — read once, here, rather than asked about: changing which surface is in force is `/capstan-board:setup`'s question, not this skill's. Outside that unfinished-migration case, a GitHub surface has no `tracker.md`: it is never part of this set, and its absence is never a collision. `decisions/archive/` travels inside `decisions/` as one of its own contents, not a fifth artifact of its own, so tracking and moving `decisions/` whole already carries it. Call this set **the artifacts** for the rest of this step and the next.

When the confirmed path is the home currently in force already, there is nothing to check or move: continue at step 4. This is the ordinary case of confirming the same answer back, even on a project too new to have any of the artifacts yet; whether it existed a moment ago is already said above.

Otherwise, if `capstan-tracker` names a GitHub surface and `tracker.md` still exists at the home currently in force, stop: a board migration is unfinished, and `/capstan-board:setup` must complete it before this skill moves the document home. Moving the home out from under an unfinished migration is what strands the rows still sitting in `tracker.md`, on either leg.

Otherwise, check whether the confirmed path already holds any of the artifacts.

**All of them are there.** Report it, and ask the operator to choose:

- **Give a different path.** Return to **The ask** and ask it again from the fork, so choosing the default is a live answer this time too, then return to step 1 with whatever the operator gives.
- **Proceed.** The confirmed path's existing artifacts become the ones in force from here on. Skip step 3 entirely, and continue at step 4: the key still gets written, pointing at the confirmed path. If the home currently in force holds any of the artifacts, say plainly that it now holds a stale copy; if it holds none, there is nothing to say.

**Some but not all of them are there.** Never merge, never overwrite: a partial merge is the most dangerous kind, indistinguishable from data loss until someone diffs it by hand. Report exactly what is there, and offer only:

- **Give a different path.** Same as above, return to step 1.
- **Stop.** End the run here. The operator clears the destination by hand before running this again.

There is no third answer for a partial collision. Leaving the uncollided artifacts behind reaches the same split state a merge would, only by omission instead of by overwrite.

**None are there.** Continue to step 3.

This step runs every time a different path is in play, because two working copies pointed at one home would otherwise mean one decision log numbered by two different runs, and nothing else catches it: a working-copy-local claim file cannot see a working copy it does not know about.

### 3. Report what would move, then move it

List which of the artifacts sit at **the home currently in force** (the value read at the top of **The ask**) today and would move to the confirmed path.

If none of them do, ask the operator which is true, since nothing here can tell the two apart:

- **Nothing exists yet.** Proceed to step 4 with nothing moved.
- **This is not where the artifacts live.** The home currently in force, whether that came from a key or from standing at the default, is pointing at the wrong place; they sit somewhere else. Stop here. The operator points it at the right place by hand, then runs this again.

Otherwise, on the operator's approval, move them and continue to step 4. On refusal, move nothing, say plainly that `<home currently in force>` still holds what was just listed and the confirmed path is not receiving it, and stop here: do not write the key and do not commit. A refusal that still rewrote the key would leave that key pointing at an empty destination while the real log sat untouched at the old home, worse than either finishing the move or leaving everything as it was.

The move covers exactly the artifacts defined in step 2, nothing more and nothing less: `CONTEXT.md`, `decisions.md` and `decisions/` always — `decisions/archive/` inside it, with no separate move of its own — `tracker.md` too on the default and never on GitHub, where none exists to move. The effort scratch stays at `<working copy>/.capstan/effort/` under every configuration, and `.capstan/` itself is never deleted by this step. It can end up empty once the artifacts move out and no effort is currently running, the same expected emptiness as step 1's newly created folder.

### 4. Write the key

Write `capstan-document-home: default` into its chosen file when the confirmed path is the default, or `capstan-document-home: <confirmed path>` when the operator named a path outside the repository. Choose the file this way:

- **The ask found the two files disagreeing on this key.** The operator already picked which one is correct there; write into that file, and do not ask again.
- **Neither `CLAUDE.md` nor `AGENTS.md` exists.** Create `AGENTS.md`, since both Claude Code and Codex read it; `CLAUDE.md` is never created by this step.
- **Exactly one of the two exists.** Write into that one.
- **Both exist, and nothing above settled it.** Ask which file should carry `capstan-document-home`.

If the chosen file already carries a `capstan-document-home` line, replace that line in place; never append a second one. A file with no existing key gets the line appended at the end, under no heading. A file this step creates holds one sentence above the key line saying what the file is, for example:

```
This file carries configuration read by Capstan and by other agents working in this repository.

capstan-document-home: default
```

If the other file — `CLAUDE.md` or `AGENTS.md`, whichever was not chosen — still carries a `capstan-document-home` line, remove it entirely, and remove the introductory sentence too if that file now carries neither `capstan-document-home` nor `capstan-tracker` and nothing else, whichever run wrote that sentence — it names configuration no longer there, stray the same way the line was, even where other content in that file survives it. A stray line or sentence left standing states a second, contradicting answer for a project that now has one settled. This runs every time both files exist, not only when the ask found them disagreeing: a file that already agreed leaves the same debris behind if this is skipped. Never remove or touch a `capstan-tracker` line in either file while doing this — that key is `/capstan-board:setup`'s, not this step's, whichever file it happens to sit in. Once the line and, where it applied, the sentence are gone, delete the file itself if it now carries neither `capstan-document-home` nor `capstan-tracker` and nothing else: a zero-byte file in git history looks like it means something.

`capstan-document-home` is written even when the confirmed path is the default, so a project that commits this file never commits the operator's own filesystem layout. Otherwise a project that was never asked and a project that was asked and chose the default also look identical on disk, and telling those two states apart is the reason this skill exists.

### 5. Add `.capstan/effort/` to `.gitignore`

Create `<working copy>/.gitignore` if it does not exist, and add the line if it is missing. A committed effort scratch is a stale spec sitting in someone's repository, read by the next agent as current when it no longer is.

### 6. Commit everything, once

Commit every change this run made to the working copy as a single commit, ordinary unattended work: the `capstan-document-home` key written or replaced, and a second file's key removed or the file deleted alongside it if step 4 found one; the artifacts removed from the home currently in force, if they moved out of the working copy; and the `.gitignore` line from step 5. Subject it `Configure document home`. Do not commit anything on the far side of a move. That is the operator's, always, the same as anything else in a vault they did not ask this skill to touch.

Nothing to commit is a valid outcome. Confirming the same answer back changes none of the working copy's own files, and this step is then a no-op.

### 7. Say the vault is theirs to commit

When the confirmed path is a folder outside the repository, tell the operator that the vault is theirs to commit, and that a document home can sit unversioned for days if they let it. When the artifacts also moved out of a vault, the source is theirs to commit too, for the same reason: this step ran no git there either, and the deletions sitting inside it are just as real as the arrivals in the destination. Nothing here runs git outside the working copy.

**Done when** exactly one `capstan-document-home` line exists across `<working copy>/CLAUDE.md` and `<working copy>/AGENTS.md` combined and reads `default` or an absolute path, `<working copy>/.gitignore` carries `.capstan/effort/`, and listing the confirmed path directly, not recalling what an earlier step reported, shows a directory that exists and holds every one of the artifacts (step 2's set, for whichever surface `capstan-tracker` currently names) that exists anywhere. Zero of the artifacts, some of them, or all of them all satisfy this equally, since step 2 itself calls some-but-not-all the ordinary case; what fails it is one of the artifacts sitting somewhere else without also sitting at the confirmed path, or the confirmed path not existing at all. A stale copy left behind at the old home under step 2's full-collision Proceed, reported there as stale, does not fail this on its own: the confirmed path still holds every artifact currently in force.

## Re-running

Running this a second time is not a special mode. It is the same skill, and the read at the top of **The ask** is what makes re-running work. It reports the current value, or the disagreement between the two files if there is one, before offering its own fork again, so the operator always sees what is in force before they change it.

Confirming the same document-home value back finds nothing to move. Step 2 sees the confirmed path is the home already in force and skips straight to step 4, step 4 replaces the key line with the same value, step 5 is a no-op once the `.gitignore` line already carries it, and step 6 commits nothing further for it. Choosing a different answer runs steps 1 through 7 exactly as a first run would, moving the artifacts from the home currently in force, wherever that is today, to the newly confirmed path: vault A to vault B, `.capstan/` back to a vault, or any pair between them.

This is what a one-shot question could not do. An operator who wants to change the document home runs `setup` again, rather than editing a key by hand and hoping the rest follows it there on their own. Changing the tracker surface, or moving what a board holds, is `/capstan-board:setup`'s question instead, run separately.
