#!/usr/bin/env bash
# Behaviour of skills/effort/bin/capstan-scratch-clean: exact paths only,
# verified ownership, symlinks handled as links, unknown siblings survive.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

CLEAN="$BIN/capstan-scratch-clean"
CLAIM="$BIN/capstan-claim"

setup() { # prints a repository whose effort "checkout" is claimed by alice
  local d
  d=$(tmpdir)/"work tree"
  mkdir -p "$d"
  git_repo "$d" >/dev/null
  "$CLAIM" acquire "$d" --owner alice --effort checkout >/dev/null
  mkdir -p "$d/.capstan/effort/scout" "$d/.capstan/effort/review"
  printf 'spec\n' > "$d/.capstan/effort/spec.md"
  printf 'x\n' > "$d/.capstan/effort/scout/q.md"
  printf 'glossary\n' > "$d/.capstan/CONTEXT.md"
  printf 'log\n' > "$d/.capstan/decisions.md"
  mkdir -p "$d/.capstan/decisions"
  printf 'record\n' > "$d/.capstan/decisions/0001-x.md"
  printf 'rows\n' > "$d/.capstan/tracker.md"
  printf '%s' "$d"
}

durable_intact() {
  assert_file "$1/.capstan/CONTEXT.md"
  assert_file "$1/.capstan/decisions.md"
  assert_file "$1/.capstan/decisions/0001-x.md"
  assert_file "$1/.capstan/tracker.md"
}

test_the_old_wildcard_took_unrelated_names() {
  # The defect: `rm -rf .capstan/effort*` removes effort-archive and effort-notes.md.
  local wc
  wc=$(setup)
  mkdir -p "$wc/.capstan/effort-archive"
  printf 'notes\n' > "$wc/.capstan/effort-notes.md"
  ( cd "$wc" && rm -rf .capstan/effort* )
  assert_no_file "$wc/.capstan/effort-archive" "wildcard deletes the archive"
  assert_no_file "$wc/.capstan/effort-notes.md" "wildcard deletes the notes"
}

test_deletes_scratch_and_sync_copies_only() {
  local wc out
  wc=$(setup)
  mkdir -p "$wc/.capstan/effort 2/scout" "$wc/.capstan/effort 3" "$wc/.capstan/effort-archive"
  cp "$wc/.capstan/effort/CLAIM.md" "$wc/.capstan/effort 2/CLAIM.md"
  printf 'notes\n' > "$wc/.capstan/effort-notes.md"
  printf 'c\n' > "$wc/.capstan/effort (conflicted copy)"
  out=$("$CLEAN" "$wc" --effort checkout --owner alice)
  assert_no_file "$wc/.capstan/effort"
  assert_no_file "$wc/.capstan/effort 2"
  assert_no_file "$wc/.capstan/effort 3"
  assert_file "$wc/.capstan/effort-archive" "prefix sibling survives"
  assert_file "$wc/.capstan/effort-notes.md" "prefix file survives"
  assert_file "$wc/.capstan/effort (conflicted copy)" "unrecognised shape survives"
  durable_intact "$wc"
  assert_contains "$out" "left in place (unrecognised name, not a sync copy): "
  assert_contains "$out" "/work tree/.capstan/effort-archive"
  assert_contains "$out" "sync copy effort 2 held a claim for effort checkout"
  assert_contains "$out" "deleted 3, left 3"
}

test_sync_copy_of_another_effort_survives_by_default() {
  local wc out
  wc=$(setup)
  mkdir -p "$wc/.capstan/effort 2" "$wc/.capstan/effort 3"
  printf '# CLAIM\neffort: billing\n' > "$wc/.capstan/effort 2/CLAIM.md"
  cp "$wc/.capstan/effort/CLAIM.md" "$wc/.capstan/effort 3/CLAIM.md"
  out=$("$CLEAN" "$wc" --effort checkout --owner alice)
  assert_file "$wc/.capstan/effort 2/CLAIM.md" "another effort's copy is kept"
  assert_no_file "$wc/.capstan/effort 3" "this effort's copy goes"
  assert_no_file "$wc/.capstan/effort"
  assert_contains "$out" "holds a claim for effort billing, not checkout"
  out=$("$CLEAN" "$wc" --effort checkout --owner alice --any-effort)
  assert_no_file "$wc/.capstan/effort 2" "deleted once the operator says so"
  assert_contains "$out" "sync copy effort 2 held a claim for effort billing"
}

test_refuses_other_effort() {
  local wc code out
  wc=$(setup)
  out=$("$CLEAN" "$wc" --effort billing --owner alice 2>&1) && code=0 || code=$?
  assert_exit 2 "$code"
  assert_contains "$out" "belongs to effort 'checkout', not 'billing'"
  assert_file "$wc/.capstan/effort/spec.md"
}

test_refuses_other_owner() {
  local wc code out
  wc=$(setup)
  out=$("$CLEAN" "$wc" --effort checkout --owner bob 2>&1) && code=0 || code=$?
  assert_exit 2 "$code"
  assert_contains "$out" "held by 'alice', not 'bob'"
  assert_file "$wc/.capstan/effort/spec.md"
}

test_unclaimed_scratch_needs_explicit_flag() {
  local wc code
  wc=$(setup)
  rm -rf "$wc/.capstan/effort/.claim.lock" "$wc/.capstan/effort/CLAIM.md"
  "$CLEAN" "$wc" --effort checkout --owner alice >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code"
  assert_file "$wc/.capstan/effort/spec.md"
  "$CLEAN" "$wc" --effort checkout --owner alice --allow-unclaimed >/dev/null
  assert_no_file "$wc/.capstan/effort"
}

test_symlinked_scratch_removes_link_not_target() {
  local wc target out
  wc=$(setup)
  target=$(tmpdir)/elsewhere
  mkdir -p "$target"
  printf 'keep\n' > "$target/precious"
  rm -rf "$wc/.capstan/effort"
  ln -s "$target" "$wc/.capstan/effort"
  out=$("$CLEAN" "$wc" --effort checkout --owner alice)
  assert_no_file "$wc/.capstan/effort"
  assert_file "$target/precious" "symlink target untouched"
  assert_contains "$out" "symlink removed, target untouched"
}

test_symlinked_sync_copy_removes_link_not_target() {
  local wc target
  wc=$(setup)
  target=$(tmpdir)/elsewhere
  mkdir -p "$target"
  printf 'keep\n' > "$target/precious"
  ln -s "$target" "$wc/.capstan/effort 2"
  "$CLEAN" "$wc" --effort checkout --owner alice >/dev/null
  assert_no_file "$wc/.capstan/effort 2"
  assert_file "$target/precious"
}

test_symlinked_capstan_dir_refused() {
  local wc real code
  wc=$(tmpdir)/repo
  mkdir -p "$wc"
  git_repo "$wc" >/dev/null
  real=$(tmpdir)/real-capstan
  mkdir -p "$real/effort"
  ln -s "$real" "$wc/.capstan"
  "$CLEAN" "$wc" --effort checkout --owner alice >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code"
  assert_file "$real/effort"
}

test_repeated_cleanup_is_a_no_op() {
  local wc out code
  wc=$(setup)
  "$CLEAN" "$wc" --effort checkout --owner alice >/dev/null
  out=$("$CLEAN" "$wc" --effort checkout --owner alice) && code=0 || code=$?
  assert_exit 0 "$code"
  assert_contains "$out" "nothing to delete"
  durable_intact "$wc"
}

test_dry_run_changes_nothing() {
  local wc out
  wc=$(setup)
  mkdir -p "$wc/.capstan/effort 2"
  out=$("$CLEAN" "$wc" --effort checkout --owner alice --dry-run)
  assert_contains "$out" "would delete scratch"
  assert_contains "$out" "would delete sync copy"
  assert_file "$wc/.capstan/effort/spec.md"
  assert_file "$wc/.capstan/effort 2"
}

test_no_capstan_dir_is_fine() {
  local wc out code
  wc=$(tmpdir)/repo
  mkdir -p "$wc"
  git_repo "$wc" >/dev/null
  out=$("$CLEAN" "$wc" --effort checkout --owner alice) && code=0 || code=$?
  assert_exit 0 "$code"
  assert_contains "$out" "nothing to delete"
}

test_rejects_non_root() {
  local wc code
  wc=$(setup)
  mkdir -p "$wc/sub"
  "$CLEAN" "$wc/sub" --effort checkout --owner alice >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code"
  assert_file "$wc/.capstan/effort/spec.md"
}

run_tests
