#!/usr/bin/env bash
# Behaviour of bench/bin/session-usage: dedupe by message.id keeping the
# stop_reason line's usage (or the per-field maximum for an interrupted
# turn), subagent tokens included, known models and known cost components
# priced, an unpriced model or component never printed as $0, and a
# malformed or incomplete line named and refused rather than silently
# zeroed or merged.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

SESSION_USAGE="$REPO_ROOT/bench/bin/session-usage"
FIXTURES="$REPO_ROOT/tests/fixtures/sessions"

command -v jq >/dev/null 2>&1 || { printf '%s: jq is not installed, skipped\n' "$(basename "$0")"; exit 0; }

# pricing_file ROW... writes a fresh session-usage pricing.tsv under a
# temporary directory, one ROW per model (tab-separated: model, input,
# output, cache_write_5m, cache_write_1h, cache_read; leave a field blank
# for an unpriced component), and prints its path.
pricing_file() {
  local f
  f="$(tmpdir)/pricing.tsv"
  printf 'model\tinput_per_mtok\toutput_per_mtok\tcache_write_5m_per_mtok\tcache_write_1h_per_mtok\tcache_read_per_mtok\n' > "$f"
  local row
  for row in "$@"; do
    printf '%s\n' "$row" >> "$f"
  done
  printf '%s' "$f"
}

test_dedupes_repeated_message_id_and_sums_subagent_tokens() {
  # Own pricing file rather than the shipped bench/pricing.tsv, which the
  # protocol tells the operator to edit at every pre-flight.
  #
  # By hand from tests/fixtures/sessions/ses0001.jsonl and its subagents/
  # file:
  #   msg_fixtureA appears twice with identical usage (same id) and must
  #     count once: input 1,000,000, output 500,000.
  #   msg_fixtureSub1 (subagent, one line): input 500,000, output 250,000.
  #   msg_fixtureSub2 (subagent, three lines of one split turn): output
  #     rises 3, then 7, then 16 on the line that carries stop_reason.
  #     The kept usage is the stop_reason line's own: input 200,000,
  #     output 16. Keeping the first line, as before this fix, would have
  #     kept output 3.
  #   sonnet total: input 1,000,000 + 500,000 + 200,000 = 1,700,000;
  #     output 500,000 + 250,000 + 16 = 750,016.
  #   msg_fixtureB (opus, one line): input 2,000,000, output 100,000,
  #     cache_write_5m 500,000, cache_read 1,000,000.
  #   costs at $2/$10/mtok (sonnet) and $4/$20/$5/$0.20/mtok (opus):
  #     sonnet 1.7*2 + 0.750016*10 = 10.90016
  #     opus   2*4 + 0.1*20 + 0.5*5 + 1*0.2 = 12.7
  #     total  23.60016
  local pricing out
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t\t0.20')" "$(printf 'claude-sonnet-5\t2.00\t10.00\t2.50\t\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t1700000\t750016\t0\t0\t0\t10.90016')" "sonnet totals: deduped, subagent included, split-turn output taken from the stop_reason line"
  assert_contains "$out" "$(printf 'claude-opus-5\t2000000\t100000\t500000\t0\t1000000\t12.7')" "opus totals"
  assert_contains "$out" "$(printf 'TOTAL\t3700000\t850016\t500000\t0\t1000000\t23.60016')" "grand total across both models"
}

test_interrupted_turn_falls_back_to_the_maximum_of_each_field() {
  # A turn with no stop_reason line at all: the group's per-field maximum
  # is kept rather than the first line, since no line marks itself final.
  local fixture pricing out
  fixture=$(tmpdir)/interrupted.jsonl
  cat > "$fixture" <<'JSONL'
{"type":"assistant","message":{"id":"msg_interrupted","model":"claude-sonnet-5","role":"assistant","content":[{"type":"text","text":"a"}],"usage":{"input_tokens":100,"output_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T10:00:00.000Z"}
{"type":"assistant","message":{"id":"msg_interrupted","model":"claude-sonnet-5","role":"assistant","content":[{"type":"text","text":"ab"}],"usage":{"input_tokens":100,"output_tokens":7,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T10:00:01.000Z"}
JSONL
  pricing=$(pricing_file "$(printf 'claude-sonnet-5\t2.00\t10.00\t2.50\t\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t100\t7\t0\t0\t0')" "no stop_reason line in the group: output is the max across lines (7), not the first (3)"
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
  assert_contains "$out" "$(printf 'first_timestamp\t%s\t2026-09-20T10:00:00.000Z' "ses0001")"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\t2026-09-20T10:11:02.000Z' "ses0001")" "the subagent's split turn's last line is the latest timestamp in the session"
}

test_each_argument_gets_its_own_span_so_a_forked_files_time_is_not_doubled() {
  # ses0002.jsonl repeats ses0001.jsonl's msg_fixtureA turn verbatim, the way
  # /branch and --fork-session copy a session's opening turns into a new
  # file. Passed together, ses0001 keeps its own natural span, 10:00:00 to
  # 10:11:02, since it is the first argument that carries msg_fixtureA.
  # ses0002's own span must then start at msg_fixtureC, its one turn that
  # is not a copy, rather than at 10:00:00 again. Summing the two spans
  # must not count msg_fixtureA's slice of time twice.
  local out
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl" "$FIXTURES/ses0002.jsonl")
  assert_contains "$out" "$(printf 'first_timestamp\t%s\t2026-09-20T10:00:00.000Z' "ses0001")" "ses0001 keeps its own natural first timestamp"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\t2026-09-20T10:11:02.000Z' "ses0001")" "ses0001 keeps its own natural last timestamp"
  assert_contains "$out" "$(printf 'first_timestamp\t%s\t2026-09-20T10:21:00.000Z' "ses0002")" "ses0002's copied opening turn is credited to ses0001, so its own span starts at its one real turn"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\t2026-09-20T10:21:00.000Z' "ses0002")" "ses0002's own span does not reach back to the copied turn's time"
}

test_fails_loudly_naming_the_missing_field() {
  local out code
  out=$("$SESSION_USAGE" "$FIXTURES/bad0001.jsonl" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "a line missing message.usage is refused, not printed as a zero total"
  assert_contains "$out" "message.usage" "the refusal names the missing field"
}

test_missing_message_id_is_refused_not_merged() {
  local fixture out code
  fixture=$(tmpdir)/noid.jsonl
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5","role":"assistant","content":[],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  out=$("$SESSION_USAGE" "$fixture" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "a line missing message.id is refused, not merged into another turn's total"
  assert_contains "$out" "message.id" "the refusal names the missing field"
}

test_missing_usage_subfield_is_refused_not_zeroed() {
  local fixture out code
  fixture=$(tmpdir)/nocreadfield.jsonl
  printf '{"type":"assistant","message":{"id":"msg_x","model":"claude-sonnet-5","role":"assistant","content":[],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  out=$("$SESSION_USAGE" "$fixture" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "a line missing cache_read_input_tokens is refused, not treated as zero"
  assert_contains "$out" "message.usage.cache_read_input_tokens" "the refusal names the missing sub-field"
}

test_unpriced_model_is_never_reported_as_zero_cost() {
  local pricing out
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t1700000\t750016\t0\t0\t0\tunpriced')" "a model absent from pricing.tsv is unpriced, not \$0"
  assert_contains "$out" "partial: unpriced claude-sonnet-5" "the total says it is partial and names the unpriced model"
}

test_no_priced_model_prints_unpriced_total_not_zero() {
  local pricing out
  pricing=$(pricing_file)
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'TOTAL\t3700000\t850016\t500000\t0\t1000000\tunpriced')" "no row prices any model in this session: the total prints unpriced, never 0"
}

test_blank_rate_prices_known_components_and_flags_the_rest_partial() {
  # This fixture's own pricing file leaves cache_write_1h_per_mtok blank,
  # unlike the shipped pricing.tsv, which now prices it. A session with
  # nonzero cache_write_1h usage cannot be fully priced when the pricing
  # file supplying that rate is missing it: the known components are still
  # summed, and the row and total both say which component is missing
  # rather than silently pricing it at 0.
  local fixture pricing out
  fixture=$(tmpdir)/cw1h.jsonl
  printf '{"type":"assistant","message":{"id":"msg_x","model":"claude-opus-5","role":"assistant","content":[],"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":40}}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_contains "$out" "0.0014 (partial: cache_write_1h unpriced)" "the known components are priced and the missing one is named"
  assert_contains "$out" "partial: cache_write_1h unpriced for claude-opus-5" "the total names the model and the missing component"
}

test_multiple_session_paths_dedupe_shared_ids_and_sum_the_rest() {
  # ses0002.jsonl repeats ses0001.jsonl's msg_fixtureA turn verbatim, the
  # way `/branch` and `--fork-session` copy a session's opening turns into
  # a new file, then adds one turn of its own, msg_fixtureC (sonnet, one
  # line): input 10,000, output 2,000. Passed together in one call,
  # msg_fixtureA must count once, not twice.
  local pricing out
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t\t0.20')" "$(printf 'claude-sonnet-5\t2.00\t10.00\t2.50\t\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0001.jsonl" "$FIXTURES/ses0002.jsonl")
  assert_contains "$out" "$(printf 'claude-sonnet-5\t1710000\t752016\t0\t0\t0\t10.94016')" "sonnet totals across both files: msg_fixtureA counted once, msg_fixtureC added on top"
  assert_contains "$out" "$(printf 'TOTAL\t3710000\t852016\t500000\t0\t1000000\t23.64016')" "grand total across both files and both models"
}

test_second_file_alone_does_not_repeat_the_shared_turn() {
  # Confirms ses0002.jsonl on its own counts msg_fixtureA once, so the
  # dedupe in the previous test is credited to the multi-path call and not
  # to some property of ses0002.jsonl alone.
  local pricing out
  pricing=$(pricing_file "$(printf 'claude-sonnet-5\t2.00\t10.00\t2.50\t\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$FIXTURES/ses0002.jsonl")
  assert_contains "$out" "$(printf 'TOTAL\t1010000\t502000\t0\t0\t0')" "ses0002.jsonl alone: msg_fixtureA plus msg_fixtureC"
}

test_reversed_argument_order_changes_which_argument_owns_the_shared_turn() {
  # Ownership of a shared turn follows argument order, first argument wins,
  # not chronology. Passing ses0002 before ses0001 flips who owns
  # msg_fixtureA: ses0002 now keeps it and its full natural span
  # (10:00:00 to 10:21:00), and ses0001's own span narrows to the turns
  # that are actually its own (msg_fixtureB through the subagent's last
  # line, 10:05:00 to 10:11:02), the reverse of the forward-order test
  # above. This is why the protocol tells the operator to pass files
  # oldest-created first.
  local out
  out=$("$SESSION_USAGE" "$FIXTURES/ses0002.jsonl" "$FIXTURES/ses0001.jsonl")
  assert_contains "$out" "$(printf 'first_timestamp\t%s\t2026-09-20T10:00:00.000Z' "ses0002")" "ses0002, now first, keeps the shared turn and its natural first timestamp"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\t2026-09-20T10:21:00.000Z' "ses0002")" "ses0002's own span reaches its own last turn"
  assert_contains "$out" "$(printf 'first_timestamp\t%s\t2026-09-20T10:05:00.000Z' "ses0001")" "ses0001, now second, no longer owns the shared turn: its span starts at its own first remaining turn"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\t2026-09-20T10:11:02.000Z' "ses0001")" "ses0001 keeps its own last timestamp regardless of order"
}

test_argument_that_owns_no_kept_turn_prints_none_not_a_blank_line() {
  # ses0003.jsonl carries only a verbatim copy of msg_fixtureA, already
  # owned by ses0001 when it comes first. group_by(.owner) alone never
  # produces a group for an owner with zero turns, so ses0003 must still
  # get a span line, printing "none" rather than being dropped from the
  # output entirely.
  local out
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl" "$FIXTURES/ses0002.jsonl" "$FIXTURES/ses0003.jsonl")
  assert_contains "$out" "$(printf 'first_timestamp\t%s\tnone' "ses0003")" "an argument that owns no turn still prints its first_timestamp line, as none"
  assert_contains "$out" "$(printf 'last_timestamp\t%s\tnone' "ses0003")" "an argument that owns no turn still prints its last_timestamp line, as none"
}

test_unreadable_file_fails_loudly_rather_than_dropping_silently() {
  # Round-2 regression: a process substitution hid an unreadable file's
  # failure from `set -e`, so the total printed without the missing file's
  # tokens and exited 0. Skipped under root, which ignores file mode bits.
  if [[ "$(id -u)" == 0 ]]; then
    printf '  skip %s: skipped (root)\n' "$_T_CURRENT"
    return 0
  fi
  local dir out code
  dir=$(tmpdir)
  cp -R "$FIXTURES/ses0001.jsonl" "$FIXTURES/ses0001" "$dir/"
  chmod 000 "$dir/ses0001/subagents/agent-fixturesub.jsonl"
  out=$("$SESSION_USAGE" "$dir/ses0001.jsonl" 2>&1) && code=0 || code=$?
  chmod 644 "$dir/ses0001/subagents/agent-fixturesub.jsonl"
  assert_exit 1 "$code" "an unreadable subagent file is refused, not silently dropped from the total"
  assert_contains "$out" "could not be read" "the refusal names the read failure"
  assert_not_contains "$out" "TOTAL" "no total is printed once a file cannot be read"
}

test_last_line_without_a_trailing_newline_reports_its_true_line_number() {
  # noeol0001.jsonl's third and final line is missing message.usage and has
  # no trailing newline. Round-2 regression: jq's input_line_number
  # undercounts by one when the last line has no trailing newline, so this
  # reported line 2 instead of line 3.
  local out code
  out=$("$SESSION_USAGE" "$FIXTURES/noeol0001.jsonl" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "the malformed last line is still refused"
  assert_contains "$out" ":3:" "the line missing a trailing newline is still named by its real line number, 3"
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

test_one_good_argument_and_one_empty_directory_dies_naming_the_empty_one() {
  # A directory that exists but holds no session .jsonl and no subagents/
  # must not drop out of the total silently: the good argument's total
  # must never print at all once a later argument yields nothing.
  local empty out code
  empty=$(tmpdir)
  out=$("$SESSION_USAGE" "$FIXTURES/ses0001.jsonl" "$empty" 2>&1) && code=0 || code=$?
  assert_exit 2 "$code" "an argument with no transcript is refused even when an earlier argument is good"
  assert_contains "$out" "$empty" "the refusal names the argument that yielded nothing"
  assert_not_contains "$out" "TOTAL" "no total is printed once one argument yields no transcript"
}

test_fast_mode_prints_as_check_not_partial() {
  local fixture pricing out
  fixture=$(tmpdir)/fast.jsonl
  printf '{"type":"assistant","message":{"id":"msg_fast","model":"claude-opus-5","role":"assistant","content":[],"stop_reason":"end_turn","usage":{"input_tokens":100,"output_tokens":50,"speed":"fast","cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_contains "$out" "(check: fast mode)" "a turn priced at standard rates but run at usage.speed other than standard prints as check, not partial: nothing is left unpriced"
  assert_contains "$out" "check: fast mode for claude-opus-5" "the total names the model that ran fast"
  assert_not_contains "$out" "partial" "fast mode alone never carries the word partial: nothing here is unpriced"
}

test_us_only_inference_prints_as_check_not_partial() {
  local fixture pricing out
  fixture=$(tmpdir)/geo.jsonl
  printf '{"type":"assistant","message":{"id":"msg_geo","model":"claude-opus-5","role":"assistant","content":[],"stop_reason":"end_turn","usage":{"input_tokens":100,"output_tokens":50,"inference_geo":"us","cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_contains "$out" "(check: US-only inference)" "a turn billed at the 1.1x us surcharge prints as check, since this script does not apply the surcharge but nothing is unpriced"
  assert_contains "$out" "check: US-only inference for claude-opus-5" "the total names the model"
  assert_not_contains "$out" "partial" "US-only inference alone never carries the word partial"
}

test_iterations_disagreeing_with_top_level_usage_prints_as_check_not_partial() {
  # A turn whose top-level usage is all zero while its iterations array
  # carries real tokens. Billing may or may not follow iterations, so the
  # total is marked check rather than trusted at face value either way.
  # Each iteration element carries these five fields directly, the shape
  # real transcripts use: no nested "usage" object inside the element.
  local fixture pricing out
  fixture=$(tmpdir)/iter.jsonl
  printf '{"type":"assistant","message":{"id":"msg_iter","model":"claude-opus-5","role":"assistant","content":[],"stop_reason":"end_turn","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"iterations":[{"type":"message","input_tokens":100,"output_tokens":50,"cache_read_input_tokens":994000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}]}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_contains "$out" "(check: iterations disagree)" "top-level usage of all zero against a non-empty iterations array prints as check"
  assert_contains "$out" "check: iterations disagree for claude-opus-5" "the total names the model"
  assert_not_contains "$out" "0 (partial" "the mismatched turn never prints a bare \$0 with no flag at all"
}

test_iterations_equal_to_top_level_usage_produce_no_flag() {
  # The common real-transcript case: every iteration's five fields sum to
  # exactly the turn's own top-level usage. This must never print as
  # check or partial, since round 4's guessed schema (iterations nested
  # under their own "usage" key, which real transcripts never carry)
  # flagged every one of these as disagreeing.
  local fixture pricing out
  fixture=$(tmpdir)/iter_agree.jsonl
  printf '{"type":"assistant","message":{"id":"msg_iter_agree","model":"claude-opus-5","role":"assistant","content":[],"stop_reason":"end_turn","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"iterations":[{"type":"message","input_tokens":100,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}]}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  pricing=$(pricing_file "$(printf 'claude-opus-5\t4.00\t20.00\t5.00\t5.00\t0.20')")
  out=$(SESSION_USAGE_PRICING="$pricing" "$SESSION_USAGE" "$fixture")
  assert_not_contains "$out" "check" "an iterations array that agrees with the top-level usage is never flagged"
  assert_not_contains "$out" "partial" "an iterations array that agrees with the top-level usage never prints as partial either"
  assert_contains "$out" "$(printf 'claude-opus-5\t100\t50\t0\t0\t0\t0.0014')" "the row prices cleanly with no note at all"
}

test_iterations_element_missing_a_token_field_is_refused_not_summed_as_zero() {
  # A missing field inside an iteration element must refuse and name the
  # field, the same rule that already applies to a missing top-level
  # usage field: it must never fall back to 0 inside the sum.
  local fixture out code
  fixture=$(tmpdir)/iter_missing.jsonl
  printf '{"type":"assistant","message":{"id":"msg_iter_missing","model":"claude-opus-5","role":"assistant","content":[],"stop_reason":"end_turn","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"iterations":[{"type":"message","input_tokens":100,"output_tokens":50,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}]}},"timestamp":"2026-09-21T09:00:00.000Z"}\n' > "$fixture"
  out=$("$SESSION_USAGE" "$fixture" 2>&1) && code=0 || code=$?
  assert_exit 1 "$code" "an iteration element missing cache_read_input_tokens is refused, not summed as zero"
  assert_contains "$out" "message.usage.iterations[].cache_read_input_tokens" "the refusal names the missing field inside the iteration element"
}

run_tests
