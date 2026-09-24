# Installing by hand

```bash
git clone https://github.com/MokeyBytes/capstan.git
cp -r capstan/agents/* ~/.claude/agents/
cp -r capstan/skills/* ~/.claude/skills/
```

Run `/setup` next, in the repository you plan to work in, to choose where the glossary, decision log, decision records and tracker file live. Skip it and your first effort offers you the default or sends you back here. Then start work with `/effort <what you want built>`, or `/quick <something small>` for one slice through a single gate.

A plugin namespaces what it ships, so the Builder is `capstan:builder` under a plugin install and plain `builder` under a manual one. [`skills/effort/SKILL.md`](../skills/effort/SKILL.md) tells the Architect which agent to spawn for each role, so use whichever form your install produced. The plugin path is the exercised one: installing, updating, and a full remove and re-add have all been run against it. The manual copy is there for a setup with no marketplace, and sees less use.

Copying over an existing manual install leaves behind any file a new version dropped or renamed. Replace a skill outright rather than copying onto it:

```bash
rm -rf ~/.claude/skills/effort
cp -r capstan/skills/effort ~/.claude/skills/
```

**The board surface has no manual form.** `capstan-board` is a plugin-install-only feature: its `tracker` and `setup` skills ship only inside that plugin, and a `setup` copied under `~/.claude/skills/` would collide with core's own skill of the same name. See [tracker surface](tracker.md) for what the board needs instead.

**Nor does `agent-models`.** It reads the installed plugin's own `.claude-plugin/plugin.json` to learn the version an override is copied from, and a manual install has no such file for it to find. Retune a manual install's agents by hand instead: edit the `model` and `effort` lines in each copied `agents/<role>.md` directly.

## Some skills are more than one file

Most skills here are a lone `SKILL.md`. The ones below are not, and lifting only the `SKILL.md` out of one of them leaves pointers aimed at files that are not there.

```
skills/effort/
  SKILL.md              identity, the crew, the gates, the precondition, phase 1
  PHASE-2-PLAN.md
  PHASE-3-BUILD.md
  PHASE-4-DELIVER.md
  bin/                  capstan-claim, capstan-scratch-clean, capstan-log: called by the phases above and by verify

skills/writing-for-agents/
  SKILL.md
  SKILL-MECHANICS.md    frontmatter, invocation, router skills
  AUDIT.md              the editing pass to run against a target document
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/walkthrough/
  SKILL.md              identity, how to author a stage, the two guards before a write leaves the machine
  template.sh           the library, forked from upstream; CREDIT.md lists every change
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/codebase-design/
  SKILL.md              the vocabulary and its principles
  DEEPENING.md          dependency categories, seam discipline, replace-don't-layer testing
  DESIGN-IT-TWICE.md    parallel sub-agents designing one interface several ways
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/diagnosing-bugs/
  SKILL.md              vendored, three repointed lines
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/to-questionnaire/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/resolving-merge-conflicts/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits

skills/unslop/
  SKILL.md              vendored, two local changes
  LICENSE, CREDIT.md    upstream is MIT, see README.md's credits
```

`skills/quick/` and every other skill not listed above is a lone `SKILL.md`: copy the file and it works.

The Architect reads the file for the phase it is in, so a run that reaches gate two with no `PHASE-2-PLAN.md` beside it has nothing to follow and improvises a plan phase instead. Take the whole directory. The helpers under `skills/effort/bin/` need bash 3.2 or later and git.
