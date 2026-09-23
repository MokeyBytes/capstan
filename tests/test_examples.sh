#!/usr/bin/env bash
# Behaviour of examples/settings.deny.json: valid JSON, the exact top-level
# shape a settings fragment needs, every pattern required, and a shape
# check that catches a malformed entry the presence checks below would miss.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

JSON="$REPO_ROOT/examples/settings.deny.json"
README="$REPO_ROOT/examples/README.md"

REQUIRED_BASH=(
  "Bash(git stash *)"
  "Bash(git -C * stash)"
  "Bash(git -C * stash *)"
  "Bash(git push --force*)"
  "Bash(git push * --force*)"
  "Bash(git push -f*)"
  "Bash(git push * -f*)"
  "Bash(git -C * push --force*)"
  "Bash(git -C * push * --force*)"
  "Bash(git -C * push -f*)"
  "Bash(git -C * push * -f*)"
  "Bash(rm -rf*)"
  "Bash(rm -fr*)"
  "Bash(rm -Rf*)"
  "Bash(rm -fR*)"
  "Bash(rm -r -f*)"
  "Bash(rm -f -r*)"
  "Bash(gh auth login *)"
  "Bash(gh auth logout *)"
  "Bash(gh auth refresh *)"
  "Bash(gh auth token *)"
  "Bash(gh auth switch *)"
  "Bash(gh auth setup-git *)"
  "Bash(gh auth status -t*)"
  "Bash(gh auth status * -t*)"
  "Bash(gh auth status --show-token*)"
  "Bash(gh auth status * --show-token*)"
)

# Read and Edit for every path the plan names.
REQUIRED_FILE=(
  "Read(//**/.env)"
  "Read(//**/.env.*)"
  "Read(~/.config/gh/**)"
  "Read(~/.aws/credentials)"
  "Read(~/.ssh/**)"
  "Read(~/.netrc)"
  "Edit(//**/.env)"
  "Edit(//**/.env.*)"
  "Edit(~/.config/gh/**)"
  "Edit(~/.aws/credentials)"
  "Edit(~/.ssh/**)"
  "Edit(~/.netrc)"
)

deny_has() { # pattern
  jq --arg p "$1" 'any(.permissions.deny[]?; . == $p)' "$JSON" 2>&1
}

# every_entry_has_valid_shape FILE returns the deny entries that are not a
# Bash, Read or Edit rule, or that anchor a Read/Edit rule with a single
# leading slash, which settles at the settings source rather than the
# filesystem root a reader would expect. An empty array means every entry
# is well-formed.
every_entry_has_valid_shape() {
  jq -c '
    [.permissions.deny[] | select(
      (type != "string")
      or (test("^(Bash|Read|Edit)\\(.+\\)$") | not)
      or (test("^(Read|Edit)\\(/[^/]"))
    )]
  ' "$1" 2>&1
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

test_every_deny_entry_has_valid_shape() {
  local out
  out=$(every_entry_has_valid_shape "$JSON")
  assert_eq "[]" "$out" "a deny entry is not a Bash, Read or Edit rule, or a Read/Edit rule anchors with a single leading slash"
}

test_shape_check_rejects_a_misspelled_tool_name() {
  local dir out
  dir=$(tmpdir)
  jq '.permissions.deny += ["Raed(.env)"]' "$JSON" > "$dir/settings.json"
  out=$(every_entry_has_valid_shape "$dir/settings.json")
  assert_eq '["Raed(.env)"]' "$out" "shape check should flag Raed(.env)"
}

test_shape_check_rejects_a_non_string_entry() {
  local dir out
  dir=$(tmpdir)
  jq '.permissions.deny += [42]' "$JSON" > "$dir/settings.json"
  out=$(every_entry_has_valid_shape "$dir/settings.json")
  assert_eq '[42]' "$out" "shape check should flag the non-string entry 42"
}

test_shape_check_rejects_a_single_leading_slash() {
  local dir out
  dir=$(tmpdir)
  jq '.permissions.deny += ["Read(/.env)"]' "$JSON" > "$dir/settings.json"
  out=$(every_entry_has_valid_shape "$dir/settings.json")
  assert_eq '["Read(/.env)"]' "$out" "shape check should flag Read(/.env), which anchors at the settings source, not the filesystem root"
}

test_readme_exists() {
  assert_file "$README"
}

run_tests
