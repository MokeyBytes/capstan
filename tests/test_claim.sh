#!/usr/bin/env bash
# Behaviour of skills/effort/bin/capstan-claim: atomic ownership, resume,
# takeover, the immutable baseline, the verified commit, and the dispatch limits.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

CLAIM="$BIN/capstan-claim"

new_repo() { # prints the path of a fresh repository
  local d
  d=$(tmpdir)
  git_repo "$d" >/dev/null
  printf '%s' "$d"
}

test_acquire_creates_lock_and_record() {
  local wc out
  wc=$(new_repo)
  out=$("$CLAIM" acquire "$wc" --owner alice --effort checkout)
  assert_contains "$out" "fresh"
  assert_file "$wc/.capstan/effort/.claim.lock/owner"
  assert_eq "alice" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
  assert_file "$wc/.capstan/effort/CLAIM.md"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "effort: checkout"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "base_commit: $(git -C "$wc" rev-parse HEAD)"
}

test_simultaneous_acquire_has_one_winner() {
  local wc i wins=0 pids=() codes
  wc=$(new_repo)
  codes=$(tmpdir)
  for i in 1 2 3 4 5 6 7 8; do
    ( "$CLAIM" acquire "$wc" --owner "session-$i" --effort race >/dev/null 2>&1; echo $? > "$codes/$i" ) &
    pids+=($!)
  done
  wait "${pids[@]}" 2>/dev/null || true
  for i in 1 2 3 4 5 6 7 8; do
    [[ "$(cat "$codes/$i")" == "0" ]] && wins=$((wins + 1))
  done
  assert_eq "1" "$wins" "exactly one acquire succeeds"
  local holder
  holder=$(cat "$wc/.capstan/effort/.claim.lock/owner")
  assert_contains "$holder" "session-"
  # every loser exited 2 (held), never 0 and never crashed
  for i in 1 2 3 4 5 6 7 8; do
    local c
    c=$(cat "$codes/$i")
    [[ "$c" == "0" || "$c" == "2" ]] || fail "session-$i exited $c"
  done
}

test_second_owner_refused_with_record() {
  local wc out code
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  out=$("$CLAIM" acquire "$wc" --owner bob --effort e1 2>&1) && code=0 || code=$?
  assert_exit 2 "$code"
  assert_contains "$out" "held by alice"
  assert_contains "$out" "effort: e1"
  assert_eq "alice" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
}

test_same_owner_resumes() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  out=$("$CLAIM" acquire "$wc" --owner alice)
  assert_contains "$out" "resumed"
  assert_contains "$(cat "$wc/.capstan/effort/.claim.lock/history")" "resumed by alice"
}

test_release_by_wrong_owner_refused() {
  local wc code
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" release "$wc" --owner bob >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code"
  assert_file "$wc/.capstan/effort/.claim.lock/owner"
  "$CLAIM" release "$wc" --owner alice >/dev/null
  assert_no_file "$wc/.capstan/effort/.claim.lock"
  assert_file "$wc/.capstan/effort/CLAIM.md" "record survives release"
}

test_takeover_must_name_current_holder() {
  local wc code out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" takeover "$wc" --owner bob --from carol >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code" "wrong --from refused"
  "$CLAIM" takeover "$wc" --owner bob >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 64 "$code" "missing --from refused"
  assert_eq "alice" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
  out=$("$CLAIM" takeover "$wc" --owner bob --from alice)
  assert_contains "$out" "taken over from alice"
  assert_eq "bob" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "takeovers: alice -> bob"
}

test_age_alone_does_not_authorise_takeover() {
  local wc code
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  touch -t 202001010000 "$wc/.capstan/effort/.claim.lock/owner" "$wc/.capstan/effort/.claim.lock"
  "$CLAIM" acquire "$wc" --owner bob >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code" "a stale lock with an owner is still held"
  assert_eq "alice" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
}

test_interrupted_initialisation() {
  local wc code out
  wc=$(new_repo)
  mkdir -p "$wc/.capstan/effort/.claim.lock"
  # fresh: someone may be between mkdir and writing the owner file
  "$CLAIM" acquire "$wc" --owner bob --effort e1 >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 3 "$code" "a fresh ownerless lock is in progress"
  # old: abandoned, cleared and taken
  touch -t 202001010000 "$wc/.capstan/effort/.claim.lock"
  out=$("$CLAIM" acquire "$wc" --owner bob --effort e1 2>&1) && code=0 || code=$?
  assert_exit 0 "$code"
  assert_contains "$out" "interrupted initialisation"
  assert_eq "bob" "$(cat "$wc/.capstan/effort/.claim.lock/owner")"
}

test_checkpoint_moves_head_never_base() {
  local wc base head2 code
  wc=$(new_repo)
  base=$(git -C "$wc" rev-parse HEAD)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  printf 'more\n' >> "$wc/README"
  git -C "$wc" commit -qam second
  head2=$(git -C "$wc" rev-parse HEAD)
  "$CLAIM" checkpoint "$wc" --owner alice --phase plan --next "cut slices a, b" >/dev/null
  assert_eq "$base" "$("$CLAIM" base "$wc")"
  assert_eq "$head2" "$("$CLAIM" head "$wc")"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "phase: plan"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "cut slices a, b"
  "$CLAIM" checkpoint "$wc" --owner alice --base "$head2" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 64 "$code" "base_commit cannot be set through checkpoint"
  assert_eq "$base" "$("$CLAIM" base "$wc")"
  "$CLAIM" checkpoint "$wc" --owner bob --phase build >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code" "non-owner cannot checkpoint"
}

test_multiline_next_round_trips() {
  local wc nf
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  nf=$(tmpdir)/next.txt
  printf 'line one\n\nline three: a=1, b=2\n' > "$nf"
  "$CLAIM" checkpoint "$wc" --owner alice --next-file "$nf" >/dev/null
  assert_contains "$("$CLAIM" status "$wc")" "line three: a=1, b=2"
  assert_contains "$("$CLAIM" status "$wc")" "line one"
}

test_older_claim_is_degraded_not_invented() {
  local wc code out sha
  wc=$(new_repo)
  sha=$(git -C "$wc" rev-parse HEAD)
  mkdir -p "$wc/.capstan/effort"
  cat > "$wc/.capstan/effort/CLAIM.md" <<EOF
# CLAIM
effort: legacy
started: 2026-09-01T00:00:00Z
phase: build
head: $sha
next: slice a at fix 2
last-touched: 2026-09-02T00:00:00Z
EOF
  "$CLAIM" base "$wc" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 6 "$code" "no base_commit means degraded"
  "$CLAIM" acquire "$wc" --owner bob >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code" "an older claim is not taken silently"
  out=$("$CLAIM" acquire "$wc" --owner bob --adopt)
  assert_contains "$out" "fresh"
  assert_eq "$sha" "$("$CLAIM" head "$wc")" "head read as the checkpoint"
  "$CLAIM" base "$wc" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 6 "$code" "adoption never invents a baseline"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "slice a at fix 2"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "effort: legacy"
  assert_contains "$out" "adopted claim: fix-dispatch counts"
  assert_contains "$("$CLAIM" status "$wc")" "adopted:"
  # counts carried as text are never read as zero
  out=$("$CLAIM" dispatch "$wc" --owner bob fix --slice a 2>&1) && code=0 || code=$?
  assert_exit 6 "$code" "unknown legacy count refuses the dispatch"
  assert_contains "$out" "count for a is unknown"
  assert_not_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "a=1"
  "$CLAIM" reset "$wc" --owner bob --slice a --count 2 >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner bob fix --slice a)
  assert_contains "$out" "dispatched fix 3 of 5 on a"
  assert_contains "$out" "design-question: fires"
  "$CLAIM" return "$wc" --owner bob --slice a >/dev/null
  "$CLAIM" dispatch "$wc" --owner bob fix --slice b >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 6 "$code" "every slice is transcribed on its own"
  "$CLAIM" reset "$wc" --owner bob --slice b --count 0 >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner bob fix --slice b)
  assert_contains "$out" "dispatched fix 1 of 5 on b"
  "$CLAIM" dispatch "$wc" --owner bob note >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 6 "$code" "the note count is transcribed too"
}

test_note_design_question_signal() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice note >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice note)
  assert_not_contains "$out" "design-question"
  out=$("$CLAIM" dispatch "$wc" --owner alice note)
  assert_contains "$out" "design-question: fires (fix dispatch 3 on the note)"
}

test_return_and_reset_validate_slice_names() {
  local wc code before
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice fix --slice a >/dev/null
  before=$(cat "$wc/.capstan/effort/CLAIM.md")
  "$CLAIM" reset "$wc" --owner alice --slice 'a=9, b' >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 64 "$code" "a forged map entry is refused"
  "$CLAIM" return "$wc" --owner alice --slice 'x,y' >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 64 "$code"
  "$CLAIM" reset "$wc" --owner alice --slice a --count x >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 64 "$code" "a count must be a number"
  assert_eq "$before" "$(cat "$wc/.capstan/effort/CLAIM.md")" "record untouched by refused calls"
}

test_acquire_clears_in_flight_across_runs() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice build --slice a --max-builders 1 >/dev/null
  # the run ends here; the next run resumes
  out=$("$CLAIM" acquire "$wc" --owner alice)
  assert_contains "$out" "cleared builders_in_flight (a)"
  assert_not_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "builders_in_flight: a"
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice b --max-builders 1)
  assert_contains "$out" "dispatched build on b (1 of 1 builders in flight)"
}

test_verified_and_drift() {
  local wc v code out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" drift "$wc" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 6 "$code" "no verified commit is degraded"
  v=$(git -C "$wc" rev-parse HEAD)
  "$CLAIM" verified "$wc" --owner alice --commit "$v" >/dev/null
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 0 "$code"
  assert_contains "$out" "drift: none"
  # a document-home-only commit does not invalidate
  mkdir -p "$wc/.capstan"
  printf '| 1 | 2026-09-22 | x | accepted |\n' > "$wc/.capstan/decisions.md"
  git -C "$wc" add .capstan/decisions.md
  git -C "$wc" commit -qm "record 1"
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 0 "$code" "document home commits do not drift"
  assert_contains "$out" "document home  .capstan/decisions.md"
  # a version bump after verification does
  printf '{"version":"2.0.0"}\n' > "$wc/plugin.json"
  git -C "$wc" add plugin.json
  git -C "$wc" commit -qm "bump"
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 8 "$code" "a repository change after verification drifts"
  assert_contains "$out" "OUTSIDE        plugin.json"
  assert_contains "$out" "verified_commit: $v"
  # re-verifying at HEAD clears it
  "$CLAIM" verified "$wc" --owner alice --commit HEAD >/dev/null
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 0 "$code"
  # uncommitted change outside the document home drifts too
  printf 'x\n' >> "$wc/README"
  "$CLAIM" drift "$wc" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 8 "$code" "uncommitted repository change drifts"
}

test_drift_renames_keep_their_paths() {
  local wc code out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  mkdir -p "$wc/.capstan/decisions"
  printf 'r\n' > "$wc/.capstan/decisions/0001-old-name.md"
  git -C "$wc" add .capstan
  git -C "$wc" commit -qm "record"
  "$CLAIM" verified "$wc" --owner alice --commit HEAD >/dev/null
  git -C "$wc" mv .capstan/decisions/0001-old-name.md .capstan/decisions/0001-new-name.md
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 0 "$code" "a rename inside the document home is not drift"
  assert_contains "$out" "document home  .capstan/decisions/0001-old-name.md"
  assert_contains "$out" "document home  .capstan/decisions/0001-new-name.md"
  git -C "$wc" mv README READ-ME
  out=$("$CLAIM" drift "$wc") && code=0 || code=$?
  assert_exit 8 "$code"
  assert_contains "$out" "OUTSIDE        README"
  assert_contains "$out" "OUTSIDE        READ-ME"
  assert_not_contains "$out" " DME"
}

test_drift_ignores_the_scratch_itself() {
  local wc code out home
  wc=$(new_repo)
  home=$(tmpdir)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" verified "$wc" --owner alice --commit HEAD >/dev/null
  mkdir -p "$wc/.capstan/effort 2"
  printf 'x\n' > "$wc/.capstan/effort 2/spec.md"
  # no .gitignore in this repository, and the document home is elsewhere
  out=$("$CLAIM" drift "$wc" --document-home "$home") && code=0 || code=$?
  assert_exit 0 "$code" "untracked scratch files are never drift"
  assert_contains "$out" "scratch        .capstan/effort/CLAIM.md"
  assert_contains "$out" "scratch        .capstan/effort 2/spec.md"
}

test_drift_with_configured_document_home() {
  local wc v code out home
  wc=$(new_repo)
  home=$(tmpdir)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" verified "$wc" --owner alice --commit HEAD >/dev/null
  mkdir -p "$wc/.capstan"
  printf 'x\n' > "$wc/.capstan/decisions.md"
  git -C "$wc" add .capstan/decisions.md
  git -C "$wc" commit -qm "record"
  out=$("$CLAIM" drift "$wc" --document-home "$home") && code=0 || code=$?
  assert_exit 8 "$code" "with the home elsewhere, .capstan is an ordinary path"
  v=$(git -C "$wc" rev-parse HEAD)
  assert_contains "$out" "head: $v"
}

test_fix_dispatch_limit_preserves_state() {
  local wc i code out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  for i in 1 2; do
    "$CLAIM" dispatch "$wc" --owner alice fix --slice api --max-fix 2 --max-builders 5 >/dev/null
    "$CLAIM" return "$wc" --owner alice --slice api >/dev/null
  done
  out=$("$CLAIM" dispatch "$wc" --owner alice fix --slice api --max-fix 2 --max-builders 5 2>&1) && code=0 || code=$?
  assert_exit 5 "$code"
  assert_contains "$out" "fix-dispatch limit 2 reached on api (count 2)"
  assert_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "fix_dispatches: api=2"
  assert_not_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "api=3"
  assert_not_contains "$(cat "$wc/.capstan/effort/CLAIM.md")" "builders_in_flight: api"
}

test_fix_count_survives_resumption_and_release() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice fix --slice api >/dev/null
  "$CLAIM" return "$wc" --owner alice --slice api >/dev/null
  "$CLAIM" release "$wc" --owner alice >/dev/null
  "$CLAIM" acquire "$wc" --owner bob >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner bob fix --slice api)
  assert_contains "$out" "dispatched fix 2 of 5 on api"
}

test_design_question_signal_from_third_dispatch() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice fix --slice api >/dev/null
  "$CLAIM" return "$wc" --owner alice --slice api >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice fix --slice api)
  assert_not_contains "$out" "design-question"
  "$CLAIM" return "$wc" --owner alice --slice api >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice fix --slice api)
  assert_contains "$out" "design-question: fires (fix dispatch 3 on api)"
}

test_builder_concurrency_bounded() {
  local wc code out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice build --slice a --max-builders 2 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice build --slice b --max-builders 2 >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice c --max-builders 2 2>&1) && code=0 || code=$?
  assert_exit 5 "$code"
  assert_contains "$out" "builder limit 2 reached (in flight: a, b)"
  "$CLAIM" return "$wc" --owner alice --slice a >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice c --max-builders 2)
  assert_contains "$out" "dispatched build on c (2 of 2 builders in flight)"
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice b --max-builders 5 2>&1) && code=0 || code=$?
  assert_exit 5 "$code" "the same slice cannot be dispatched twice"
}

test_limits_read_from_config_and_default() {
  local wc out code
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice a)
  assert_contains "$out" "(1 of 3 builders in flight)" "default builders is 3"
  out=$("$CLAIM" dispatch "$wc" --owner alice note)
  assert_contains "$out" "dispatched fix 1 of 5 on the note" "default fix limit is 5"
  printf 'capstan-max-builders: 1\ncapstan-max-fix-dispatches: 2\n' > "$wc/CLAUDE.md"
  out=$("$CLAIM" dispatch "$wc" --owner alice build --slice b 2>&1) && code=0 || code=$?
  assert_exit 5 "$code" "configured builder limit applies"
  printf 'capstan-max-builders: 4\n' > "$wc/AGENTS.md"
  "$CLAIM" dispatch "$wc" --owner alice build --slice b >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 2 "$code" "disagreeing config files stop the dispatch"
}

test_reset_after_recut() {
  local wc out
  wc=$(new_repo)
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  "$CLAIM" dispatch "$wc" --owner alice fix --slice api --max-fix 1 >/dev/null
  "$CLAIM" return "$wc" --owner alice --slice api >/dev/null
  out=$("$CLAIM" reset "$wc" --owner alice --slice api)
  assert_contains "$out" "reset api from 1 to 0"
  out=$("$CLAIM" dispatch "$wc" --owner alice fix --slice api --max-fix 1)
  assert_contains "$out" "dispatched fix 1 of 1 on api"
}

test_rejects_non_root_and_non_repo() {
  local d code
  d=$(tmpdir)
  "$CLAIM" status "$d" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code"
  local wc
  wc=$(new_repo)
  mkdir -p "$wc/sub"
  "$CLAIM" status "$wc/sub" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 7 "$code" "a subdirectory is not the working copy root"
  "$CLAIM" status "$wc" >/dev/null 2>&1 && code=0 || code=$?
  assert_exit 4 "$code" "no claim yet"
}

test_path_with_spaces() {
  local wc
  wc=$(tmpdir)/"my repo"
  mkdir -p "$wc"
  git_repo "$wc" >/dev/null
  "$CLAIM" acquire "$wc" --owner alice --effort e1 >/dev/null
  assert_file "$wc/.capstan/effort/.claim.lock/owner"
  "$CLAIM" release "$wc" --owner alice >/dev/null
}

run_tests
