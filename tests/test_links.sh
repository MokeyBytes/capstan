#!/usr/bin/env bash
# For every relative markdown link, reference-style link definition, and
# #anchor under README.md, DESIGN.md, docs/, examples/, skills/, agents/,
# plugins/, bench/, .capstan/ and CLAUDE.md: the target file (or directory)
# exists, and any #anchor matches a heading in that target under an
# ASCII-only slug rule (lowercase, keep a-z0-9_-, spaces to hyphens,
# everything else dropped, duplicates suffixed -1, -2, ...), not GitHub's
# fuller rule. Links inside fenced code blocks are sample text, not real
# links, and are skipped on both sides.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

SCAN_ROOTS=(README.md DESIGN.md docs skills agents examples plugins bench .capstan CLAUDE.md)

# missing_scan_roots ROOT... prints, one per line, any root that does not
# exist under REPO_ROOT. A renamed or deleted root should fail loudly
# rather than scan silently less than it claims to.
missing_scan_roots() {
  local root
  for root in "$@"; do
    [[ -e "$REPO_ROOT/$root" ]] || printf '%s\n' "$root"
  done
}

# heading_slugs FILE prints one GitHub-style anchor slug per line, in
# document order. ATX headings only; a line inside a fenced code block is
# sample content, never a real heading.
heading_slugs() {
  awk '
    /^```/ { infence = !infence; next }
    infence { next }
    /^#{1,6}[ \t]/ {
      line = $0
      sub(/^#{1,6}[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      slug = ""
      n = length(line)
      for (i = 1; i <= n; i++) {
        c = tolower(substr(line, i, 1))
        if (c ~ /[a-z0-9_-]/) slug = slug c
        else if (c == " ") slug = slug "-"
      }
      seen[slug]++
      if (seen[slug] == 1) print slug
      else print slug "-" (seen[slug] - 1)
    }
  ' "$1"
}

# extract_links FILE prints "<line>\t<target>" for every markdown link and
# reference-style link definition outside a fenced code block, in document
# order. Several links on one line each get their own output line.
extract_links() {
  awk '
    /^```/ { infence = !infence; next }
    infence { next }
    {
      line = $0
      while (match(line, /\]\([^)]+\)/)) {
        seg = substr(line, RSTART, RLENGTH)
        target = substr(seg, 3, length(seg) - 3)
        print FNR "\t" target
        line = substr(line, RSTART + RLENGTH)
      }
      if (match($0, /^\[[^]]+\]:[ \t]*[^ \t]+/)) {
        seg = substr($0, RSTART, RLENGTH)
        sub(/^\[[^]]+\]:[ \t]*/, "", seg)
        print FNR "\t" seg
      }
    }
  ' "$1"
}

# check_link ABS_SRC_FILE TARGET prints a one-line reason if TARGET is
# broken from ABS_SRC_FILE, and prints nothing when it resolves.
check_link() {
  local src="$1" target="$2" src_dir file_part anchor_part resolved wanted
  src_dir="$(dirname "$src")"

  case "$target" in
    \#*)
      file_part=""
      anchor_part="${target#\#}"
      ;;
    *)
      file_part="${target%%#*}"
      if [[ "$target" == *"#"* ]]; then
        anchor_part="${target#*#}"
      else
        anchor_part=""
      fi
      ;;
  esac

  if [[ -z "$file_part" ]]; then
    resolved="$src"
  else
    resolved="$src_dir/$file_part"
  fi

  if [[ ! -e "$resolved" ]]; then
    printf 'missing target %s' "$resolved"
    return
  fi

  if [[ -n "$anchor_part" && -f "$resolved" ]]; then
    wanted="$(printf '%s' "$anchor_part" | tr '[:upper:]' '[:lower:]')"
    if ! heading_slugs "$resolved" | grep -qxF "$wanted"; then
      printf 'missing anchor #%s in %s' "$anchor_part" "$resolved"
    fi
  fi
}

test_flags_a_missing_target_file() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n\nSee [it](nope.md).\n' > "$dir/a.md"
  out=$(check_link "$dir/a.md" "nope.md")
  assert_contains "$out" "missing target" "a link to a file that does not exist should be flagged"
}

test_flags_a_missing_anchor() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n' > "$dir/a.md"
  printf '# Real heading\n' > "$dir/b.md"
  out=$(check_link "$dir/a.md" "b.md#nope")
  assert_contains "$out" "missing anchor" "an anchor absent from the target's headings should be flagged"
}

test_accepts_a_working_relative_link_and_anchor() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n' > "$dir/a.md"
  printf '# Real heading\n\nMore text.\n' > "$dir/b.md"
  out=$(check_link "$dir/a.md" "b.md#real-heading")
  assert_eq "" "$out" "a working relative link with a matching anchor should not be flagged"
}

test_accepts_a_same_file_anchor() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n\n## Sub heading\n' > "$dir/a.md"
  out=$(check_link "$dir/a.md" "#sub-heading")
  assert_eq "" "$out" "a same-file anchor should resolve against the file's own headings"
}

test_accepts_a_directory_link_with_no_anchor() {
  local dir out
  dir=$(tmpdir)
  mkdir -p "$dir/sub"
  printf '# Title\n' > "$dir/a.md"
  out=$(check_link "$dir/a.md" "sub/")
  assert_eq "" "$out" "a link to an existing directory should not be flagged"
}

test_duplicate_headings_get_the_github_suffix() {
  local dir out
  dir=$(tmpdir)
  printf '# One\n\n## Setup\n\nMore.\n\n## Setup\n' > "$dir/a.md"
  out=$(heading_slugs "$dir/a.md")
  assert_eq "$(printf 'one\nsetup\nsetup-1')" "$out" "a second identical heading should slug to setup-1, GitHub's own rule"
}

test_a_heading_inside_a_fenced_code_block_is_not_a_real_heading() {
  local dir out fence
  dir=$(tmpdir)
  fence='```'
  printf '# One\n\n%smarkdown\n# Decisions\n%s\n\n## Two\n' "$fence" "$fence" > "$dir/a.md"
  out=$(heading_slugs "$dir/a.md")
  assert_eq "$(printf 'one\ntwo')" "$out" "a heading-shaped line inside a code fence should be skipped"
}

test_a_link_inside_a_fenced_code_block_is_not_checked() {
  local dir out fence
  dir=$(tmpdir)
  fence='```'
  printf '# Title\n\n%smarkdown\nSee [it](nope.md).\n%s\n' "$fence" "$fence" > "$dir/a.md"
  out=$(extract_links "$dir/a.md")
  assert_eq "" "$out" "a link-shaped example inside a code fence should not be extracted"
}

test_extracts_a_reference_style_link_definition() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n\nSee [it][ref].\n\n[ref]: nope.md\n' > "$dir/a.md"
  out=$(extract_links "$dir/a.md")
  assert_contains "$out" "nope.md" "a reference-style link definition should surface its target"
}

test_a_reference_style_definition_inside_a_fenced_code_block_is_not_extracted() {
  local dir out fence
  dir=$(tmpdir)
  fence='```'
  printf '# Title\n\n%smarkdown\n[ref]: nope.md\n%s\n' "$fence" "$fence" > "$dir/a.md"
  out=$(extract_links "$dir/a.md")
  assert_eq "" "$out" "a reference-style definition inside a code fence should not be extracted"
}

test_flags_a_broken_reference_style_link() {
  local dir out
  dir=$(tmpdir)
  printf '# Title\n\nSee [it][ref].\n\n[ref]: nope.md\n' > "$dir/a.md"
  out=$(check_link "$dir/a.md" "nope.md")
  assert_contains "$out" "missing target" "a reference-style link resolving to a missing file should be flagged"
}

test_missing_scan_roots_reports_an_absent_root() {
  local dir out
  dir=$(tmpdir)
  mkdir -p "$dir/docs"
  out=$(REPO_ROOT="$dir" missing_scan_roots docs nope-dir)
  assert_contains "$out" "nope-dir" "an absent scan root should be reported"
  assert_not_contains "$out" "docs" "an existing scan root should not be reported"
}

test_repo_links_all_resolve() {
  local broken="" f target lineno reason abs missing
  missing="$(missing_scan_roots "${SCAN_ROOTS[@]}")"
  if [[ -n "$missing" ]]; then
    fail "missing scan root(s): $(printf '%s' "$missing" | tr '\n' ' ')"
    return
  fi
  while IFS= read -r f; do
    abs="$REPO_ROOT/$f"
    while IFS=$'\t' read -r lineno target; do
      [[ -z "$target" ]] && continue
      case "$target" in
        http://*|https://*|mailto:*) continue ;;
      esac
      reason="$(check_link "$abs" "$target")"
      if [[ -n "$reason" ]]; then
        broken="${broken}${f}:${lineno}: ${reason}"$'\n'
      fi
    done < <(extract_links "$abs")
  done < <(cd "$REPO_ROOT" && find "${SCAN_ROOTS[@]}" -type f -name '*.md' | sort)
  [[ -z "$broken" ]] || fail "$broken"
}

run_tests
