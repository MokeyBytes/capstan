---
name: tracker
description: Read or write Capstan's slice tracker on a GitHub Projects v2 board, when a project's capstan-tracker key names one.
---

# Tracker: GitHub surface

The helpers this skill runs live in `bin/` beside this file. Resolve that folder to an absolute path from wherever this skill was loaded — `${CLAUDE_PLUGIN_ROOT}/skills/tracker/bin` under a plugin install, `bin/` beside this file under a manual one — and call it `<bin>` below. This plugin cannot read core's files, so it never resolves `<bin>` against `capstan`'s own `bin/`.

Under an effort, where core's `effort` skill is already loaded, the visibility gate that decides whether a write needs the operator's confirmation lives in the Authority table there, and only there. Read it before writing anything to this surface. A caller outside an effort — this plugin's own `setup` skill among them, which cannot load that skill — states its own approval rule inline instead of pointing here.

## The column mapping

`tracker.md` has four columns. Each maps onto a GitHub primitive built for that job, never onto a shape borrowed from elsewhere:

| Tracker column | GitHub primitive |
|---|---|
| Slice | An issue, titled with the slice's name — the only place that name lives on this surface |
| Effort | A milestone, grouping the issues that belong to it |
| Status | A **custom** single-select field on the Projects v2 board, named `Capstan Status` — never the built-in `Status` field |
| Commit | Posted as a comment on the issue once the slice merges |

A slice becomes an issue rather than a bare project item because only an issue can be closed by a pull request or linked from a commit, which is most of the reason to run this surface at all.

## The write path

Do these in order. Steps 1 and 2 happen once each — per board, per effort — and are already done for every slice after the first one. Steps 3 through 6 happen once per slice, and step 5 repeats every time that slice's status changes; step 6's merge-commit comment can be revisited afterward too, per the declaration below.

1. **The field, once per board.** Check whether `Capstan Status` already exists before creating it — a second `field-create` is not obviously a no-op:

   ```
   gh project field-list <project-number> --owner <owner>
   ```

   If `Capstan Status` is not in the list, whoever is making this board's first status write creates it, with the same four options `tracker.md` always used: `planned`, `building`, `merged`, `dropped`. Nothing else ever creates it — `setup` never touches the field, and there is no per-effort or per-slice variant:

   ```
   gh project field-create <project-number> --owner <owner> --name "Capstan Status" \
     --data-type SINGLE_SELECT --single-select-options "planned,building,merged,dropped"
   ```

2. **The milestone, once per effort.** `gh` has no `milestone` command at all. Check the effort already has one before creating it:

   ```
   gh api repos/<owner>/<repo>/milestones -q '.[].title'
   ```

   If `<effort>` is not in the list:

   ```
   gh api repos/<owner>/<repo>/milestones -f title="<effort>" -X POST
   ```

3. **The issue, once per slice.** `gh issue create -m <name>` needs the milestone from step 2 to already exist:

   ```
   gh issue create -R <owner>/<repo> --title "<slice>" --body "<what this slice does>" --milestone "<effort>"
   ```

4. **Add the issue to the board.** An issue carrying a milestone is not yet a project item — it becomes one only here. Skip this and step 5 has nothing to edit:

   ```
   gh project item-add <project-number> --owner <owner> --url <issue-url>
   ```

5. **Set the status**, by name, every time the slice moves: `planned` to `building` to `merged`, or to `dropped`. `gh project item-edit` resolves both the field and the option from what you pass it, which is the form `gh` itself documents as the usual one:

   ```
   gh project item-edit <project-number> --owner <owner> \
     --url <issue-url> --field "Capstan Status" --value "<status>"
   ```

6. **Close the issue.** This surface closes it explicitly, in both terminal cases — the write path never relies on a pull request or on GitHub's own automation to do it.

   For a `merged` slice, first post the merge commit as a comment, in the format declared below, then close with reason `completed`:

   ```
   gh issue comment <issue-url> --body "merged in \`<commit-sha>\`"
   gh issue close <issue-url> --reason completed
   ```

   If a later fix dispatch changes which commit merged the slice's final state, correcting the row is an edit of that comment, never a second one posted alongside it — the declaration below says why. Either of these edits it in place, both verified against a live comment:

   ```
   gh issue comment <issue-url> --edit-last --body "merged in \`<commit-sha>\`"
   gh api -X PATCH repos/<owner>/<repo>/issues/comments/<comment-id> -f body="merged in \`<commit-sha>\`"
   ```

   `--edit-last` edits the authenticated user's own most recent comment on the issue — correct as long as nothing else posts under that same identity after the merge comment. The `PATCH` form edits by comment ID instead, so it works regardless of who posted it or what else was said afterward; reach for it once a run has already located the single conforming comment by ID while reading the issue back.

   For a `dropped` slice there is no merge commit, and no pull request to close the issue either, so close it directly with reason `not planned`:

   ```
   gh issue close <issue-url> --reason "not planned"
   ```

## The merge-commit comment format

The comment step 6 posts on a `merged` row's issue is a contract, not just an example: this is the one declaration of it, and every direction that writes or reads it points here rather than restating it. A conforming comment's body is exactly

```
merged in `<commit-sha>`
```

equivalently, the whole body matches

```
^merged in `[0-9a-f]{4,40}`$
```

where `<commit-sha>` is the commit's SHA in lowercase hexadecimal, abbreviated or full. Nothing precedes or follows it, and the SHA sits inside the single pair of backticks shown.

A `dropped` row never carries this comment — step 6 closes it directly, naming no commit. The `Capstan Status` field is what decides a row's status, never the presence or absence of a comment, so this runs one way only: on a row that is already `dropped`, no merge-commit comment is expected, and its absence there is not a gap to fill in.

A `merged` row's issue carries exactly one conforming comment: two would read back no differently than one that changed its mind, and nothing on this surface could say which is current.

An issue can otherwise carry any number of comments that do not match the pattern above — a question, a status update, a remark from anyone with access to the repository. Those are ordinary discussion, not a gap or a corruption, and none of them stops the run on its own. When a `merged` row's issue carries exactly one conforming comment, any non-conforming comment on that issue is reported alongside the commit that was read, so an operator sees that something else on the issue named a commit and can judge it. What stops the run is a count: a `merged` row whose issue carries zero conforming comments, or more than one, has no single commit to read, and reports what it found rather than guessing at what was meant. That count only holds for a per-issue read that itself succeeded — see **Unreachable stops the run** below for what tells a genuine zero apart from a masked failure.

## The teardown comment format

A reverse migration closes every torn-down issue with a second, different comment, regardless of the status the row carried. This is the one declaration of that format too; the reverse migration points here rather than restating it. A conforming teardown comment's body is exactly

```
returned to `tracker.md` at `<commit-sha>`
```

equivalently, the whole body matches

```
^returned to `tracker\.md` at `[0-9a-f]{4,40}`$
```

where `<commit-sha>` is, in lowercase hexadecimal, abbreviated or full, the commit at which `tracker.md` was reconstructed — never the commit the row itself merged at, which a `merged` row's separate merge-commit comment already names and keeps.

This cannot be mistaken for the merge-commit format above, on two independent grounds. The formats open on different literal words, `returned` against `merged`, so no single body can satisfy both regexes. And the merge-commit format wraps one value in backticks, the SHA; this one wraps two, the literal `` `tracker.md` `` and the SHA. Either ground alone rules out a shared match.

A teardown comment is never a conforming comment: that term names only a match against the merge-commit format above, and this format's regex cannot match it. Posting a teardown comment on a `merged` row's issue does not give that issue a second conforming comment and does not trip the count that stops the run — the row still carries exactly one, the merge-commit comment already there, unchanged.

## Reading the tracker back

Read the board through the helper, never through a bare `gh project item-list`:

```
<bin>/capstan-tracker read --owner <owner> --repo <repo> --project <project-number> [--with-commits]
```

It prints one tab-separated row per slice — `effort`, `slice`, `status`, `commit`, `issue`, `url`, `note` — under a header line, a summary on stderr, and it exits 0 only for a read it can prove complete. `gh project item-list` returns 30 items unless told otherwise and paginates only up to the limit it is given, so the helper reads with an explicit limit, compares what came back against the `totalCount` the same response carries, and reads again with that count when the two differ. A row belongs to this tracker only when it is an issue in `<owner>/<repo>` carrying a `Capstan Status`; everything else on the board is counted in the summary and left out.

| Exit | Means |
|---|---|
| 0 | Complete. Zero rows with exit 0 is a genuine empty board, told apart from the two below. |
| 1 | Unreachable: a `gh` call exited non-zero, the per-issue comment reads included. No rows are printed. |
| 2 | Incomplete: the board reports more items than three reads returned. No rows are printed. |
| 3 | A row that cannot be read: a status outside the four, a missing milestone, or, with `--with-commits`, a `merged` row whose issue carries zero or more than one conforming comment. No rows are printed. |

`--with-commits` reads every `merged` row's issue comments, all pages, and fills `commit` from its one conforming comment; other comments on that issue are counted into `note` as `other-comments=<n>`, which is what "reported alongside the commit" above means in practice. A read of the full tracker is therefore 1+N calls against the board, N the number of merged slices, not the one file-read `tracker.md` gives an agent that already has it open. This surface is worth it for the visibility it gives people without a clone; it is not a drop-in replacement for the offline, single-read table underneath it.

Underneath, the helper runs `gh project item-list <project-number> --owner <owner> --format json --limit <n>` with a `--jq` projection. `--format json` is what puts the milestone and the custom field on the item at all, and in that JSON the field is keyed `capstan Status`, not `Capstan Status`: GitHub lowercases only the first word of a custom field's name when it renders it, leaving the option values untouched. Querying the display name exits zero and returns nothing against a field that is set, which is the trap the helper exists to keep out of an agent's hands.

`diff` compares the board against a `tracker.md`, keyed by effort **and** slice, never slice alone: two efforts can each have a `docs`. It exits 0 only when both hold the same keys with the same status, and the same commit on `merged` rows, and otherwise prints every difference — `status-changed`, `commit-changed`, `board-only`, `file-only` — and exits 4. this plugin's own `setup` skill runs it before either migration leg deletes or tears anything down.

## Why never the built-in `Status`

GitHub ships every Projects v2 board with a built-in `Status` field, defaulting to Todo / In Progress / Done. Do not write Capstan's statuses there. Create a separate custom single-select and write to that instead.

Closing an issue fires GitHub's own Projects workflow, and that workflow sets the built-in `Status` to `Done` on its own, overwriting whatever Capstan last wrote. `merged` and `dropped` both close the issue, so the built-in field collapses them into the same value — exactly the distinction a tracker exists to hold. A custom field carries all four of Capstan's statuses and survives closure untouched, because nothing but Capstan ever writes to it.

There is no repair path either. `gh` has no `project field-edit`, so the built-in field's options cannot be renamed or repurposed from the CLI. The custom field is the only way in.

## Unreachable stops the run

GitHub unreachable stops the run and says so. No retry, no backoff, no bounded wait. A rate limit and an expired token are the same case: the run ends rather than slows down. This is the same rule an unreachable document home already gets — a missing source of truth is not ambiguity to work around, it is a reason to stop.

The discriminator is the exit status, never the message, and it reaches every read against this surface. Through the helper that is one code to read: exit 1 is unreachable, whichever of its calls failed, the per-issue comment reads included, which fire once per merged row and are easy to undercount by hand. Exit 2, incomplete, stops the run the same way: a partial read is neither empty nor unreachable, and treating it as either drops rows while reporting success.

A nonzero exit from a write, or from any `gh` call made outside the helper, is unreachable, with one exception: this plugin's own `setup` skill's scope-probe branch already names the missing-`project`-scope failure and walks the operator through the grant rather than stopping here. Every other nonzero exit, at that probe and everywhere else on this surface, is unreachable.

A zero exit from the helper is a genuine empty result, not a failure: it has already proved the read complete and queried the field under the key the JSON actually carries. "Returns nothing" means no rows from it, which is already narrowed to rows whose value came back set.

Exhausting the rate limit made `gh project item-list` print `unknown owner type`. It looked like a different failure, and was in fact this one, the unreachable case.
