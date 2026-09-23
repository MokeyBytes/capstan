#!/usr/bin/env bash
# Behaviour of examples/settings.deny.json: valid JSON, the exact top-level
# shape a settings fragment needs, and every pattern the plan requires.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

JSON="$REPO_ROOT/examples/settings.deny.json"
README="$REPO_ROOT/examples/README.md"

# Every Bash rule the plan requires: git stash in all forms, the three
# git push force spellings reachable from more than one argument position,
# rm -rf/-fr/-r -f, and the five mutating gh auth subcommands.
REQUIRED_BASH=(
  "Bash(git stash *)"
  "Bash(git push --force*)"
  "Bash(git push * --force*)"
  "Bash(git push -f*)"
  "Bash(git push * -f*)"
  "Bash(rm -rf*)"
  "Bash(rm -fr*)"
  "Bash(rm -r -f*)"
  "Bash(gh auth login *)"
  "Bash(gh auth logout *)"
  "Bash(gh auth refresh *)"
  "Bash(gh auth token *)"
  "Bash(gh auth switch *)"
)

# Read and Edit for every path the plan names.
REQUIRED_FILE=(
  "Read(.env)"
  "Read(.env.*)"
  "Read(~/.config/gh/**)"
  "Read(~/.aws/credentials)"
  "Read(~/.ssh/**)"
  "Read(~/.netrc)"
  "Edit(.env)"
  "Edit(.env.*)"
  "Edit(~/.config/gh/**)"
  "Edit(~/.aws/credentials)"
  "Edit(~/.ssh/**)"
  "Edit(~/.netrc)"
)

deny_has() { # pattern
  jq --arg p "$1" 'any(.permissions.deny[]?; . == $p)' "$JSON" 2>&1
}

test_json_file_exists() {
  assert_file "$JSON"
}

test_json_parses() {
  local out
  if out=$(jq empty "$JSON" 2>&1); then
    return 0
  fi
  fail "jq could not parse $JSON: $out"
}

test_top_level_shape_is_exactly_permissions_deny() {
  local out
  out=$(jq -e '
    (keys == ["permissions"])
    and (.permissions | keys == ["deny"])
    and (.permissions.deny | type == "array")
  ' "$JSON" 2>&1)
  assert_eq "true" "$out" "top-level shape is not {permissions: {deny: [...]}}"
}

test_every_required_bash_pattern_is_present() {
  local p out
  for p in "${REQUIRED_BASH[@]}"; do
    out=$(deny_has "$p")
    assert_eq "true" "$out" "missing Bash rule: $p"
  done
}

test_every_required_file_pattern_is_present() {
  local p out
  for p in "${REQUIRED_FILE[@]}"; do
    out=$(deny_has "$p")
    assert_eq "true" "$out" "missing Read/Edit rule: $p"
  done
}

test_readme_exists() {
  assert_file "$README"
}

run_tests
