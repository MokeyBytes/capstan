#!/usr/bin/env bash
# Tests for skills/effort/bin/capstan-tracker against tests/mock/gh. No
# network: the mock is first on PATH for every case, and every case runs in
# its own tmpdir. Fixtures come from tests/fixtures/make-board.sh.
#
# The awk conditions handed to count() are meant literally, so SC2016 is off
# for this file. lib.sh is not followed because run.sh lints without -x.
# shellcheck disable=SC2016,SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PATH="$REPO_ROOT/tests/mock:$PATH"
export PATH
FIX="$REPO_ROOT/tests/fixtures"
TRACKER="$BIN/capstan-tracker"
TAB=$'\t'
ROW_HEADER="effort${TAB}slice${TAB}status${TAB}commit${TAB}issue${TAB}url${TAB}note"

# run DIR [VAR=VALUE...] -- ARGS...: run the helper with the mock configured
# by the VAR=VALUE pairs, logging every gh call to DIR/log. Leaves stdout in
# OUT (and DIR/out), stderr in ERR (and DIR/err), and the exit code in CODE.
run() {
  local dir="$1"
  shift
  local envs=()
  while [[ $# -gt 0 && "$1" != -- ]]; do
    envs+=("$1")
    shift
  done
  shift
  CODE=0
  env GH_MOCK_LOG="$dir/log" ${envs[@]+"${envs[@]}"} "$TRACKER" "$@" \
    > "$dir/out" 2> "$dir/err" || CODE=$?
  OUT="$(cat "$dir/out")"
  ERR="$(cat "$dir/err")"
}

lines() { # FILE: line count, without wc's padding
  awk 'END { print NR }' "$1"
}

count() { # AWK-CONDITION FILE: rows (header excluded) matching the condition
  awk -F '\t' "NR > 1 && ($1)" "$2" | awk 'END { print NR }'
}

calls() { # LOG PREFIX: gh calls in LOG starting with PREFIX; no log, no calls
  if [[ -e "$1" ]]; then grep -c "^$2" "$1" || true; else printf '0\n'; fi
}

nth_call() { # LOG PREFIX N: the Nth gh call starting with PREFIX
  grep "^$2" "$1" | sed -n "${3}p"
}

test_default_limit_truncates_without_helper() {
  # The defect the helper exists for: a bare item-list read stops at 30 items
  # and says nothing, while the same response reports the board's true size.
  local d n t
  d="$(tmpdir)"
  n="$(env GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_LOG="$d/log" \
    gh project item-list 1 --owner acme --format json --jq '.items | length')"
  t="$(env GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_LOG="$d/log" \
    gh project item-list 1 --owner acme --format json --jq '.totalCount')"
  assert_eq 30 "$n" "items returned at gh's default limit"
  assert_eq 75 "$t" "totalCount the same response reports"
}

test_read_is_complete_over_30() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" -- read --owner acme --repo widgets --project 1
  assert_exit 0 "$CODE"
  assert_eq 71 "$(lines "$d/out")" "header plus 70 rows"
  assert_eq "$ROW_HEADER" "$(head -n 1 "$d/out")" "header line"
  assert_eq 1 "$(calls "$d/log" 'project item-list')" "one item-list call when --limit 100 covers the board"
  assert_contains "$(nth_call "$d/log" 'project item-list' 1)" "--limit 100" "first call carries an explicit limit"
  assert_not_contains "$(nth_call "$d/log" 'project item-list' 1)" "--limit 30"
  assert_contains "$ERR" "board: 75 items, read 75; capstan rows in acme/widgets: 70"
}

test_short_first_read_reruns_with_total() {
  # One call comes back short of totalCount; the helper re-reads with the
  # board's own total as the limit and only then prints rows.
  local d
  d="$(tmpdir)"
  touch "$d/short"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_SHORT_ONCE="$d/short" -- \
    read --owner acme --repo widgets --project 1
  assert_exit 0 "$CODE"
  assert_eq 71 "$(lines "$d/out")" "header plus 70 rows after the re-read"
  assert_eq 2 "$(calls "$d/log" 'project item-list')" "a second item-list call"
  assert_contains "$(nth_call "$d/log" 'project item-list' 2)" "--limit 75" "second call uses totalCount as the limit"
  assert_no_file "$d/short" "the mock consumed its one short read"
}

test_read_scopes_to_repository() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" -- read --owner acme --repo widgets --project 1
  assert_exit 0 "$CODE"
  assert_not_contains "$OUT" "other/repo" "issue on another repository"
  assert_not_contains "$OUT" "elsewhere" "issue on another repository, by title"
  assert_not_contains "$OUT" "pull-request-71" "pull request"
  assert_not_contains "$OUT" "scratch note" "draft issue"
  assert_not_contains "$OUT" "redacted" "item with null content"
  assert_not_contains "$OUT" "unstatused" "issue with no Capstan Status"
  assert_contains "$ERR" "skipped: 1 other repository, 3 not an issue, 1 no Capstan Status"
  assert_eq 0 "$(count '$6 !~ /^https:\/\/github\.com\/acme\/widgets\/issues\/[0-9]+$/' "$d/out")" "every kept url is an acme/widgets issue"
}

test_duplicate_slice_names_kept_apart() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" -- read --owner acme --repo widgets --project 1
  assert_exit 0 "$CODE"
  assert_eq 2 "$(count '$2 == "docs"' "$d/out")" "two docs rows"
  assert_contains "$OUT" "effort-a${TAB}docs${TAB}merged${TAB}"
  assert_contains "$OUT" "effort-b${TAB}docs${TAB}building${TAB}"
}

test_empty_board_is_genuine_empty() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-empty.json" -- read --owner acme --repo widgets --project 1
  assert_exit 0 "$CODE"
  assert_eq "$ROW_HEADER" "$OUT" "header only"
  assert_contains "$ERR" "board: 0 items, read 0; capstan rows in acme/widgets: 0"
  assert_contains "$ERR" "genuine empty result"
}

test_unreachable_prints_no_rows() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_FAIL_LIST=1 -- read --owner acme --repo widgets --project 1
  assert_exit 1 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" "unreachable"
  assert_contains "$ERR" "unknown owner type"
}

test_incomplete_read_exits_2() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_TOTAL_OVERRIDE=999 -- read --owner acme --repo widgets --project 1
  assert_exit 2 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" "incomplete: board reports 999 items, read 75"
  assert_eq 3 "$(calls "$d/log" 'project item-list')" "three attempts, no more"
  assert_contains "$(nth_call "$d/log" 'project item-list' 2)" "--limit 999"
  assert_contains "$(nth_call "$d/log" 'project item-list' 3)" "--limit 999"
}

test_with_commits_reads_every_merged_row() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments" -- \
    read --owner acme --repo widgets --project 1 --with-commits
  assert_exit 0 "$CODE"
  assert_eq 71 "$(lines "$d/out")" "header plus 70 rows"
  assert_eq 18 "$(count '$3 == "merged"' "$d/out")" "merged rows on the board"
  assert_eq 0 "$(count '$3 == "merged" && $4 !~ /^[0-9a-f]+$/' "$d/out")" "every merged row carries a commit"
  assert_eq 0 "$(count '$3 != "merged" && ($4 != "" || $7 != "")' "$d/out")" "no commit or note on other rows"
  assert_eq 18 "$(calls "$d/log" 'api repos/acme/widgets/issues/[0-9]*/comments --paginate')" "one paginated comments read per merged row"
  assert_contains "$OUT" "effort-a${TAB}slice-03${TAB}merged${TAB}0388395${TAB}3${TAB}https://github.com/acme/widgets/issues/3${TAB}other-comments=1"
  assert_contains "$OUT" "effort-a${TAB}slice-07${TAB}merged${TAB}083ddb1${TAB}7${TAB}https://github.com/acme/widgets/issues/7${TAB}other-comments=1"
  assert_not_contains "$OUT" "deadbeef" "the sha inside ordinary discussion is not a commit"
  assert_not_contains "$OUT" "cafe0000" "a conforming line inside a longer body is not a commit"
  assert_eq 2 "$(count '$7 != ""' "$d/out")" "only the two rows with extra comments carry a note"
}

test_partial_api_failure_produces_no_table() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments" GH_MOCK_FAIL_ISSUE=11 -- \
    read --owner acme --repo widgets --project 1 --with-commits
  assert_exit 1 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" "unreachable"
  assert_contains "$ERR" "issue #11"
  assert_contains "$ERR" "HTTP 500"
}

test_two_conforming_comments_invalid() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments-bad" -- \
    read --owner acme --repo widgets --project 1 --with-commits
  assert_exit 3 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" "invalid: issue #3: 2 conforming merge comments"
  assert_contains "$ERR" "invalid: issue #11: 0 conforming merge comments"
}

test_invalid_row_exits_3() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-invalid.json" -- read --owner acme --repo widgets --project 1
  assert_exit 3 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" "invalid: issue #80"
  assert_contains "$ERR" "no milestone"
  assert_contains "$ERR" "invalid: issue #81"
  assert_contains "$ERR" 'status "done"'
}

test_parse_tracker_md() {
  local d sorted
  d="$(tmpdir)"
  run "$d" -- parse --tracker-md "$FIX/tracker-75.md"
  assert_exit 0 "$CODE"
  assert_eq 71 "$(lines "$d/out")" "header plus 70 rows"
  assert_eq "$ROW_HEADER" "$(head -n 1 "$d/out")" "header line"
  sorted=0
  tail -n +2 "$d/out" | LC_ALL=C sort -c -t "$TAB" -k1,1 -k2,2 || sorted=$?
  assert_eq 0 "$sorted" "rows sorted by effort then slice"
  assert_eq 18 "$(count '$3 == "merged" && $4 ~ /^[0-9a-f]+$/' "$d/out")" "merged rows keep their commit"
  assert_eq 0 "$(count '$5 != "" || $6 != "" || $7 != ""' "$d/out")" "issue, url and note empty"
  assert_contains "$OUT" "effort-a${TAB}slice-03${TAB}merged${TAB}0388395${TAB}${TAB}${TAB}"
  assert_contains "$OUT" "effort-c${TAB}web ui${TAB}dropped${TAB}${TAB}${TAB}${TAB}"
  assert_eq 0 "$(calls "$d/log" '')" "parse never calls gh"
}

test_parse_rejects_bad_status() {
  local d
  d="$(tmpdir)"
  printf -- '---\ncapstan_type: tracker\n---\n\n# Tracker\n\n| Effort | Slice | Status | Commit |\n|---|---|---|---|\n| e | one | planned | |\n| e | two | done | |\n' > "$d/tracker.md"
  run "$d" -- parse --tracker-md "$d/tracker.md"
  assert_exit 3 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  assert_contains "$ERR" 'status "done"'
}

test_diff_clean() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments" -- \
    diff --owner acme --repo widgets --project 1 --tracker-md "$FIX/tracker-75.md"
  assert_exit 0 "$CODE"
  assert_eq 71 "$(lines "$d/out")" "header plus 70 verdicts"
  assert_eq 70 "$(count '$3 == "same"' "$d/out")" "every key is same"
  assert_contains "$ERR" "70 same, 0 status-changed, 0 commit-changed, 0 board-only, 0 file-only"
}

test_diff_detects_every_drift() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments" -- \
    diff --owner acme --repo widgets --project 1 --tracker-md "$FIX/tracker-drift.md"
  assert_exit 4 "$CODE"
  assert_eq 1 "$(count '$3 ~ /^status-changed /' "$d/out")" "one status-changed"
  assert_eq 1 "$(count '$3 ~ /^commit-changed /' "$d/out")" "one commit-changed"
  assert_eq 1 "$(count '$3 == "board-only"' "$d/out")" "one board-only"
  assert_eq 1 "$(count '$3 == "file-only"' "$d/out")" "one file-only"
  assert_eq 67 "$(count '$3 == "same"' "$d/out")" "the rest same"
  assert_contains "$OUT" "effort-b${TAB}docs${TAB}status-changed merged -> building"
  assert_contains "$OUT" "effort-a${TAB}docs${TAB}same"
  assert_contains "$OUT" "effort-a${TAB}slice-03${TAB}commit-changed 0000abc -> 0388395"
  assert_contains "$OUT" "effort-c${TAB}slice-37${TAB}board-only"
  assert_contains "$OUT" "effort-d${TAB}slice-99${TAB}file-only"
  assert_contains "$ERR" "67 same, 1 status-changed, 1 commit-changed, 1 board-only, 1 file-only"
}

test_resume_after_interruption() {
  # A reverse migration torn down partway: ten rows already off the board,
  # the full tracker.md written. Every remaining row matches, nothing is
  # board-only, and the ten torn down read as file-only.
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-65.json" GH_MOCK_COMMENTS_DIR="$FIX/comments" -- \
    diff --owner acme --repo widgets --project 1 --tracker-md "$FIX/tracker-75.md"
  assert_exit 4 "$CODE"
  assert_eq 10 "$(count '$3 == "file-only"' "$d/out")" "ten file-only"
  assert_eq 60 "$(count '$3 == "same"' "$d/out")" "sixty same"
  assert_eq 0 "$(count '$3 == "board-only"' "$d/out")" "no board-only"
  assert_eq 0 "$(count '$3 ~ /-changed /' "$d/out")" "no status or commit changes"
  assert_contains "$ERR" "capstan rows in acme/widgets: 60"
  assert_contains "$ERR" "60 same, 0 status-changed, 0 commit-changed, 0 board-only, 10 file-only"
}

test_diff_propagates_read_failure() {
  local d
  d="$(tmpdir)"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_FAIL_LIST=1 -- \
    diff --owner acme --repo widgets --project 1 --tracker-md "$FIX/tracker-75.md"
  assert_exit 1 "$CODE"
  assert_eq "" "$OUT" "stdout empty"
  run "$d" GH_MOCK_ITEMS="$FIX/board-75.json" GH_MOCK_COMMENTS_DIR="$FIX/comments-bad" -- \
    diff --owner acme --repo widgets --project 1 --tracker-md "$FIX/tracker-75.md"
  assert_exit 3 "$CODE"
  assert_eq "" "$OUT" "stdout empty on an invalid board"
}

test_usage_errors_exit_64() {
  local d
  d="$(tmpdir)"
  run "$d" --
  assert_exit 64 "$CODE" "no command"
  run "$d" -- read --owner acme --project 1
  assert_exit 64 "$CODE" "missing --repo"
  run "$d" -- read --owner acme --repo widgets --project one
  assert_exit 64 "$CODE" "non-numeric project"
  run "$d" -- parse --tracker-md "$d/missing.md"
  assert_exit 64 "$CODE" "unreadable tracker.md"
  run "$d" -- --help
  assert_exit 0 "$CODE" "--help"
  assert_contains "$OUT" "usage:"
  assert_eq 0 "$(calls "$d/log" '')" "usage errors never call gh"
}

test_mock_refuses_unknown_calls() {
  local d code
  d="$(tmpdir)"
  code=0
  env GH_MOCK_LOG="$d/log" gh issue view 1 > "$d/out" 2> "$d/err" || code=$?
  assert_exit 99 "$code"
  assert_contains "$(cat "$d/err")" "mock gh: unsupported"
}

run_tests
