#!/usr/bin/env bash
# Behavioural tests for the walkthrough library in skills/walkthrough/template.sh.
# Each case runs the library in a fresh bash inside a throwaway directory, with
# stdin fed from a string, and judges only what came out: the exit code, the
# combined output, and the bytes left in .env. gh is always a mock written into
# that directory and PATH is limited to that directory, so no case can reach
# the real gh or the network.

# The statements handed to run_lib below are bash for the child shell, so their
# $vars are meant to stay literal here. lib.sh is not followed because run.sh
# lints without -x.
# shellcheck disable=SC2016,SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ -z "${TEST_TMP_ROOT:-}" ]]; then
  TEST_TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/capstan-tests.XXXXXX")
  trap 'rm -rf "$TEST_TMP_ROOT"' EXIT
fi

TEMPLATE="$REPO_ROOT/skills/walkthrough/template.sh"

# The library is everything above the STAGES marker. The example stages below
# it run on source, so they are cut off once here and every case sources the
# remainder.
WALK_LIB="$(tmpdir)/lib.sh"
_marker=$(grep -n '# STAGES:' "$TEMPLATE" | head -n1 | cut -d: -f1)
head -n "$((_marker - 1))" "$TEMPLATE" > "$WALK_LIB"
export WALK_LIB

# sandbox prints a fresh directory holding a tools/ PATH entry with only the
# commands the library needs. Cases run with PATH set to that entry (plus bin/
# once a case installs a mock gh), so "gh absent" is a real condition and the
# machine's own gh is never reachable.
sandbox() {
  local d t p
  d=$(tmpdir)
  mkdir -p "$d/tools"
  for t in grep tail mktemp cat rm mv touch; do
    p=$(command -v "$t") && ln -s "$p" "$d/tools/$t"
  done
  printf '%s' "$d"
}

# mock_gh DIR installs a gh that appends every call's argv to DIR/gh.log,
# reports itself authenticated, stores what `secret set NAME` reads on stdin
# in DIR/secret.NAME, and the --body of `variable set NAME` in DIR/variable.NAME.
mock_gh() {
  mkdir -p "$1/bin"
  cat > "$1/bin/gh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$1/gh.log"
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "secret set") cat > "$1/secret.\$3" ;;
  "variable set") printf '%s' "\$5" > "$1/variable.\$3" ;;
esac
EOF
  chmod +x "$1/bin/gh"
}

# run_lib DIR STDIN_CONTENT 'bash statements' sources the library and runs the
# statements in DIR with ENV_FILE=DIR/.env and stdin fed from STDIN_CONTENT
# (empty means stdin is closed from the start). Leaves stdout+stderr in OUT
# and the exit code in CODE. The same bash that runs this file runs the
# library, so `/bin/bash tests/test_walkthrough.sh` exercises bash 3.2.
OUT=""
CODE=0
run_lib() {
  local dir="$1" input="$2" script="$3"
  OUT=$(cd "$dir" && printf '%s' "$input" |
    ENV_FILE="$dir/.env" PATH="$dir/bin:$dir/tools" \
    "$BASH" -c "source \"\$WALK_LIB\"; $script" 2>&1)
  CODE=$?
}

# assert_file_is PATH EXPECTED [message] compares the file's exact bytes,
# trailing newline included, which `$(cat ...)` alone would drop.
assert_file_is() {
  local actual
  actual=$(cat "$1"; printf x)
  assert_eq "$2" "${actual%x}" "${3:-content of $1}"
}

test_interrupted_write_leaves_no_temp_file() {
  local d
  # an error between building the temp file and copying it back
  d=$(sandbox)
  printf 'A=1\n' > "$d/.env"
  chmod 444 "$d/.env"
  run_lib "$d" "" 'write_env K "secret-value"'
  chmod 644 "$d/.env"
  assert_exit 1 "$CODE"
  assert_file_is "$d/.env" $'A=1\n' "the file is untouched"
  assert_eq "" "$(find "$d" -maxdepth 1 -name '.env.*' | head -n1)" "no temp file survives the failed write"

  # Ctrl-C landing while the temp file exists
  d=$(sandbox)
  mkdir -p "$d/bin"
  printf '#!/usr/bin/env bash\nkill -INT "$PPID"\nsleep 2\n' > "$d/bin/cat"
  chmod +x "$d/bin/cat"
  run_lib "$d" "" 'write_env K "secret-value"; echo unreachable'
  [[ "$CODE" -ne 0 ]] || fail "an interrupted write must not exit 0"
  assert_not_contains "$OUT" "unreachable"
  assert_eq "" "$(find "$d" -maxdepth 1 -name '.env.*' | head -n1)" "no temp file survives the interrupt"
}

test_eof_writes_nothing() {
  local d
  d=$(sandbox)
  run_lib "$d" "" 'ask K "p"; write_env K "$K"'
  assert_exit 1 "$CODE"
  assert_contains "$OUT" "input closed"
  assert_no_file "$d/.env"

  d=$(sandbox)
  printf 'X=1\n' > "$d/.env"
  run_lib "$d" "" 'ask K "p"; write_env K "$K"'
  assert_exit 1 "$CODE" "pre-seeded"
  assert_file_is "$d/.env" $'X=1\n' "pre-seeded .env untouched"
}

test_eof_after_partial() {
  local d
  d=$(sandbox)
  run_lib "$d" $'first\n' 'ask A "p"; write_env A "$A"; ask B "p"; write_env B "$B"'
  assert_exit 1 "$CODE"
  assert_file_is "$d/.env" $'A=first\n'
  assert_contains "$OUT" "Written so far: A"
}

test_enter_keeps_existing() {
  local d
  d=$(sandbox)
  printf 'K=old\n' > "$d/.env"
  run_lib "$d" $'\n' 'ask K "p"; write_env K "$K"'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'K=old\n'
  assert_contains "$OUT" "kept"
}

test_empty_confirmed() {
  local d
  d=$(sandbox)
  run_lib "$d" $'\ny\n' 'ask K "p"; write_env K "$K"'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'K=\n'
}

test_empty_declined_reprompts() {
  local d
  d=$(sandbox)
  run_lib "$d" $'\nn\nvalue\n' 'ask K "p"; write_env K "$K"'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'K=value\n'
}

test_invalid_key_rejected() {
  local d stmt
  for stmt in "ask 'BAD KEY' \"p\"" "write_env '1ABC' x" "write_env 'A.B' x" "_existing 'A B'"; do
    d=$(sandbox)
    run_lib "$d" $'x\n' "$stmt"
    assert_exit 1 "$CODE" "$stmt"
    assert_contains "$OUT" "invalid environment variable name" "$stmt"
    assert_no_file "$d/.env" "$stmt"
  done
}

test_multiline_rejected_before_mutation() {
  local d value
  for value in 'a\nb' 'a\rb'; do
    d=$(sandbox)
    printf 'X=1\n' > "$d/.env"
    run_lib "$d" "" "write_env K \"\$(printf '$value')\"; printf 'REACHED\n'"
    assert_exit 1 "$CODE" "$value"
    assert_contains "$OUT" "line break" "$value"
    assert_not_contains "$OUT" "REACHED" "$value: script continued past the refusal"
    assert_file_is "$d/.env" $'X=1\n' "$value: .env changed"
  done
}

test_replace_preserves_order_and_others() {
  local d
  d=$(sandbox)
  printf '# c\nA=1\nK=old\nB=2\n' > "$d/.env"
  run_lib "$d" "" 'write_env K new'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'# c\nA=1\nK=new\nB=2\n'
  assert_contains "$OUT" "wrote"
}

test_replace_collapses_duplicates() {
  local d
  d=$(sandbox)
  printf 'K=1\nA=1\nK=2\n' > "$d/.env"
  run_lib "$d" "" 'write_env K 3'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'K=3\nA=1\n'
}

test_append_when_absent_and_no_trailing_newline() {
  local d
  d=$(sandbox)
  printf 'A=1' > "$d/.env"
  run_lib "$d" "" 'write_env K v'
  assert_exit 0 "$CODE"
  assert_file_is "$d/.env" $'A=1\nK=v\n'
}

test_special_characters_round_trip() {
  local d v1 v2
  d=$(sandbox)
  v1="p@ss w0rd=#\$x\"y'z\\"
  v2='second `value` (with) *stars* & % more'
  V="$v1" run_lib "$d" "" 'write_env K "$V" >/dev/null; _existing K'
  assert_exit 0 "$CODE"
  assert_eq "$v1" "$OUT" "_existing after first write"
  assert_file_is "$d/.env" "K=$v1"$'\n' "first write"
  V="$v2" run_lib "$d" "" 'write_env K "$V" >/dev/null; _existing K'
  assert_exit 0 "$CODE"
  assert_eq "$v2" "$OUT" "_existing after replacement"
  assert_file_is "$d/.env" "K=$v2"$'\n' "replacement"
}

test_ask_secret_eof() {
  local d
  d=$(sandbox)
  run_lib "$d" "" 'ask_secret K "p"; write_env K "$K"'
  assert_exit 1 "$CODE"
  assert_contains "$OUT" "input closed"
  assert_no_file "$d/.env"
}

test_pause_and_confirm_eof() {
  local d
  d=$(sandbox)
  run_lib "$d" "" 'pause "x"; printf "REACHED\n"'
  assert_exit 1 "$CODE" "pause"
  assert_contains "$OUT" "input closed" "pause"
  assert_not_contains "$OUT" "REACHED" "pause: script continued"
  run_lib "$d" "" 'if confirm "x"; then printf "ACCEPTED\n"; else printf "DECLINED\n"; fi'
  assert_exit 1 "$CODE" "confirm"
  assert_contains "$OUT" "input closed" "confirm"
  assert_not_contains "$OUT" "DECLINED" "confirm: EOF read as a decline"
  assert_not_contains "$OUT" "ACCEPTED" "confirm: EOF read as a yes"
}

test_set_secret_refuses_empty() {
  local d
  d=$(sandbox)
  mock_gh "$d"
  run_lib "$d" "" 'set_secret S ""; printf "SKIPPED: %s\n" "${SKIPPED[*]:-}"'
  assert_exit 0 "$CODE"
  assert_no_file "$d/secret.S"
  assert_not_contains "$(cat "$d/gh.log" 2>/dev/null)" "secret set" "gh was asked to set the secret"
  assert_contains "$OUT" "SKIPPED: GitHub secret S"
}

test_set_secret_pushes_value() {
  local d
  d=$(sandbox)
  mock_gh "$d"
  run_lib "$d" "" 'set_secret S "v"; printf "SECRETS: %s\n" "${WRITTEN_SECRET[*]:-}"'
  assert_exit 0 "$CODE"
  assert_file_is "$d/secret.S" "v"
  assert_contains "$OUT" "SECRETS: S"
}

test_set_secret_without_gh() {
  local d
  d=$(sandbox)
  run_lib "$d" "" 'set_secret S "v"; printf "SKIPPED: %s\n" "${SKIPPED[*]:-}"'
  assert_exit 0 "$CODE"
  assert_contains "$OUT" "SKIPPED: GitHub secret S"
  assert_no_file "$d/secret.S"
}

test_set_var_refuses_empty_and_pushes_value() {
  local d
  d=$(sandbox)
  mock_gh "$d"
  run_lib "$d" "" 'set_var V ""; set_var W "w"; printf "SKIPPED: %s\n" "${SKIPPED[*]:-}"'
  assert_exit 0 "$CODE"
  assert_no_file "$d/variable.V"
  assert_file_is "$d/variable.W" "w"
  assert_contains "$OUT" "SKIPPED: GitHub variable V"
}

run_tests
