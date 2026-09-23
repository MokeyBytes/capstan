#!/usr/bin/env bash
# Behaviour of bench/bin/session-usage: dedupe by message.id, subagent
# tokens included, known models priced, unknown models never $0, and a
# malformed line named and refused rather than silently zeroed.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

SESSION_USAGE="$REPO_ROOT/bench/bin/session-usage"
FIXTURES="$REPO_ROOT/tests/fixtures/sessions"

command -v jq >/dev/null 2>&1 || { printf '%s: jq is not installed, skipped\n' "$(basename "$0")"; exit 0; }

test_dedupes_repeated_message_id_and_sums_subagent_tokens() {
  # By hand from tests/fixtures/sessions/ses0001.jsonl and its subagents/
  # file: msg_fixtureA appears twice (same id) and must count once.
  #   sonnet: msg_fixtureA (input 1,000,000 output 500,000) once, plus the
  #     subagent's msg_fixtureSub1 (input 500,000 output 250,000)
  #     = input 1,500,000, output 750,000
  #   opus: msg_fixtureB only = input 2,000,000, output 100,000,
  #     cache_write_5m 500,000, cache_read 1,000,000
  local out
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t1500000\t750000\t0\t0\t0\t10.5')" "sonnet totals, deduped and including the subagent"
  assert_contains "$out" "$(printf 'claude-opus-5\t2000000\t100000\t500000\t0\t1000000\t12.7')" "opus totals"
  assert_contains "$out" "$(printf 'TOTAL\t3500000\t850000\t500000\t0\t1000000\t23.2')" "grand total across both models"
}

test_synthetic_lines_are_skipped_not_errored() {
  # msg_fixtureSynthetic has model <synthetic> and no usage block at all; if
  # the synthetic check ran after the missing-usage check, this would fail
  # loudly instead of being skipped.
  local out code
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl" 2>&1) && code=0 || code=$?
  assert_exit 0 "$code" "a <synthetic> line with no usage block does not trip the missing-field refusal"
  assert_not_contains "$out" "fixtureSynthetic"
  assert_not_contains "$out" "synthetic"
}

test_session_dir_and_session_jsonl_paths_agree() {
  local by_file by_dir
  by_file=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  by_dir=$("$SESSION_USAGE" "$FIXTURES/ses0001")
  assert_eq "$by_file" "$by_dir" "the sibling file and the sibling directory resolve to the same session"
}

test_first_and_last_timestamp_span_the_subagent() {
  local out
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'first_timestamp\t2026-09-20T10:00:00.000Z')"
  assert_contains "$out" "$(printf 'last_timestamp\t2026-09-20T10:10:00.000Z')" "the subagent's line is the latest timestamp in the session"
}

test_fails_loudly_naming_the_missing_field() {
  local out code
  out=$("$SESSION_USAGE" "$FIXTURES/bad0001.jsonl" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "a line missing message.usage is refused, not printed as a zero total"
  assert_contains "$out" "message.usage" "the refusal names the missing field"
}

test_unpriced_model_is_never_reported_as_zero_cost() {
  local pricing out
  pricing=$(tmpdir)/pricing.tsv
  printf 'model\tinput_per_mtok\toutput_per_mtok\tcache_write_5m_per_mtok\tcache_write_1h_per_mtok\tcache_read_per_mtok\n' > "$pricing"
  printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20\n' >> "$pricing"
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t1500000\t750000\t0\t0\t0\tunpriced')" "a model absent from pricing.tsv is unpriced, not \$0"
  assert_contains "$out" "partial: unpriced claude-sonnet-5" "the total says it is partial and names the unpriced model"
}

test_usage_error_with_no_arguments() {
  local out code
  out=$("$SESSION_USAGE" 2>&1) && code=0 || code=$?
  assert_exit 64 "$code" "no arguments is a usage error"
}

test_missing_transcript_is_refused() {
  local out code
  out=$("$SESSION_USAGE" "$(tmpdir)/does-not-exist" 2>&1) && code=0 || code=$?
  assert_exit 2 "$code" "a path with no transcript is refused, not silently empty"
}

run_tests
