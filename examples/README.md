# Example deny list

`settings.deny.json` is a settings fragment: `{"permissions": {"deny": [...]}}`. It blocks a short list of commands and paths that are easy to type by accident and hard to undo. Copy the `deny` array into a real settings file; do not point Claude Code at this file directly.

## Where to put it

Merge the `deny` array into the `permissions.deny` array of whichever settings file fits:

- `~/.claude/settings.json`, applies to every project on the machine.
- `.claude/settings.json`, applies to this project, checked into version control.
- `.claude/settings.local.json`, applies to this project, on this machine only, not checked in.

Claude Code reads deny rules from all of these at once and combines them, so add the array to one file rather than duplicating it everywhere. If that file already has a `permissions.deny` array, append these entries to it instead of overwriting it.

## What it enforces

Deny wins over allow. If any settings file denies a command, no other settings file can allow it, and rule specificity doesn't change that. Deny also holds in every permission mode, including `bypassPermissions`, where allow rules stop mattering but deny rules still block.

`Read` and `Edit` deny rules reach further than the tool names suggest. They also cover file commands Claude Code recognizes inside `Bash`, such as `cat`, `head`, `tail`, `sed`, and `tee`, and the target of a shell redirect like `> .env`.

A `Bash` deny rule also reaches past the exact command shape it names. Claude Code splits a compound command on `&&`, `||`, `;`, `|`, `|&`, `&`, and newlines, and checks each piece on its own, so `Bash(git stash *)` still blocks `cd /tmp && git stash`. It also strips a fixed set of wrappers before matching, including `timeout`, `nohup`, and bare `xargs`, so `Bash(rm -rf*)` still blocks `timeout 5 rm -rf tmp/`. Claude Code also strips a leading `VAR=value` assignment, so the same rule blocks `FOO=1 rm -rf tmp/`.

This list applies to the main session and to every subagent it runs, not to the operator's own terminal.

## What it does not enforce

A `Bash` deny rule matches the command text Claude writes, not the program underneath it. Each rule below stops the form a model normally produces, and the forms after it name what stays open:

- `Bash(rm -rf*)` and its five siblings stop `rm -rf`, `rm -fr`, `rm -Rf`, `rm -fR`, `rm -r -f`, and `rm -f -r`. They do not stop `/bin/rm -rf`, `bash -c 'rm -rf ...'`, `rm --recursive --force`, or a script that deletes files through its own code, such as Python's `shutil.rmtree`.
- `Bash(git stash *)` stops a bare `git stash` and covers every stash subcommand, such as `git stash pop` and `git stash list`. `Bash(git -C * stash)` and `Bash(git -C * stash *)` stop the same commands run as `git -C <dir> stash`, the form this repository's own Builders write. Neither pair stops `git -c core.pager=cat stash` or `git --git-dir=<dir> stash`.
- `Bash(git push --force*)` and its seven siblings stop `git push --force`, `git push -f`, and `git push --force-with-lease`, whether the flag sits right after `push`, after another argument, or after a leading `-C <dir>`. None of them stop a force push spelled as a `+refspec`, such as `git push origin +main`, or as a bundled short flag, such as `git push -uf`, because neither text contains `--force` or a standalone `-f`. `git -c push.default=current push -f` also gets through, because every rule begins with `git push` or `git -C`.
- The matcher has no one-word wildcard, so the `-C` rules above also match past the command they name: any `git -C <dir>` command whose text has `stash` as a separate word, such as `git -C <dir> grep -n stash` or a commit message like "Add git -C stash rules", is denied too. So is one with `push` followed by a separate `-f` or `--force`. To avoid it, delete the `-C` rules and check those commands in a [PreToolUse hook](https://code.claude.com/docs/en/permissions#extend-permissions-with-hooks) instead. A hook can't reopen a command that a deny rule matches.
- `Bash(gh auth login *)`, `logout`, `refresh`, and `switch` stop the four subcommands that change which account is signed in. `gh auth token` prints the token to stdout, so `Bash(gh auth token *)` blocks a credential read rather than a session change. `Bash(gh auth setup-git *)` stops `gh` from rewriting git's credential helper. `Bash(gh auth status -t*)` and its three siblings stop `gh auth status --show-token` and its `-t` short form, which print the same token `gh auth token` does; a plain `gh auth status` stays open, since it only reads state. Two other forms print the token and stay open. `gh auth status -at` gets through because the rules need `-t` as a separate word. `gh auth git-credential get`, the helper `gh auth setup-git` installs, prints the token when asked through git's credential protocol.
- The `Read`/`Edit` rules for `.env`, `.env.*`, `~/.ssh/**`, `~/.aws/credentials`, `~/.netrc`, and `~/.config/gh/**` do not stop `grep -r pattern .`, which reads files without naming them, or any subprocess that opens a file itself rather than going through a tool or a recognized Bash command.
- Subagent frontmatter can only allow or remove a whole tool, not a scoped pattern like `Bash(git checkout:*)`, so a rule this fine-grained has to live in `permissions.deny` instead. That is also why `git checkout` and `git switch` are absent: a deny rule here would bind a Builder's shell and the Architect's alike, not just the Builder it is meant to constrain.

The `.env` and `.env.*` rules anchor at the filesystem root with `//**/`, so they block a `.env` file anywhere on the machine, not only inside the current project. `.env.*` also blocks `.env.example` and `.env.sample`, the templates most projects check into version control. The docs' own carve-out, a `!` rule such as `Read(!sample.env)`, cannot reach a rule anchored with `//`, `~/`, or `/`: Claude Code reads a `!` pattern relative to the current directory regardless of what prefix follows it. An allow rule can't carve an exception out of a deny rule in any case. Exempting a template file needs one of two changes:

- Delete both `.env.*` lines and keep `.env`.
- In the settings file that holds these rules, replace `Read(//**/.env.*)` and `Edit(//**/.env.*)` with the cwd-relative `Read(.env.*)` and `Edit(.env.*)`, then add `Read(!.env.example)` and `Edit(!.env.example)` after them.

`.env.*` is then covered only under the current directory.

None of this is a security boundary around what a process can actually do. It's Claude Code's own command-text matcher, and a determined script can walk straight past it. The [OS sandbox](https://code.claude.com/docs/en/sandboxing) is the real boundary: it enforces at the filesystem and network level regardless of what a command is called.

Source: [Configure permissions](https://code.claude.com/docs/en/permissions), fetched 2026-09-22.
