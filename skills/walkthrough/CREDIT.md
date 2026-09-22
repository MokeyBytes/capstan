# Credit

`template.sh` in this folder is the work of Matt Pocock, taken from
[mattpocock/skills](https://github.com/mattpocock/skills) under the MIT licence.
The full licence text sits beside it in `LICENSE`, and it is the licence that
governs that file.

`template.sh` is a declared fork, not a byte-identical copy, since 2026-09-22.
The stages section below the `STAGES` marker is upstream's, unchanged. The
library above it carries these local changes, made so that a closed stdin or
a malformed value stops the script instead of writing something wrong, per
[decision record 0005](../../.capstan/decisions/0005-fork-the-walkthrough-library.md):

- `_valid_key` (new): a key must match `^[A-Za-z_][A-Za-z0-9_]*$`; anything
  else is named on stderr and the script exits 1 before touching the file.
- `_input_closed` (new): stdin closing (EOF) during any prompt prints what was
  already written and exits 1. Upstream's `read ... || true` read EOF as an
  empty value and carried on.
- `pause`, `confirm`: EOF stops the script through `_input_closed` instead of
  continuing, or reading as a decline.
- `ask`, `ask_secret`: both delegate to a shared `_read_value`. Enter keeps a
  value already in `ENV_FILE` and says so; Enter with no value there asks
  `Leave KEY empty?` and re-prompts on no, so an empty value is always
  deliberate; a trailing carriage return from a pasted CRLF is dropped.
- `_existing`: validates the key first.
- `write_env`: validates the key; refuses a value holding a line break and
  writes nothing; replaces the key's line where it stands, drops a later
  duplicate, and keeps every other line in order (upstream removed the line
  and appended at the end); repairs a missing final newline before appending;
  rebuilds through a temp file beside `ENV_FILE` and copies back, so a
  symlinked `.env` and its mode survive; records the write only after it
  succeeds. Values are still written byte-for-byte, unquoted.
- `set_secret`, `set_var`: an empty value is not pushed; it is recorded under
  `SKIPPED` and warned about. Upstream would have overwritten a live secret
  with nothing.
- `_write_env_cleanup` (new) and three `trap` lines: the temp file `write_env`
  builds beside `ENV_FILE` is removed on any exit, an interrupt included, so a
  Ctrl-C mid-write never leaves a copy of every captured value under a name
  `.gitignore` does not cover.
- Header comment: three lines stating the above. One `shellcheck` directive on
  the colour block, which upstream also needed.

The file keeps the executable bit (upstream tracks it as `100644`, ours as
`100755`), since a shebang script needs it to run directly. `SKILL.md` is
ours, written fresh around the library.

Every change above is covered by `tests/test_walkthrough.sh` at the
repository root. To refresh from upstream, re-fetch `template.sh`, re-apply
the list above, and run those tests before replacing this copy.
