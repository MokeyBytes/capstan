#!/usr/bin/env bash
# Runs every tests/test_*.sh file and, when shellcheck is installed, lints the
# helpers. No network, no credentials: gh is always a mock under tests/.
set -u
cd "$(dirname "$0")/.." || exit 1

export TEST_TMP_ROOT
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/capstan-tests.XXXXXX")"
trap 'rm -rf "$TEST_TMP_ROOT"' EXIT

# Whichever bash runs this file runs everything under it: the test files, and
# the helpers, whose `#!/usr/bin/env bash` resolves through this shim first.
# So `/bin/bash tests/run.sh` on macOS exercises bash 3.2 throughout.
mkdir -p "$TEST_TMP_ROOT/shim"
ln -s "$BASH" "$TEST_TMP_ROOT/shim/bash"
export PATH="$TEST_TMP_ROOT/shim:$PATH"
printf 'bash: %s (%s)\n' "$BASH" "$BASH_VERSION"

status=0
if ! command -v jq >/dev/null 2>&1; then
  printf '== jq is not installed: tests/mock/gh needs it to apply --jq, so tests/test_tracker.sh cannot run\n'
  status=1
fi
for f in tests/test_*.sh; do
  printf '== %s\n' "$f"
  "$BASH" "$f" || status=1
done

if command -v shellcheck >/dev/null 2>&1; then
  printf '== shellcheck\n'
  if shellcheck -s bash skills/effort/bin/* skills/walkthrough/template.sh bench/bin/* tests/*.sh tests/mock/*; then
    printf '  ok   shellcheck\n'
  else
    status=1
  fi
else
  printf '== shellcheck not installed, skipped\n'
fi

for f in skills/effort/bin/* skills/walkthrough/template.sh bench/bin/*; do
  bash -n "$f" || status=1
done

[[ $status -eq 0 ]] && printf 'all checks passed\n' || printf 'CHECKS FAILED\n'
exit $status
