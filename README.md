# Capstan

<a href='https://ko-fi.com/G5C025L5FG' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi6.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

A Claude Code plugin for taking work from concept to delivery, with you at three gates.

Five roles carry the work, a discipline for each part of it, and three times the run stops so you can decide whether it continues. It is plain markdown, plus a bash library that `walkthrough` builds throwaway scripts from and three small helpers the `effort` skill calls to take a lock, delete its scratch, and read a tracker board. Nothing runs on its own: no daemon, no poller, no hook. [`DESIGN.md`](DESIGN.md) says why those helpers exist and what stays out.

This repository's own [glossary](.capstan/CONTEXT.md) defines every word it uses (see [document home](#document-home) if you've pointed yours elsewhere), and [`DESIGN.md`](DESIGN.md) holds the reasoning behind the shape.

## Install

```bash
claude plugin marketplace add MokeyBytes/capstan
claude plugin install capstan@bytesnation
```

Restart Claude Code once it finishes. Agent definitions load at session start, so nothing applies until you do.

That installs at user scope, so the crew is available in every session. Add `--scope project` to write to the project's `.claude/settings.json` instead, which is what you want when a team shares one repository.

Run `/capstan:setup` next, in the repository you plan to work in. It asks two questions, kept apart because they answer separately: where the glossary, decision log, decision records and tracker should live, in the repository by default or in a vault, and whether slice state is written to `tracker.md` there or to a GitHub Projects v2 board instead. It writes the answers down so nothing asks again. Skip it and your first effort asks a narrower version of the first question: take the default here, or stop and run `setup` to choose a folder outside the repository. You cannot name a vault path from inside an effort.

## Your first run

```
/capstan:effort add rate limiting to the public API
```

You are now talking to the Architect, and you keep talking to it for the rest of the run. It owns the interview, the spec, the slice graph and the decision log. It does not build and it does not review, because the Builder and the Reviewer do that, and keeping those apart is the whole reason there are five roles instead of one.

What happens, in order:

1. **It interviews you.** Rounds of questions, each carrying a recommended answer, so most rounds are you confirming rather than composing. Finding things out is its job, not yours. Anything the codebase or a primary source can answer, it goes and reads.
2. **It stops at gate one** with a brief covering what it is building, why, and what it is deliberately not building. Protect this gate. A wrong turn is cheapest to catch here, and it is the one that gets waved through because the concept feels obvious to everyone in the room.
3. **Phase two plans.** It cuts the work into vertical slices, agrees where the tests go, and stops at gate two with the slice graph and everything it had to assume.
4. **Phase three builds.** One Builder per slice, each in its own git worktree, each writing a failing test first. A Reviewer reads every diff without the Builder's reasoning, on two axes that never blend into one verdict. Once the slices merge, your repository's own checks run against the integration, because passing alone proves nothing about passing together. Gate three shows you what was built, what review found, and what verification showed.
5. **Phase four delivers.** The Courier packages the output and writes the permanent note. You commit it, once the note review passes. It never sends anything to anyone. That part stays yours.

| Gate | The brief answers | You decide |
|---|---|---|
| 1. Concept locked | What we are building, why, what we are explicitly not doing | Right thing? |
| 2. Plan locked | How, cut into slices, what runs parallel, what was assumed | Right shape? |
| 3. Ready to deliver | What was built, what review and verification found, what goes to whom | Ship? |

**The run ends at every gate.** Nothing polls, nothing waits in the background, and the crew never asks whether it should stop. The run being over is what makes the gate real. `.capstan/effort/CLAIM.md` records which phase the effort reached, the commit it started from, the commit its checks last passed against, and what is still outstanding inside it, so the next session picks up where the last one stopped, however many hours later. Beside it sits a lock that exactly one session can hold: a second session starting the same effort is refused and told who holds it, and only you decide whether that session resumes it or takes it over.

**Unclear requirements never stop the run.** The crew takes the most defensible reading, writes the assumption into the decision log, and keeps going. Every assumption surfaces at the next gate, where correcting one costs almost nothing. Four things do stop it: secrets and credentials, anything a third party will see, anything that costs money, and anything destructive or production-facing. The one delete the crew makes on its own authority is the gitignored scratch, at delivery.

Three efforts at once is the ceiling. Three gates each against one reader is nine briefs a cycle, which is about where briefs stop being read and start being rubber-stamped. Inside one effort, three Builders run at once by default and a slice gets five fix rounds before the run stops and asks you; both are keys in your `CLAUDE.md` or `AGENTS.md`, `capstan-max-builders` and `capstan-max-fix-dispatches`, and the counts live in the claim so they survive the gaps between runs.

## The disciplines

The disciplines the roles pull in, plus the two front doors: [`effort`](skills/effort/SKILL.md) starts a run, and [`setup`](skills/setup/SKILL.md) configures where its artifacts live. Both are invoked only by you, and neither is a discipline.

| Skill | For |
|---|---|
| [`interview`](skills/interview/SKILL.md) | Rounds of questions, each carrying a recommended answer, so decisions stay yours. |
| [`spike`](skills/spike/SKILL.md) | A throwaway build, so a stalled design question gets something concrete to react to. |
| [`slicing`](skills/slicing/SKILL.md) | Cuts a locked plan into vertical slices with real blocking edges. |
| [`test-first`](skills/test-first/SKILL.md) | Red, green, refactor, tested only at seams agreed in advance. |
| [`diagnosing-bugs`](skills/diagnosing-bugs/SKILL.md) | A feedback loop that goes red on the bug before anyone theorises about the cause. |
| [`codebase-design`](skills/codebase-design/SKILL.md) | The words for structure, so a review can say a module is too shallow instead of that it feels wrong. |
| [`two-axis-review`](skills/two-axis-review/SKILL.md) | Standards and spec, reviewed independently, never blended into one verdict. |
| [`verify`](skills/verify/SKILL.md) | Runs the checks your repository declares against the merged result, because a slice passing alone proves nothing about the ones beside it. |
| [`resolving-merge-conflicts`](skills/resolving-merge-conflicts/SKILL.md) | Integrating parallel Builders, where neither side of a conflict can be asked what it meant. |
| [`walkthrough`](skills/walkthrough/SKILL.md) | The one-time script that carries you through a manual procedure, stage by stage, capturing what comes back. |
| [`decision-record`](skills/decision-record/SKILL.md) | A one-line log by default, a full record only when one is earned. |
| [`brief`](skills/brief/SKILL.md) | Checkpoint and partner briefs, generated per recipient rather than maintained. |
| [`to-questionnaire`](skills/to-questionnaire/SKILL.md) | Turns a question nobody in the room can answer into a document for the person who can. |
| [`unslop`](skills/unslop/SKILL.md) | Cuts AI tells from prose a person reads. |
| [`writing-for-agents`](skills/writing-for-agents/SKILL.md) | Keeps a document an agent consumes flat and the same shape every run. |

## What Capstan writes

By default, everything lands in `.capstan/`, inside the repository the work is happening in:

```
.capstan/
  CONTEXT.md      one line per term. committed. edited in place.
  decisions.md    one line per decision. committed.
  decisions/      a full record, only when one is earned. committed.
  tracker.md      one row per slice: effort, slice, status, merge commit. committed.
  effort/         scratch: the lock, the claim, spec, plan, scout returns. gitignored.
```

`effort` and `setup` both make sure `.capstan/effort/` is in your `.gitignore`, so you never have to add it by hand. That folder, and any copy a sync service makes of it (`effort 2`, `effort 3`), is deleted at delivery, because a stale spec is worse than no spec: the next agent reads it as current. The delete names those paths exactly, after checking the claim inside belongs to the effort being closed; anything else in `.capstan/` is left alone, whatever it is called.

`tracker.md` answers what shipped, one row per slice, with the commit that merged it, and it is on by default, so you get it without configuring anything.

Capstan reads five keys from your own `CLAUDE.md` or `AGENTS.md` rather than hardcoding any of them. `capstan-document-home` and `capstan-tracker` are the two sections below. `setup` always writes `capstan-document-home`; it writes `capstan-tracker` only when you choose GitHub, and removes any existing line there when you choose the default instead. `capstan-knowledge-base` is where the permanent per-effort note goes, and it is yours to write; leave it out and the Courier skips the note and says so. `capstan-max-builders` and `capstan-max-fix-dispatches` bound the fan-out inside one effort, default 3 and 5, and are yours to raise or lower; leave them out and the defaults apply.

## Document home

By default, the glossary, the decision log, the decision records, and the tracker live in `.capstan/` in the repository, next to your code. That is the layout above, and the first effort you run writes it down as soon as you answer its one question with the default, rather than leaving anything unconfigured.

The effort scratch never moves, whichever layout you pick below: the claim, the spec, the plan, and scout returns stay at `.capstan/effort/` in the repository under every configuration, and are deleted at delivery.

Some operators would rather keep a growing decision log out of the repository entirely, or keep one project's notes fully apart from another's. Three layouts cover that. `setup` asks the fork first, here in the repository or somewhere outside it, and only asks which of the two vault layouts you want if you choose outside:

- in the repository: the default above, nothing to configure, and the files sit next to the code they document.
- one vault per project: a dedicated vault for this project alone, for someone who wants it kept apart from every other project.
- one folder per project in a shared vault: one vault holding every project as its own folder, for someone who wants related projects visible together.

Capstan stores no difference between the last two. Both are an absolute path configured away from the default, and the list above exists to help you choose, not because Capstan branches on which one it is.

Run `/capstan:setup` to choose, and run it again later to change your mind. It asks the fork first and the vault layout only if you go outside the repository, confirms the path, creates the folder if it does not exist, checks whether anything is already sitting at the destination before it moves a thing, and moves the artifacts on your approval. That is four when the tracker stays on the default and `tracker.md` moves with the rest, three when the tracker is on GitHub and there is no `tracker.md` to move. It also writes `capstan-document-home` into `CLAUDE.md` or `AGENTS.md`: whichever one you have, asking you which when you have both, and creating `AGENTS.md` when you have neither. Exactly one file carries the key when it finishes, never two.

**Capstan never commits a configured document home, and it never runs git inside one.** It writes the files and stops; committing them from then on is yours, the same as committing anything else in that vault. Left uncommitted, a document home can sit that way for days before anyone notices, so weigh that before you switch it on.

A vault like that is often synced too, by iCloud, Dropbox, or Obsidian Sync. Only iCloud was tested, on macOS. Desktop & Documents sync is on, and the sync mechanism has already fired repeatedly on the vault used for the test. Dropbox and Obsidian Sync were not tested; both make their own conflict-copy names, different from iCloud's, so nothing here says how they behave.

Whichever one makes the copy, nothing in the vault catches it. Capstan runs no git in a configured document home, so a duplicated `decisions.md 2` sitting beside the real one has nothing to surface it. In the repository, `git status` does that job for the scratch Capstan writes there. In a vault, nothing does, and there is no guard against it. The only warning is this one, and it reaches you once, when you are choosing where the document home goes. It reaches nothing when an agent is actually writing there.

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

## Knowledge base

The document home holds this project's records. The knowledge base is the other thing: your own vault or notes folder, outside the repository, holding what you know across every project. At delivery the Courier writes one note there per effort, covering what the effort was, what was decided, what was rejected, and where the code and the records live. It is the only place that can answer a question spanning two projects, because no single repository can.

Set it with a key in this repository's own `CLAUDE.md` or `AGENTS.md`, the same two files the document home uses, and never a user-level file:

```markdown
capstan-knowledge-base: /Users/you/vault/Efforts
```

`setup` does not write this one. There is no default to fall back to, so leaving the key out is a complete answer. The Courier writes no note and says so in its close-out, rather than guessing a folder, because a note nobody can find again is worse than no note.

Capstan never runs git in there either. It writes the note, a Reviewer reads it at that path, and you commit it.

## Tracker surface

Slice state lives in `tracker.md` in the document home by default: one row per slice, carrying the effort it belongs to, the slice itself, its status and the commit that merged it. Set `capstan-tracker` and slice state is read and written on a GitHub Projects v2 board from then on instead: an issue per slice, a milestone per effort, a custom status field, and the merge commit posted as a comment once the slice lands.

The value is for people, not agents. An agent building or reviewing a slice already has `tracker.md` open, offline, at the commit it is reading. A board gives a teammate something to open without cloning the repository, and an issue that closes the moment its slice merges or drops, with the merge commit recorded on it as a comment.

It lives in `CLAUDE.md` or `AGENTS.md`, the same two files the other keys can use, though not necessarily the same one: each key picks its own file, independently of the other, and `setup` asks which file should carry this one if both exist and nothing has settled it already.

```markdown
capstan-tracker: github:your-org/your-repo#3
```

Leave it out and nothing changes. Every project has run on `tracker.md` since the tracker existed, and unset keeps it that way for anyone who never asks. `setup` asks the question either way, and writes this key only if you choose GitHub; you should not need to type it by hand.

Projects v2 needs a scope grant most tokens do not carry yet. `setup` checks for it and, if it is missing, hands you off to a walkthrough: you run `gh auth refresh -s project` yourself, since an auth change is never the crew's to make, then confirm it landed before the key gets written.

Moving onto the board is not final. Run `setup` again and choose the default, and it reconstructs `tracker.md` from the board and tears the board down, on your approval, the same shape in reverse.

Four costs worth knowing before you turn this on:

- **A public repository asks for confirmation on every write.** Every write to the board there is third-party-visible, so the operator confirms it, the same as any other third-party-visible action; a private repository writes unattended, the same as `tracker.md` always has. The tracker is written on every slice transition, so this is the cost that changes daily operation most.
- **GitHub unreachable stops the run.** No retry, no backoff, no bounded wait. A rate limit and an expired token end it the same way.
- **Reading the full tracker costs more.** `tracker.md` is one file read. A board reconstructs the effort, the slice and the status in one call, but the merge commit lives in a comment on each issue, so a full read costs one call plus one more per merged slice. The read is complete or refused: it checks what came back against the count the board reports, and a board it cannot read whole stops the run rather than passing off part of it as all of it.
- **Moving onto GitHub deletes your `tracker.md`.** Choosing GitHub on a project that already has a `tracker.md` carries every row onto the board as an issue, then deletes the file once a read of the board back matches it row for row, status and merge commit included. `setup` describes the batch first, how many rows and how many milestones, and asks for one approval covering the whole thing, before either key is written, so refusing writes no key and leaves the rows where they are. That delete needs the operator's approval on a public repository and a private one alike; the per-write confirmation above is the only part that depends on whether the repository is public.

Moving back costs something different:

- **It needs your approval, the same way.** `setup` describes the batch first, how many rows and how many milestones are on the board, before closing or removing anything. Decline and it tells you the same thing: how many rows are on the board and that leaving them there strands them. The run stops there and writes no key.
- **It closes every issue and removes every item from the board.** That removal is the only delete the reverse makes, and it starts only after the rebuilt `tracker.md` has been read back against the board and matched row for row. The issues stay, closed rather than gone. The board stays too, untouched apart from the removals. Each milestone closes, once every row under it is back, rather than being deleted.
- **An interrupted run can leave rows on both surfaces until you run `setup` again.** That is deliberate. A row nobody can get back is worse than a duplicate a second run clears up.

## Upgrading

```bash
claude plugin marketplace update bytesnation
claude plugin update capstan@bytesnation
```

The first refreshes the marketplace catalogue and changes no installed plugin by itself. The second moves your install onto the new version and needs the marketplace-qualified name: `capstan@bytesnation` resolves, a bare `capstan` does not. Reaching for `install` instead does nothing useful: it reports the plugin is already installed and leaves the old version running. Add `-s project` if that is where you installed, then restart Claude Code.

Leave the `/plugin` auto-update toggle off, the same as for any third-party marketplace.

### Moving the marketplace to a different address

No command edits a marketplace's source in place, and editing `~/.claude/plugins/known_marketplaces.json` by hand does not hold, because the next `claude plugin marketplace update` puts the old address back. Removing and re-adding is the route that sticks.

**Removing a marketplace uninstalls every plugin installed from it.** The install record empties and the marketplace clone is deleted, so the second and third commands here are the repair rather than tidying afterwards. Run the first alone and you have no Capstan:

```bash
claude plugin marketplace remove bytesnation
claude plugin marketplace add MokeyBytes/capstan
claude plugin install capstan@bytesnation --scope user
```

Use `--scope project` on the last command if that is where it was installed. `capstan@bytesnation` survives the round trip because a marketplace takes its name from the `name` field in its `marketplace.json` rather than from the repository path, so re-adding from a different address produces the same marketplace and the same plugin identifier.

The version cache under `~/.claude/plugins/cache/` is untouched throughout. A session open while you do this keeps resolving skills from the copy it already holds, and picks up the reinstall when you restart it.

## Installing by hand

```bash
git clone https://github.com/MokeyBytes/capstan.git
cp -r capstan/agents/* ~/.claude/agents/
cp -r capstan/skills/* ~/.claude/skills/
```

Run `/setup` next, in the repository you plan to work in, to choose where the glossary, decision log, decision records and tracker should live. Skip it and your first effort offers you the default or sends you back here. Then start work with `/effort <what you want built>`.

A plugin namespaces what it ships, so the Builder is `capstan:builder` under a plugin install and plain `builder` under a manual one. [`skills/effort/SKILL.md`](skills/effort/SKILL.md) tells the Architect which agent to spawn for each role, so use whichever form your install produced. The plugin path is the exercised one: installing, updating, and a full remove and re-add have all been run against it. The manual copy is there for a setup with no marketplace, and sees less use.

Copying over an existing manual install leaves behind any file a new version dropped or renamed. Replace a skill outright rather than copying onto it:

```bash
rm -rf ~/.claude/skills/effort
cp -r capstan/skills/effort ~/.claude/skills/
```

### Some skills are more than one file

Most skills here are a lone `SKILL.md`. The ones below are not, and lifting only the `SKILL.md` out of one of them leaves pointers aimed at files that are not there.

```
skills/effort/
  SKILL.md              identity, the crew, the gates, the precondition, phase 1
  PHASE-2-PLAN.md
  PHASE-3-BUILD.md
  PHASE-4-DELIVER.md
  TRACKER-GITHUB.md     the board surface, read when capstan-tracker names one
  bin/                  capstan-claim, capstan-scratch-clean, capstan-tracker: called by the phases above and by setup and verify

skills/writing-for-agents/
  SKILL.md
  SKILL-MECHANICS.md    frontmatter, invocation, router skills
  AUDIT.md              the editing pass to run against a target document
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/walkthrough/
  SKILL.md              identity, how to author a stage, the two guards before a write leaves the machine
  template.sh           the library, forked from upstream; CREDIT.md lists every change
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/codebase-design/
  SKILL.md              the vocabulary and its principles
  DEEPENING.md          dependency categories, seam discipline, replace-don't-layer testing
  DESIGN-IT-TWICE.md    parallel sub-agents designing one interface several ways
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/diagnosing-bugs/
  SKILL.md              vendored, three repointed lines
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/to-questionnaire/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/resolving-merge-conflicts/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see the licence section

skills/unslop/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see the licence section
```

The Architect reads the file for the phase it is in, so a run that reaches gate two with no `PHASE-2-PLAN.md` beside it has nothing to follow and improvises a plan phase instead. Take the whole directory. The helpers under `skills/effort/bin/` need bash 3.2 or later and git; `capstan-tracker` also needs `gh`.

## Checks

```bash
bash tests/run.sh
```

That runs every behavioural test under `tests/`, against the helpers and the walkthrough library, in temporary repositories with a mock `gh`, so nothing needs credentials or a network. The mock needs `jq`, which the helpers themselves do not. It also runs `shellcheck` when installed. The same command runs in CI on Linux and macOS, and running it with `/bin/bash` on a Mac exercises everything under bash 3.2.

## Known limits

**`/capstan:effort` cannot be invoked by a model.** It carries `disable-model-invocation: true`, so only you start an effort. An agent that can start work on its own authority can commit you to work you never asked for. It does mean kickoff is always something you type.

**Bash is an escape hatch.** Scout's read-only guarantee is structural: its tool grant holds no write tools, so the harness enforces it. Builder, Reviewer and Courier all hold Bash, so their "never do X" rules are prose rather than enforcement. Add a deny list to `settings.json` if you want the gates enforced instead of requested.

**Builder runs with `acceptEdits`.** File writes never prompt. Bash commands still can, which is where unattended fan-out tends to stall.

**Effort is not supported on Haiku.** Drop the `effort:` frontmatter line from any agent you point at a Haiku model.

**Fan-out does nothing for single-artifact work.** Parallel Builders need slices that own different files. A document, a video script, a single config file: each is one artifact and inherently one Builder. Software usually fans out because slices own different things. Most other work does not, and a one-slice plan there is correct rather than a failure to parallelise.

**The helpers refuse; they do not intercept.** `capstan-claim` refuses a second owner, a sixth fix dispatch, or a fourth Builder only when the Architect calls it, which the skills tell it to do before every such step. Nothing stops an agent from running `rm -rf` or spawning a Builder by hand. The tests prove what each helper does when called, not that every agent calls it.

**The board read has been tested against a mock, not a live board, since the helper landed.** `capstan-tracker`'s completeness check, repository scoping and diff are exercised by `tests/test_tracker.sh` against a mock `gh` built from gh 2.101.0's own JSON shape. The first real migration through it is the integration trial still owed.

**The knowledge-base note is reviewed whole, when there is one.** The note is never committed, so it has no fixed point to diff against, and the Reviewer reads the whole file rather than a diff. A project with no `capstan-knowledge-base` key gets no note, and then there is nothing to review.

## Licence

MIT. See [LICENSE](LICENSE). Take it, change it, ship it.

Some skills here are not ours. Every one is MIT, and every one is redistributed with its own licence and a `CREDIT.md` in its folder recording exactly what changed:

- [`skills/writing-for-agents/`](skills/writing-for-agents/): `SKILL.md` and `SKILL-MECHANICS.md` by [Matt Pocock](https://github.com/mattpocock/skills). `AUDIT.md` beside them is ours.
- [`skills/unslop/`](skills/unslop/): `SKILL.md` by [Lauren Tan](https://github.com/cursor/plugins/tree/main/pstack/skills/unslop), via cursor/plugins. Two lines changed.
- [`skills/walkthrough/`](skills/walkthrough/): `template.sh` by [Matt Pocock](https://github.com/mattpocock/skills), forked: the library stops on closed input, validates keys, and refuses multi-line values, with every change listed in its `CREDIT.md` and covered by `tests/test_walkthrough.sh`. `SKILL.md` beside it is ours, written fresh around the library.
- [`skills/diagnosing-bugs/`](skills/diagnosing-bugs/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Three lines repointed at Capstan's own paths and at `walkthrough`.
- [`skills/codebase-design/`](skills/codebase-design/): `SKILL.md`, `DEEPENING.md` and `DESIGN-IT-TWICE.md` by [Matt Pocock](https://github.com/mattpocock/skills). One line repointed; the other two files are byte-identical.
- [`skills/to-questionnaire/`](skills/to-questionnaire/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Two changes: the invocation flag, and where the document lands and where its answers go.
- [`skills/resolving-merge-conflicts/`](skills/resolving-merge-conflicts/): `SKILL.md` by [Matt Pocock](https://github.com/mattpocock/skills). Two changes: where a hunk's intent is found, and one exception to never aborting.

Beyond those, nothing is vendored, though some ideas are borrowed, all from [Matt Pocock](https://github.com/mattpocock/skills). The prose is ours; the mechanics are his.

- The frontier in `interview`: a design tree, where a question depending on an open question waits for a later round. Sharpened from `grilling`.
- The `next` section in `CLAIM.md`: what the run after this one picks up, written for the agent that resumes rather than the person at the gate. From `handoff`, sized down to a field in a file that already exists. The fix-dispatch counts that once rode in it now have a line of their own, where a helper can read them.
- The `unformed` status in the decision log: an area nobody can phrase a question about yet. His fog of war from `wayfinder`, without the issue tracker it is charted on.
- Two moves in `interview`: challenging a term against the glossary rather than only within the session, and inventing an edge-case scenario when a relationship between concepts stays vague. From `domain-modeling`, minus its file layout.
