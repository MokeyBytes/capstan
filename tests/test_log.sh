#!/usr/bin/env bash
# Behaviour of skills/effort/bin/capstan-log: rotating the decision log into
# an archive, and reading numbers and status across both.
#
# The backtick-and-pipe fixture text is meant literally, so SC2016 is off
# for this file.
# shellcheck source=tests/lib.sh disable=SC2016
source "$(dirname "$0")/lib.sh"

LOG="$BIN/capstan-log"

# make_ten_row_log HOME: writes <HOME>/decisions.md with ten rows, numbered
# 10 down to 1, newest first, like a real log. Row 9's text supersedes row
# 2's, row 5 carries a pipe and backticks in its own decision text, and
# 10/8/6 are open, assumed and unformed so they stay active regardless of
# number. Rows are padded to a realistic length so the file crosses a small
# byte threshold; each individual test picks the threshold it needs.
make_ten_row_log() {
  local home="$1"
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 10 | 2026-09-01 | Row ten is open and stays active regardless of its number, since nothing has decided it yet and no default is in force here today | open |
| 9 | 2026-09-01 | Row nine settles row two's question the other way. Supersedes 2. Padded further so the fixture reaches a realistic decision-log row length | accepted |
| 8 | 2026-09-01 | Row eight is assumed, defaulted so the work could proceed, and it stays active no matter how far it falls behind the newest kept rows | assumed |
| 7 | 2026-09-01 | Row seven is an ordinary accepted row, old and low numbered enough that rotation should move it to the archive once it runs on this fixture | accepted |
| 6 | 2026-09-01 | Row six is unformed, an area nobody has phrased a question for yet, and it stays active the same way open and assumed rows do here | unformed |
| 5 | 2026-09-01 | Row five carries a pipe `like|this` and backticks in its own text, which the status parser must still read past to find the real status word | accepted |
| 4 | 2026-09-01 | Row four is an ordinary accepted row that should move to the archive the same way row seven and row three do, unedited and byte for byte forever | accepted |
| 3 | 2026-09-01 | Row three is an ordinary accepted row, padded to a realistic length so the fixture file crosses a small byte threshold once all ten rows are present | accepted |
| 2 | 2026-09-01 | Row two is the row that row nine supersedes. Its own status cell never changes: this line stays exactly as it is, in the archive, forever | superseded by 9 |
| 1 | 2026-09-01 | Row one is the oldest ordinary accepted row in the fixture, and the lowest-numbered row that rotation should move to the archive today | accepted |
EOF
}

test_rotate_keeps_open_assumed_unformed_and_newest_n_moves_the_rest() {
  local home before size_before out
  home=$(tmpdir)
  make_ten_row_log "$home"
  before=$(cat "$home/decisions.md")
  size_before=$(wc -c < "$home/decisions.md" | tr -d '[:space:]')
  [[ "$size_before" -gt 1024 ]] || fail "fixture must exceed 1KB for the threshold test to mean anything (got $size_before)"

  out=$("$LOG" rotate "$home" --keep 3 --threshold 1)
  assert_contains "$out" "rotated: moved 6 rows to decisions/archive/decisions-0001-0007.md; kept 4 rows"

  # kept: 10 (open), 9 (top 3 by number), 8 (assumed), 6 (unformed)
  local active
  active=$(cat "$home/decisions.md")
  assert_contains "$active" "capstan_type: decision-log"
  assert_contains "$active" "| # | Date | Decision | Status |"
  for n in 10 9 8 6; do
    assert_contains "$active" "| $n | 2026-09-01"
  done
  for n in 7 5 4 3 2 1; do
    assert_not_contains "$active" "| $n | 2026-09-01"
  done

  local archive="$home/decisions/archive/decisions-0001-0007.md"
  assert_file "$archive"
  local arch
  arch=$(cat "$archive")
  assert_contains "$arch" "capstan_type: decision-archive"
  assert_contains "$arch" "# Decisions archive"
  assert_contains "$arch" "| # | Date | Decision | Status |"
  for n in 7 5 4 3 2 1; do
    assert_contains "$arch" "| $n | 2026-09-01"
  done
  for n in 10 9 8 6; do
    assert_not_contains "$arch" "| $n | 2026-09-01"
  done

  # the pipe-and-backtick row moved byte-identical
  assert_contains "$arch" 'a pipe `like|this` and backticks'

  # before/after multiset: every row line, taken together, is unchanged
  local before_rows after_rows
  before_rows=$(printf '%s\n' "$before" | grep -E '^\| [0-9]+ \|' | sort)
  after_rows=$( { grep -E '^\| [0-9]+ \|' "$home/decisions.md"; grep -E '^\| [0-9]+ \|' "$archive"; } | sort)
  assert_eq "$before_rows" "$after_rows" "row multiset is unchanged by rotation"

  # check passes across both files
  out=$("$LOG" check "$home")
  assert_eq "ok 10 rows, highest 10" "$out"

  # find resolves a row that now lives in the archive, plus its superseder
  out=$("$LOG" find "$home" 2)
  assert_contains "$out" "$archive: | 2 | 2026-09-01"
  assert_contains "$out" "$home/decisions.md: | 9 | 2026-09-01"

  # a second rotate under the (now lower) threshold is a no-op
  local active_before
  active_before=$(cat "$home/decisions.md")
  out=$("$LOG" rotate "$home" --keep 3 --threshold 1)
  assert_eq "under threshold" "$out"
  assert_eq "$active_before" "$(cat "$home/decisions.md")" "no-op leaves the active file untouched"
  assert_eq "$arch" "$(cat "$archive")" "no-op leaves the archive untouched"
}

test_rotate_is_a_no_op_under_the_default_threshold() {
  local home before out
  home=$(tmpdir)
  make_ten_row_log "$home"
  before=$(cat "$home/decisions.md")
  out=$("$LOG" rotate "$home" --keep 3)
  assert_eq "under threshold" "$out"
  assert_eq "$before" "$(cat "$home/decisions.md")"
  assert_no_file "$home/decisions/archive"
}

test_rotate_force_ignores_the_threshold() {
  local home out
  home=$(tmpdir)
  make_ten_row_log "$home"
  out=$("$LOG" rotate "$home" --keep 3 --force)
  assert_contains "$out" "rotated: moved 6 rows"
}

test_rotate_refuses_when_archive_target_already_exists() {
  local home before code out
  home=$(tmpdir)
  make_ten_row_log "$home"
  before=$(cat "$home/decisions.md")
  mkdir -p "$home/decisions/archive"
  printf 'pre-existing, not written by capstan-log\n' > "$home/decisions/archive/decisions-0001-0007.md"
  out=$("$LOG" rotate "$home" --keep 3 --threshold 1 2>&1) && code=0 || code=$?
  assert_exit 2 "$code"
  assert_contains "$out" "decisions-0001-0007.md"
  assert_eq "$before" "$(cat "$home/decisions.md")" "refusal writes nothing to the active log"
  assert_eq "pre-existing, not written by capstan-log" "$(cat "$home/decisions/archive/decisions-0001-0007.md")" "the existing archive file is untouched"
}

test_rotate_refuses_on_duplicate_number() {
  local home before code out
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 2 | 2026-09-01 | first row numbered two | accepted |
| 2 | 2026-09-01 | a second, duplicate row also numbered two | accepted |
| 1 | 2026-09-01 | an ordinary row numbered one | accepted |
EOF
  before=$(cat "$home/decisions.md")
  out=$("$LOG" rotate "$home" --threshold 0 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
  assert_contains "$out" "duplicated"
  assert_eq "$before" "$(cat "$home/decisions.md")"
  assert_no_file "$home/decisions/archive"
}

test_check_refuses_on_duplicate_number_across_active_and_archive() {
  local home code out
  home=$(tmpdir)
  mkdir -p "$home/decisions/archive"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 3 | 2026-09-01 | an open row | open |
EOF
  cat > "$home/decisions/archive/decisions-0003-0003.md" <<'EOF'
---
capstan_type: decision-archive
---

# Decisions archive

| # | Date | Decision | Status |
|---|------|----------|--------|
| 3 | 2026-08-01 | the same number, filed away already | accepted |
EOF
  out=$("$LOG" check "$home" 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
  assert_contains "$out" "row number 3 is duplicated"
}

test_rotate_refuses_on_unparseable_row() {
  local home before code out
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 2 | 2026-09-01 | this row never closes its last column with a pipe so it cannot carry a status
| 1 | 2026-09-01 | an ordinary row numbered one | accepted |
EOF
  before=$(cat "$home/decisions.md")
  out=$("$LOG" rotate "$home" --threshold 0 2>&1) && code=0 || code=$?
  assert_exit 4 "$code"
  assert_contains "$out" "unparseable row"
  assert_eq "$before" "$(cat "$home/decisions.md")"
}

test_rotate_refuses_when_header_is_missing() {
  local home before code out
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 1 | 2026-09-01 | this file never declares capstan_type: decision-log | accepted |
EOF
  before=$(cat "$home/decisions.md")
  out=$("$LOG" rotate "$home" --threshold 0 2>&1) && code=0 || code=$?
  assert_exit 5 "$code"
  assert_contains "$out" "header"
  assert_eq "$before" "$(cat "$home/decisions.md")"
}

test_next_across_active_and_archive() {
  local home out
  home=$(tmpdir)
  mkdir -p "$home/decisions/archive"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 3 | 2026-09-01 | an open row | open |
| 1 | 2026-09-01 | an accepted row | accepted |
EOF
  cat > "$home/decisions/archive/decisions-0002-0009.md" <<'EOF'
---
capstan_type: decision-archive
---

# Decisions archive

| # | Date | Decision | Status |
|---|------|----------|--------|
| 9 | 2026-08-01 | the highest number lives in the archive, not the active log | accepted |
| 2 | 2026-08-01 | an ordinary archived row | accepted |
EOF
  out=$("$LOG" next "$home")
  assert_eq "10" "$out"
}

test_find_across_multiple_archive_files() {
  local home out
  home=$(tmpdir)
  mkdir -p "$home/decisions/archive"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 20 | 2026-09-01 | this row supersedes row four, which is filed in an older archive file. Supersedes 4 | accepted |
EOF
  cat > "$home/decisions/archive/decisions-0010-0015.md" <<'EOF'
---
capstan_type: decision-archive
---

# Decisions archive

| # | Date | Decision | Status |
|---|------|----------|--------|
| 15 | 2026-08-15 | an unrelated archived row | accepted |
EOF
  cat > "$home/decisions/archive/decisions-0001-0009.md" <<'EOF'
---
capstan_type: decision-archive
---

# Decisions archive

| # | Date | Decision | Status |
|---|------|----------|--------|
| 4 | 2026-08-01 | row four, superseded later on | superseded by 20 |
EOF
  out=$("$LOG" find "$home" 4)
  assert_contains "$out" "decisions-0001-0009.md: | 4 | 2026-08-01"
  assert_contains "$out" "decisions.md: | 20 | 2026-09-01"
  assert_not_contains "$out" "decisions-0010-0015.md"
}

test_find_exits_nonzero_when_the_row_does_not_exist() {
  local home code
  home=$(tmpdir)
  make_ten_row_log "$home"
  "$LOG" find "$home" 999 >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 1 "$code"
}

test_help_lists_commands_and_exit_codes() {
  local out
  out=$("$LOG" --help 2>&1) || true
  assert_contains "$out" "rotate"
  assert_contains "$out" "check"
  assert_contains "$out" "next"
  assert_contains "$out" "find"
  assert_contains "$out" "Exit codes"
}

run_tests
