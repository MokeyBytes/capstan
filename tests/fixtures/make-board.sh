#!/usr/bin/env bash
#
# Regenerates every fixture in this folder from one description of a board.
# Run it from anywhere; it writes next to itself. Needs bash and jq.
#
# The board is acme/widgets, project 1, 75 items:
#   1-70   issues carrying a Capstan Status, across four milestones (efforts),
#          with the slice name "docs" under two of them at different statuses
#   71     a PullRequest              (skipped: not an issue)
#   72     a DraftIssue, no number    (skipped: not an issue)
#   73     an issue on other/repo     (skipped: other repository)
#   74     an acme/widgets issue with no Capstan Status (skipped: no status)
#   75     an item whose content is null (skipped: not an issue)
#
# Files written:
#   board-75.json       the board above
#   board-65.json       board-75 with ten of the seventy rows torn down
#   board-invalid.json  two good rows, one with no milestone, one with a
#                       status outside the four
#   board-empty.json    {"items": [], "totalCount": 0}
#   comments/N.json     one conforming merge comment per merged issue; issue 3
#                       also carries a non-conforming one, issue 7 a multi-line
#                       one that merely contains a conforming line
#   comments-bad/       as comments/, but issue 3 carries two conforming
#                       comments and issue 11 none
#   tracker-75.md       the tracker.md that matches board-75 exactly
#   tracker-drift.md    tracker-75.md with effort-b/docs marked merged (board:
#                       building), slice-03's commit changed, slice-37 removed
#                       and slice-99 added

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v jq > /dev/null 2>&1 || { printf 'make-board.sh: jq is required\n' >&2; exit 1; }

OWNER=acme
REPO=widgets
DROP_FOR_65='[2, 3, 9, 19, 23, 30, 41, 50, 60, 70]'

effort_for() {
  if [[ $1 -le 18 ]]; then printf 'effort-a'
  elif [[ $1 -le 36 ]]; then printf 'effort-b'
  elif [[ $1 -le 53 ]]; then printf 'effort-c'
  else printf 'effort-d'
  fi
}

status_for() {
  case $(( $1 % 4 )) in
    1) printf 'planned' ;;
    2) printf 'building' ;;
    3) printf 'merged' ;;
    0) printf 'dropped' ;;
  esac
}

slice_for() {
  case $1 in
    5|22) printf 'docs' ;;
    40) printf 'web ui' ;;
    *) printf 'slice-%02d' "$1" ;;
  esac
}

sha_for() {
  printf '%07x' $(( $1 * 1234567 ))
}

# Non-conforming comment bodies: ordinary discussion that names a commit, and
# a multi-line body that merely contains a conforming line. Backticks literal.
# shellcheck disable=SC2016
ASIDE_BODY='did this merge in `deadbeef`?'
# shellcheck disable=SC2016
MULTILINE_BODY=$'see also\nmerged in `cafe0000`'
# shellcheck disable=SC2016
SECOND_MERGE_BODY='merged in `abcdef1`'

# item TYPE NUMBER TITLE REPO EFFORT STATUS: one project item as compact JSON.
# An empty EFFORT omits the milestone; an empty STATUS omits Capstan Status;
# TYPE "null" makes content null; "DraftIssue" has no number, repo or url.
item() {
  jq -nc --arg type "$1" --arg number "$2" --arg title "$3" --arg repo "$4" \
    --arg effort "$5" --arg status "$6" '
    ($number | tonumber) as $n
    | (if $type == "PullRequest" then "pull" else "issues" end) as $kind
    | { id: ("PVTI_" + $number), title: $title, assignees: [], labels: [] }
    + (if $type == "null" then { content: null }
       elif $type == "DraftIssue" then
         { content: { type: "DraftIssue", title: $title, body: "a note on the board" } }
       else
         { content: { type: $type, title: $title, number: $n, repository: $repo,
                      url: ("https://github.com/" + $repo + "/" + $kind + "/" + $number),
                      body: "Migrated from `tracker.md` at commit 0123abc." },
           repository: ("https://github.com/" + $repo) }
       end)
    + (if $effort != "" then { milestone: { title: $effort, description: "", dueOn: null } } else {} end)
    + (if $status != "" then { "capstan Status": $status } else {} end)
    + (if $status == "merged" or $status == "dropped" then { status: "Done" } else { status: "Todo" } end)
  '
}

board() { # ITEMS-FILE OUT
  jq -s '{ items: ., totalCount: length }' "$1" > "$2"
}

# comment_file NUMBER DIR BODY...: DIR/NUMBER.json holding one {body} per BODY,
# in order. A BODY may contain newlines.
comment_file() {
  local number="$1" dir="$2" body
  shift 2
  : > "$tmp/bodies"
  for body in "$@"; do
    printf '%s' "$body" | jq -R -s '{ body: . }' >> "$tmp/bodies"
  done
  jq -s '.' "$tmp/bodies" > "$dir/$number.json"
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/make-board.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

rm -rf "$here/comments" "$here/comments-bad"
mkdir -p "$here/comments" "$here/comments-bad"
: > "$tmp/items"
: > "$tmp/rows"

i=1
while [[ $i -le 70 ]]; do
  effort="$(effort_for "$i")"
  slice="$(slice_for "$i")"
  status="$(status_for "$i")"
  [[ $i -eq 5 ]] && status=merged
  commit=""
  if [[ "$status" == merged ]]; then
    commit="$(sha_for "$i")"
    case $i in
      3) comment_file "$i" "$here/comments" "$ASIDE_BODY" "merged in \`$commit\`" ;;
      7) comment_file "$i" "$here/comments" "merged in \`$commit\`" "$MULTILINE_BODY" ;;
      *) comment_file "$i" "$here/comments" "merged in \`$commit\`" ;;
    esac
  fi
  item Issue "$i" "$slice" "$OWNER/$REPO" "$effort" "$status" >> "$tmp/items"
  # An empty commit cell is written "| |", the spelling skills/effort/SKILL.md shows.
  cell=" $commit "
  [[ -n "$commit" ]] || cell=" "
  printf '| %s | %s | %s |%s|\n' "$effort" "$slice" "$status" "$cell" >> "$tmp/rows"
  i=$((i + 1))
done

{
  item PullRequest 71 pull-request-71 "$OWNER/$REPO" effort-a merged
  item DraftIssue 72 'scratch note' '' '' planned
  item Issue 73 elsewhere other/repo effort-b building
  item Issue 74 unstatused "$OWNER/$REPO" effort-c ''
  item null 75 redacted '' '' planned
} >> "$tmp/items"
board "$tmp/items" "$here/board-75.json"

jq --argjson drop "$DROP_FOR_65" '
  .items |= map(select(((.content.number // -1) as $n | any($drop[]; . == $n)) | not))
  | .totalCount = (.items | length)
' "$here/board-75.json" > "$here/board-65.json"

{
  item Issue 1 slice-01 "$OWNER/$REPO" effort-a planned
  item Issue 2 slice-02 "$OWNER/$REPO" effort-a building
  item Issue 80 orphan "$OWNER/$REPO" '' building
  item Issue 81 mislabelled "$OWNER/$REPO" effort-a "done"
} > "$tmp/invalid"
board "$tmp/invalid" "$here/board-invalid.json"

printf '{"items": [], "totalCount": 0}\n' > "$here/board-empty.json"

cp "$here/comments/"*.json "$here/comments-bad/"
comment_file 3 "$here/comments-bad" "merged in \`$(sha_for 3)\`" "$SECOND_MERGE_BODY"
printf '[]\n' > "$here/comments-bad/11.json"

{
  printf -- '---\ncapstan_type: tracker\n---\n\n# Tracker\n\n'
  printf '| Effort | Slice | Status | Commit |\n|---|---|---|---|\n'
  cat "$tmp/rows"
} > "$here/tracker-75.md"

sed -e 's/^| effort-b | docs | building | |$/| effort-b | docs | merged | feedface |/' \
    -e "s/^| effort-a | slice-03 | merged | $(sha_for 3) |\$/| effort-a | slice-03 | merged | 0000abc |/" \
    -e '/^| effort-c | slice-37 | /d' \
    "$here/tracker-75.md" > "$here/tracker-drift.md"
printf '| effort-d | slice-99 | planned | |\n' >> "$here/tracker-drift.md"

printf 'wrote fixtures to %s\n' "$here"
