#!/usr/bin/env bash
# Behaviour of skills/effort/bin/capstan-worktree-remove: the worktree goes, the
# Compose project its checks created goes with it, and nothing else does.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

REMOVE="$BIN/capstan-worktree-remove"
MOCK="$REPO_ROOT/tests/mock"

# setup prints "<repo>|<worktree>|<state file>": a repository with one linked
# worktree named like a slice's, and an empty mock Docker state.
setup() {
  local root repo wt state
  root=$(cd "$(tmpdir)" && pwd)
  repo="$root/repo"
  wt="$root/worktrees/Checkout-Cart"
  mkdir -p "$repo" "$root/worktrees"
  git_repo "$repo" >/dev/null
  git -C "$repo" worktree add -q "$wt" -b checkout/cart
  state="$root/docker-state"
  : > "$state"
  printf '%s|%s|%s' "$repo" "$wt" "$state"
}

row() { # STATE KIND ID PROJECT WORKING_DIR
  printf '%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "$5" >> "$1"
}

with_mock() { # STATE COMMAND...
  local state="$1"; shift
  PATH="$MOCK:$PATH" DOCKER_MOCK_STATE="$state" "$@"
}

test_removes_worktree_and_its_project() {
  local s repo wt state out
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" container c1 checkout-cart "$wt"
  row "$state" network n1 checkout-cart ""
  row "$state" volume v1 checkout-cart ""
  row "$state" image i1 checkout-cart ""
  row "$state" image i1 checkout-cart ""
  row "$state" image pg "" ""
  row "$state" container other main-app "$repo"
  row "$state" volume v2 main-app ""
  out=$(with_mock "$state" "$REMOVE" "$repo" "$wt")
  assert_no_file "$wt"
  assert_contains "$out" "removed container: c1"
  assert_contains "$out" "removed network: n1"
  assert_contains "$out" "removed volume: v1"
  assert_contains "$out" "removed image: i1"
  assert_eq "$(printf 'image\tpg\t\t\ncontainer\tother\tmain-app\t%s\nvolume\tv2\tmain-app\t' "$repo")" "$(cat "$state")" \
    "pulled images and other projects survive"
}

test_finds_projects_run_from_inside_the_worktree() {
  local s repo wt state out
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" container c1 infra "$wt/infra"
  row "$state" volume v1 infra ""
  out=$(with_mock "$state" "$REMOVE" "$repo" "$wt")
  assert_contains "$out" "removed container: c1"
  assert_contains "$out" "removed volume: v1"
}

test_leaves_a_project_shared_with_another_directory() {
  local s repo wt state out
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" container c1 checkout-cart "/elsewhere/checkout-cart"
  row "$state" volume v1 checkout-cart ""
  out=$(with_mock "$state" "$REMOVE" "$repo" "$wt")
  assert_no_file "$wt"
  assert_contains "$out" "left in place (project checkout-cart has containers from /elsewhere/checkout-cart)"
  assert_contains "$(cat "$state")" "v1"
}

test_dry_run_changes_nothing() {
  local s repo wt state out
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" volume v1 checkout-cart ""
  out=$(with_mock "$state" "$REMOVE" "$repo" "$wt" --dry-run)
  assert_file "$wt"
  assert_contains "$out" "would remove worktree: "
  assert_contains "$out" "would remove volume: v1"
  assert_contains "$(cat "$state")" "v1"
}

test_no_daemon_still_removes_the_worktree() {
  local s repo wt state out code
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" volume v1 checkout-cart ""
  out=$(DOCKER_MOCK_DOWN=1 with_mock "$state" "$REMOVE" "$repo" "$wt") && code=0 || code=$?
  assert_exit 0 "$code"
  assert_no_file "$wt"
  assert_contains "$out" "docker: not reachable"
  assert_contains "$(cat "$state")" "v1"
}

test_dirty_worktree_is_refused_and_docker_untouched() {
  local s repo wt state code
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  row "$state" volume v1 checkout-cart ""
  printf 'wip\n' > "$wt/README"
  with_mock "$state" "$REMOVE" "$repo" "$wt" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 3 "$code"
  assert_file "$wt/README"
  assert_contains "$(cat "$state")" "v1"
  with_mock "$state" "$REMOVE" "$repo" "$wt" --force >/dev/null
  assert_no_file "$wt"
  assert_not_contains "$(cat "$state")" "v1"
}

test_refuses_the_main_working_copy() {
  local s repo wt state code
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  with_mock "$state" "$REMOVE" "$repo" "$repo" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code"
  assert_file "$repo/README"
}

test_refuses_a_directory_that_is_not_a_worktree() {
  local s repo wt state code other
  s=$(setup); repo=${s%%|*}; s=${s#*|}; wt=${s%%|*}; state=${s#*|}
  other=$(tmpdir)
  with_mock "$state" "$REMOVE" "$repo" "$other" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code"
  assert_file "$other"
}

run_tests
