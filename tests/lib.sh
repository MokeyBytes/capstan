#!/usr/bin/env bash
# Shared assertions for the test files under tests/. Sourced, never run.
# Every test file: source this, define test_* functions, and end with `run_tests`.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/skills/effort/bin"
export REPO_ROOT BIN

_T_PASS=0
_T_FAIL=0
_T_CURRENT=""

fail() {
  printf '  FAIL %s: %s\n' "$_T_CURRENT" "$*" >&2
  _T_FAIL=$((_T_FAIL + 1))
  return 1
}

assert_eq() { # expected actual [message]
  if [[ "$1" != "$2" ]]; then
    fail "${3:-values differ}: expected [$1] got [$2]"
  fi
}

assert_exit() { # expected-code actual-code [message]
  if [[ "$1" != "$2" ]]; then
    fail "${3:-exit code}: expected $1 got $2"
  fi
}

assert_contains() { # haystack needle [message]
  case "$1" in
    *"$2"*) ;;
    *) fail "${3:-missing text}: [$2] not in [$1]" ;;
  esac
}

assert_not_contains() { # haystack needle [message]
  case "$1" in
    *"$2"*) fail "${3:-unexpected text}: [$2] found in [$1]" ;;
  esac
}

assert_file() { # path [message]
  [[ -e "$1" ]] || fail "${2:-expected path to exist}: $1"
}

assert_no_file() { # path [message]
  [[ ! -e "$1" && ! -L "$1" ]] || fail "${2:-expected path to be absent}: $1"
}

# tmpdir prints a fresh temporary directory under the test scratch root.
tmpdir() {
  mktemp -d "${TEST_TMP_ROOT:-${TMPDIR:-/tmp}}/capstan-test.XXXXXX"
}

# git_repo DIR initialises a repository with one commit and prints HEAD.
git_repo() {
  git -C "$1" init -q -b main
  git -C "$1" config user.email test@example.invalid
  git -C "$1" config user.name test
  printf 'seed\n' > "$1/README"
  git -C "$1" add README
  git -C "$1" commit -q -m seed
  git -C "$1" rev-parse HEAD
}

run_tests() {
  local name
  for name in $(declare -F | awk '{print $3}' | grep '^test_' | sort); do
    _T_CURRENT="$name"
    local before=$_T_FAIL
    if ! "$name"; then
      [[ $_T_FAIL -gt $before ]] || fail "returned non-zero"
    fi
    if [[ $_T_FAIL -eq $before ]]; then
      _T_PASS=$((_T_PASS + 1))
      printf '  ok   %s\n' "$name"
    fi
  done
  printf '%s: %d passed, %d failed\n' "$(basename "$0")" "$_T_PASS" "$_T_FAIL"
  [[ $_T_FAIL -eq 0 ]]
}
