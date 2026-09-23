# Example deny list

`settings.deny.json` is a settings fragment: `{"permissions": {"deny": [...]}}`. It blocks a short list of commands and paths that are easy to type by accident and hard to undo. Copy the `deny` array into a real settings file; do not point Claude Code at this file directly.

## Where to put it

Merge the `deny` array into the `permissions.deny` array of whichever settings file fits:

- `~/.claude/settings.json` — applies to every project on the machine.
- `.claude/settings.json` — applies to this project, checked into version control.
- `.claude/settings.local.json` — applies to this project, on this machine only, not checked in.

Claude Code reads deny rules from all of these at once and combines them, so add the array to one file rather than duplicating it everywhere. If that file already has a `permissions.deny` array, append these entries to it instead of overwriting it.

## What it enforces

Deny wins over allow. If any settings file denies a command, no other settings file can allow it, and rule specificity doesn't change that. Deny also holds in every permission mode, including `bypassPermissions`, where allow rules stop mattering but deny rules still block.

`Read` and `Edit` deny rules reach further than the tool names suggest. They also cover file commands Claude Code recognizes inside `Bash`, such as `cat`, `head`, `tail`, `sed`, and `tee`, and the target of a shell redirect like `> .env`.

## What it does not enforce

A `Bash` deny rule matches the command text Claude writes, not the program underneath it. Each rule below stops the form a model normally produces and nothing else:

- `Bash(rm -rf*)` stops `rm -rf`. It does not stop `/bin/rm -rf`, `bash -c 'rm -rf ...'`, or a script that deletes files through its own code (Python's `shutil.rmtree`, for instance).
- `Bash(git push --force*)` and its three siblings stop `git push --force`, `git push -f`, and `git push --force-with-lease` when the flag sits right after `push` or after the other push arguments, since that covers how these are normally typed. A push invoked another way, such as `git -C . push --force` or `git -c push.default=current push -f`, is not matched — the rule text has to start with `git push` exactly.
- `Bash(gh auth login *)` and the other four `gh auth` rules stop the five subcommands that log a session in, out, or over: `login`, `logout`, `refresh`, `token`, `switch`. `gh auth status` is deliberately left open; it only reads state.
- The `Read`/`Edit` rules for `.env`, `.env.*`, `~/.ssh/**`, `~/.aws/credentials`, `~/.netrc`, and `~/.config/gh/**` do not stop `grep -r pattern .`, which reads files without naming them, or any subprocess that opens a file itself rather than going through a tool or a recognized Bash command.

`git checkout` and `git switch` are absent on purpose. A deny rule can't be scoped to one subagent: subagent frontmatter only allows or removes whole tools, and a `permissions.deny` rule written for `Bash(git checkout:*)` would apply to the main session and the operator's own terminal too, not just the Builder it was meant to constrain.

None of this is a security boundary around what a process can actually do. It's Claude Code's own command-text matcher, and a determined script can walk straight past it. The [OS sandbox](https://code.claude.com/docs/en/sandboxing) is the real boundary: it enforces at the filesystem and network level regardless of what a command is called.

Source: [Configure permissions](https://code.claude.com/docs/en/permissions), fetched 2026-09-22.
