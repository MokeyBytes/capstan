# Checks

```bash
bash tests/run.sh
```

That runs every behavioural test under `tests/` and `plugins/*/tests/`, against the helpers and the walkthrough library, in temporary repositories with a mock `gh`, so nothing needs credentials or a network. The mock needs `jq`, which the helpers themselves do not. It also runs `shellcheck` when installed, and `bash -n` over every helper.

## What CI runs

Two jobs, defined in `.github/workflows/checks.yml`:

- **`tests`**, on an `ubuntu-latest`/`macos-latest` matrix. It runs `bash tests/run.sh`, then runs `tests/test_walkthrough.sh` a second time under a `PATH` shim that makes `id -u` print `0`, to exercise the root-safe skip branch on ordinary CI without a real root shell.
- **`root`**, in an `ubuntu:24.04` container, actually running as root. `test_write_fails_on_readonly_env` skips there, since root ignores file modes and the test needs one a non-root user cannot override, printing `skipped (root)` once. `test_interrupted_write_leaves_no_temp_file` still runs its Ctrl-C half under real root.

Running the suite with `/bin/bash` rather than a newer bash on your own Mac exercises the same bash 3.2 path both jobs do: `tests/run.sh` shims `bash` on `PATH` to whatever shell invoked it, so every helper it calls resolves through that same interpreter.
