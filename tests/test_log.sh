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

# install_decisions_md_mv_shim DIR: writes a `mv` shim into DIR that exits 1
# when its last argument ends in /decisions.md, and otherwise execs the real
# mv untouched. Deterministic and the same under any user, root included, on
# macOS or Linux, unlike an immutable-file flag (chflags/chattr), which
# needs a capability root does not always have and, if a run is interrupted
# mid-flag, leaves a file the test runner cannot remove.
install_decisions_md_mv_shim() {
  local dir="$1" real_mv
  real_mv=$(command -v mv)
  cat > "$dir/mv" <<SHIM
#!/bin/sh
for last; do :; done
case "\$last" in
  */decisions.md) exit 1 ;;
esac
exec "$real_mv" "\$@"
SHIM
  chmod +x "$dir/mv"
}

# install_active_rename_term_shim DIR: writes a `mv` shim into DIR that,
# only for a call whose last argument ends in /decisions.md, sends SIGTERM
# to its parent and waits (up to 5s) for the parent to actually exit before
# returning, rather than performing that rename; every other call execs the
# real mv untouched. If the parent never exits, it leaves DIR/.interrupt-
# missed. That case is not mere flakiness: a shell that has trapped the
# signal itself (rather than leaving it at its default disposition) defers
# running the trap until the current foreground command finishes, so a
# parent that catches TERM without exiting sits waiting on this very shim
# until the wait times out. The caller treats that as the trap regression it
# is, not as a reason to pass quietly.
install_active_rename_term_shim() {
  local dir="$1" real_mv
  real_mv=$(command -v mv)
  cat > "$dir/mv" <<SHIM
#!/bin/sh
for last; do :; done
case "\$last" in
  */decisions.md)
    kill -TERM "\$PPID" 2>/dev/null
    waited=0
    while kill -0 "\$PPID" 2>/dev/null && [ "\$waited" -lt 500 ]; do
      sleep 0.01
      waited=\$((waited + 1))
    done
    if kill -0 "\$PPID" 2>/dev/null; then
      touch "$dir/.interrupt-missed"
    fi
    exit 143
    ;;
esac
exec "$real_mv" "\$@"
SHIM
  chmod +x "$dir/mv"
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

test_help_names_the_tools_actually_used() {
  local out
  out=$("$LOG" --help 2>&1) || true
  assert_not_contains "$out" "bash, awk, sort and grep only"
  assert_contains "$out" "POSIX tools"
  assert_contains "$out" "No jq"
}

# --- S1: an interruption between the two renames ----------------------------

test_rotate_interrupted_between_renames_is_detected_by_check_and_rotate() {
  local home code out
  home=$(tmpdir)
  make_ten_row_log "$home"
  # Exactly the state a kill between the two renames now leaves: the archive
  # already renamed into place, the active log not yet rewritten. Both
  # commands must refuse on the resulting duplicate rather than lose the
  # rows or report a stale "ok".
  mkdir -p "$home/decisions/archive"
  cat > "$home/decisions/archive/decisions-0001-0007.md" <<'EOF'
---
capstan_type: decision-archive
---

# Decisions archive

| # | Date | Decision | Status |
|---|------|----------|--------|
| 7 | 2026-09-01 | Row seven is an ordinary accepted row, old and low numbered enough that rotation should move it to the archive once it runs on this fixture | accepted |
| 5 | 2026-09-01 | Row five carries a pipe `like|this` and backticks in its own text, which the status parser must still read past to find the real status word | accepted |
| 4 | 2026-09-01 | Row four is an ordinary accepted row that should move to the archive the same way row seven and row three do, unedited and byte for byte forever | accepted |
| 3 | 2026-09-01 | Row three is an ordinary accepted row, padded to a realistic length so the fixture file crosses a small byte threshold once all ten rows are present | accepted |
| 2 | 2026-09-01 | Row two is the row that row nine supersedes. Its own status cell never changes: this line stays exactly as it is, in the archive, forever | superseded by 9 |
| 1 | 2026-09-01 | Row one is the oldest ordinary accepted row in the fixture, and the lowest-numbered row that rotation should move to the archive today | accepted |
EOF

  out=$("$LOG" check "$home" 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
  assert_contains "$out" "duplicated"

  out=$("$LOG" rotate "$home" --keep 3 --threshold 1 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
  assert_contains "$out" "duplicated"
}

test_rotate_forced_failure_after_archive_rename_leaves_active_untouched_and_is_detected() {
  local home before code out shim_dir saved_path
  home=$(tmpdir)
  make_ten_row_log "$home"
  before=$(cat "$home/decisions.md")
  mkdir -p "$home/decisions/archive"

  # Force exactly the active log's own rename to fail, deterministically and
  # the same way under any user (root included) on macOS or Linux: a PATH
  # shim for `mv` that fails only the call whose last argument ends in
  # /decisions.md and hands every other call to the real mv. The archive
  # rename lands on a different filename entirely and is unaffected, so this
  # isolates the two renames' order rather than merely asserting the state
  # an interruption between them would leave.
  shim_dir=$(tmpdir)
  install_decisions_md_mv_shim "$shim_dir"
  saved_path="$PATH"
  PATH="$shim_dir:$PATH"
  out=$("$LOG" rotate "$home" --keep 3 --threshold 1 2>&1) && code=0 || code=$?
  PATH="$saved_path"

  assert_exit 7 "$code" "a failed rename should abort with its own code ($out)"
  local archive="$home/decisions/archive/decisions-0001-0007.md"
  assert_file "$archive" "the archive rename must land before the active rename is attempted"
  assert_eq "$before" "$(cat "$home/decisions.md")" "the active log must be untouched when its own rename fails"

  # The archive now holds rows also still present in the untouched active
  # log: exactly the duplicate state check and rotate must refuse on.
  out=$("$LOG" check "$home" 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
  out=$("$LOG" rotate "$home" --keep 3 --threshold 1 2>&1) && code=0 || code=$?
  assert_exit 3 "$code"
}

# test_sigterm_before_the_active_rename_leaves_the_log_and_check_untouched
# replaces a poll-and-kill version of this test: waiting for a temp file to
# appear before sending TERM never failed when the code was correct, but on
# a slower runner it could pass without ever having interrupted anything,
# and it added several seconds to every run. A PATH shim removes the timing
# race entirely: it fires exactly at the mv call this test cares about, and
# it can tell the caller when the interrupt did not land rather than pass
# silently.
#
# The fixture uses --keep's default (50) against 50 rows, an interleaved
# status column (every tenth row open, so kept and would-be-moved rows are
# threaded through the file rather than clustered at the top) but sized so
# every row number is in fact kept: with nothing moved, the rotate makes
# exactly one rename call, the one this test intercepts, so decisions.md and
# the archive both stay exactly as they were and `check` sees no duplicate.
# A rotate where the archive rename has already landed when the active
# rename is interrupted is the different, already-covered scenario in
# test_rotate_forced_failure_after_archive_rename_leaves_active_untouched_and_is_detected.
test_sigterm_before_the_active_rename_leaves_the_log_and_check_untouched() {
  local home before check_before shim_dir saved_path out code i
  home=$(tmpdir)
  mkdir -p "$home"
  {
    printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n'
    for ((i = 50; i >= 1; i--)); do
      if (( i % 10 == 0 )); then
        printf '| %d | 2026-09-01 | an open row, one in every ten, threaded through the file so a corrupted rotate would leave check disagreeing with the count taken before | open |\n' "$i"
      else
        printf '| %d | 2026-09-01 | an ordinary accepted row that stays active only because every row here falls within the default kept top N | accepted |\n' "$i"
      fi
    done
  } > "$home/decisions.md"
  before=$(cat "$home/decisions.md")
  check_before=$("$LOG" check "$home")

  shim_dir=$(tmpdir)
  install_active_rename_term_shim "$shim_dir"
  saved_path="$PATH"
  PATH="$shim_dir:$PATH"
  out=$("$LOG" rotate "$home" --threshold 1 2>&1) && code=0 || code=$?
  PATH="$saved_path"

  if [[ -e "$shim_dir/.interrupt-missed" ]]; then
    fail "the SIGTERM never landed before the active-log rename: the process kept running instead of stopping at the signal (exit $code, output: $out)"
    return 1
  fi

  assert_exit 143 "$code" "a SIGTERM landing before the active-log rename should end the run through the EXIT trap ($out)"
  assert_eq "$before" "$(cat "$home/decisions.md")" "decisions.md must be byte-identical to before the interrupt"
  out=$("$LOG" check "$home")
  assert_eq "$check_before" "$out" "check must report the original row count after the interrupt"

  shopt -s nullglob
  local leftovers=("$home"/.decisions*.tmp.* "$home"/.topn.tmp.* "$home"/decisions/archive/.decisions*.tmp.*)
  shopt -u nullglob
  assert_eq "0" "${#leftovers[@]}" "no temp path should survive an interrupted rotate: ${leftovers[*]:-}"
}

# --- S3: fixtures the round-1 mutants slipped past ---------------------------

test_rotate_keeps_open_row_with_pipe_below_the_top_n() {
  local home out active
  home=$(tmpdir)
  mkdir -p "$home"
  {
    printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n'
    printf '| %d | 2026-09-01 | ordinary accepted row padded so the fixture crosses a small byte threshold once every row here is present today | accepted |\n' 20 19 18 17 16
    printf '| 1 | 2026-09-01 | an open row far below the kept top N, carrying a pipe `a|b` in its own text, that must stay active on status alone | open |\n'
  } > "$home/decisions.md"
  out=$("$LOG" rotate "$home" --keep 2 --threshold 0)
  assert_contains "$out" "kept 3 rows"
  active=$(cat "$home/decisions.md")
  assert_contains "$active" "| 1 | 2026-09-01"
  assert_contains "$active" "| 20 | 2026-09-01"
  assert_contains "$active" "| 19 | 2026-09-01"
  assert_not_contains "$active" "| 18 | 2026-09-01"
  assert_not_contains "$active" "| 17 | 2026-09-01"
  assert_not_contains "$active" "| 16 | 2026-09-01"
}

test_rotate_out_of_order_rows_keeps_exactly_the_correct_set() {
  local home out active
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 3 | 2026-09-01 | an ordinary accepted row placed early in file order though its number ranks it well outside the two highest numbers kept today | accepted |
| 12 | 2026-09-01 | an open row placed second in file order that stays active on status alone regardless of file order or numeric ranking today | open |
| 1 | 2026-09-01 | an ordinary accepted row placed third in file order and also outside the two highest numbers kept on this fixture today | accepted |
| 11 | 2026-09-01 | an ordinary accepted row placed fourth in file order that must stay active only because its number ranks in the top two kept | accepted |
| 2 | 2026-09-01 | an ordinary accepted row placed fifth in file order and outside the two highest numbers kept on this fixture today as well | accepted |
| 9 | 2026-09-01 | an assumed row placed sixth in file order that stays active on status alone regardless of file order or numeric ranking today | assumed |
| 4 | 2026-09-01 | an ordinary accepted row placed last in file order and outside the two highest numbers kept on this fixture as well today | accepted |
EOF
  out=$("$LOG" rotate "$home" --keep 2 --threshold 0)
  assert_contains "$out" "moved 4 rows to decisions/archive/decisions-0001-0004.md; kept 3 rows"
  active=$(cat "$home/decisions.md")
  for n in 12 11 9; do
    assert_contains "$active" "| $n | 2026-09-01"
  done
  for n in 3 1 2 4; do
    assert_not_contains "$active" "| $n | 2026-09-01"
  done
}

# classify_active_rows used to compare only the status cell's first
# whitespace-separated word, so a multi-word status such as "assumed until
# the bench lands" read as the bare "assumed" and stayed active regardless
# of its number.
test_rotate_moves_a_multiword_status_that_only_starts_with_a_kept_word() {
  local home out active archive
  home=$(tmpdir)
  mkdir -p "$home"
  {
    printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n'
    printf '| 2 | 2026-09-01 | an open row, kept so the fixture always has something recent | open |\n'
    printf '| 1 | 2026-09-01 | a status that starts with the word assumed but is not the exact status assumed | assumed until the bench lands |\n'
  } > "$home/decisions.md"
  out=$("$LOG" rotate "$home" --keep 0 --threshold 0)
  assert_contains "$out" "moved 1 rows"
  active=$(cat "$home/decisions.md")
  assert_not_contains "$active" "| 1 | 2026-09-01"
  archive="$home/decisions/archive/decisions-0001-0001.md"
  assert_file "$archive"
  assert_contains "$(cat "$archive")" "assumed until the bench lands"
}

test_rotate_preserves_a_backslash_in_row_text_byte_for_byte() {
  # A row's bytes are copied by a plain `read -r` loop rather than
  # re-derived; if a future change dropped the `-r` and let `read` collapse
  # a backslash escape, this row's text would come out changed and the
  # multiset verify that guards every rotate would refuse rather than write
  # silently corrupted output.
  local home out archive
  home=$(tmpdir)
  mkdir -p "$home"
  {
    printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n'
    printf '| 2 | 2026-09-01 | an open row so the file has something recent to keep | open |\n'
    printf '| 1 | 2026-09-01 | a row whose text carries a literal backslash \\ that a plain read would treat as an escape | accepted |\n'
  } > "$home/decisions.md"
  out=$("$LOG" rotate "$home" --keep 0 --threshold 0)
  assert_contains "$out" "moved 1 rows"
  archive="$home/decisions/archive/decisions-0001-0001.md"
  assert_file "$archive"
  assert_contains "$(cat "$archive")" 'a literal backslash \ that a plain read'
}

test_find_matches_supersedes_case_insensitively_but_not_as_a_substring() {
  local home out
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 20 | 2026-09-01 | an unrelated accepted row | accepted |
| 19 | 2026-09-01 | Supersedes 150, a number that must never match find 15 | accepted |
| 18 | 2026-09-01 | supersedes 15 written in lowercase | accepted |
| 17 | 2026-09-01 | Supersedes 12. Also supersedes 15 on its second half | accepted |
| 15 | 2026-09-01 | the row being superseded | superseded by 18 |
EOF
  local out
  out=$("$LOG" find "$home" 15)
  assert_contains "$out" "| 15 | 2026-09-01"
  assert_contains "$out" "| 18 | 2026-09-01"
  assert_contains "$out" "| 17 | 2026-09-01"
  assert_not_contains "$out" "| 19 | 2026-09-01"
  assert_not_contains "$out" "| 20 | 2026-09-01"
}

test_find_parses_the_list_form_of_supersedes() {
  local home out48 out57
  home=$(tmpdir)
  mkdir -p "$home"
  cat > "$home/decisions.md" <<'EOF'
---
capstan_type: decision-log
---

# Decisions

| # | Date | Decision | Status |
|---|------|----------|--------|
| 58 | 2026-09-01 | Supersedes 36, 43, 46, 49, 51, 54 and 57 | accepted |
| 188 | 2026-09-01 | Supersedes 40, 48, 50, 58 | accepted |
| 48 | 2026-09-01 | one of the rows the list above supersedes | superseded by 188 |
| 57 | 2026-09-01 | another of the rows the list above supersedes | superseded by 58 |
EOF
  out48=$("$LOG" find "$home" 48)
  assert_contains "$out48" "| 48 | 2026-09-01"
  assert_contains "$out48" "| 188 | 2026-09-01"

  out57=$("$LOG" find "$home" 57)
  assert_contains "$out57" "| 57 | 2026-09-01"
  assert_contains "$out57" "| 58 | 2026-09-01"
}

# find used to open a process substitution per row while scanning for
# `upersedes` phrases. bash 3.2 never closes one, and aborted with SIGABRT
# once about 256 were open at once, well under a real log's row count. This
# fixture crosses 300 rows so `/bin/bash tests/run.sh` catches a relapse.
test_find_works_on_a_log_with_hundreds_of_rows() {
  local home out i
  home=$(tmpdir)
  mkdir -p "$home"
  {
    printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n'
    printf '| 188 | 2026-09-01 | Supersedes 40, 48, 50, 58 | accepted |\n'
    for ((i = 350; i >= 1; i--)); do
      [[ "$i" -eq 188 ]] && continue
      printf '| %d | 2026-09-01 | an ordinary padded row so this fixture crosses the descriptor count that once made bash 3.2 abort mid-scan | accepted |\n' "$i"
    done
  } > "$home/decisions.md"
  out=$("$LOG" find "$home" 48)
  assert_contains "$out" "| 48 | 2026-09-01"
  assert_contains "$out" "| 188 | 2026-09-01"
}

# --- S4: check, next and find require decisions.md --------------------------

test_check_next_find_require_the_active_log() {
  local home code
  home=$(tmpdir)
  mkdir -p "$home"
  "$LOG" check "$home" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 1 "$code"
  "$LOG" next "$home" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 1 "$code"
  "$LOG" find "$home" 1 >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 1 "$code"
}

# --- S5: trim strips tabs, not only spaces ----------------------------------

test_status_with_a_trailing_tab_is_still_recognised_as_open() {
  local home out
  home=$(tmpdir)
  mkdir -p "$home"
  printf -- '---\ncapstan_type: decision-log\n---\n\n# Decisions\n\n| # | Date | Decision | Status |\n|---|------|----------|--------|\n' > "$home/decisions.md"
  printf '| 1 | 2026-09-01 | a row whose status cell carries a trailing tab after the word | open\t|\n' >> "$home/decisions.md"
  out=$("$LOG" rotate "$home" --keep 0 --threshold 0)
  assert_contains "$out" "kept 1 rows"
  assert_contains "$(cat "$home/decisions.md")" "| 1 | 2026-09-01"
}

# --- T1: --keep 0, and a missing flag value ---------------------------------

test_rotate_keep_zero_moves_every_row_but_open_assumed_unformed() {
  local home out
  home=$(tmpdir)
  make_ten_row_log "$home"
  out=$("$LOG" rotate "$home" --keep 0 --threshold 1)
  # Open, assumed and unformed still stay; nothing else does with keep 0.
  assert_contains "$out" "kept 3 rows"
  local active
  active=$(cat "$home/decisions.md")
  for n in 10 8 6; do
    assert_contains "$active" "| $n | 2026-09-01"
  done
  for n in 9 7 5 4 3 2 1; do
    assert_not_contains "$active" "| $n | 2026-09-01"
  done
}

test_rotate_missing_flag_value_is_a_usage_error() {
  local home code out
  home=$(tmpdir)
  make_ten_row_log "$home"

  out=$("$LOG" rotate "$home" --keep 2>&1) && code=0 || code=$?
  assert_exit 64 "$code"
  assert_contains "$out" "--keep needs a value"

  out=$("$LOG" rotate "$home" --threshold 2>&1) && code=0 || code=$?
  assert_exit 64 "$code"
  assert_contains "$out" "--threshold needs a value"
}

run_tests
