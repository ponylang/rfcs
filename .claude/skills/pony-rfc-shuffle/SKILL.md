---
name: pony-rfc-shuffle
description: Shuffle a freshly-merged RFC into its final numbered location. Load when an RFC PR has just been merged and the file still lives under text/0000-*.md (or has been numbered but is missing its tracking URLs). Creates the ponyc tracking issue, renames the file, fills in RFC PR and Pony Issue lines, commits to main, and posts an acceptance note on the open Last Week in Pony issue.
disable-model-invocation: false
---

# Shuffle an Accepted RFC Into Place

When an RFC PR is merged, four things still have to happen before it is fully "in place":

1. The file is assigned its final RFC number and renamed from `text/0000-<slug>.md` to `text/NNNN-<slug>.md`.
2. A tracking issue is opened on `ponylang/ponyc` so the implementation has a home in the compiler repo.
3. The RFC's header lines (`RFC PR:` and `Pony Issue:`) are filled in with the real URLs and committed.
4. An acceptance note is posted as a comment on the open "Last Week in Pony" issue on `ponylang/ponylang-website` so the next LWIP newsletter announces it.

The first three are done in a single commit directly on `main`. That direct-to-main flow matches every prior shuffle/bookkeeping commit in the repo — confirm with the user each time rather than treating it as silent default.

## Inputs

The user invokes the skill after merging an RFC PR. The skill needs to determine:

- **Source file** — the RFC markdown file that was just merged. Almost always `text/0000-<slug>.md`. If exactly one `text/0000-*.md` file exists, use it. If zero or more than one, ask the user which file.
- **Next RFC number** — `max(NNNN) + 1` over existing `text/NNNN-*.md` files. Compute this; do not ask.
- **RFC PR URL and title** — the merged PR for this RFC. Auto-detect with `gh pr list --state merged --limit 5 --json number,title,mergedAt,files` and pick the most recent one whose `files` includes the source file. The PR's `title` is the human-readable feature title (e.g., "Add --shuffle option to PonyTest") used for the tracking-issue title and the LWIP comment. The PR's `number` builds the URL `https://github.com/ponylang/rfcs/pull/<number>`. Show the candidate to the user and confirm before using it. If detection is ambiguous, ask.
- **Commit slug** — a short kebab-case version of the feature for the commit message, derived from the file's slug (e.g., `0082-shuffle-test-ordering.md` → `shuffle test ordering`). Pull a few words; full PR titles read poorly in `git log --oneline`.
- **Summary** — the contents of the `# Summary` section in the RFC file, verbatim. Used as the body of the tracking issue.

Every RFC has a `# Summary` section by template. If it is missing or empty, stop and tell the user — that is a bug in the RFC, not something to paper over.

## Workflow

Run these steps in order. Show the user what you are about to do at each user-visible step (issue creation, commit) and wait for confirmation.

### 1. Verify repo state

- Confirm the working directory is the `ponylang/rfcs` repo.
- Confirm the current branch is `main` and the working tree is clean.
- `git pull --rebase --no-gpg-sign` so the merged PR is present locally.

If any of these fail, stop and report.

### 2. Gather the inputs

Determine source file, next RFC number, merged PR (URL + title), commit slug, and summary (see Inputs above). Show the user a one-block summary:

```
Source:       text/0000-shuffle-test-ordering.md
New number:   0082
New filename: text/0082-shuffle-test-ordering.md
RFC PR:       https://github.com/ponylang/rfcs/pull/224
Title:        Add --shuffle option to PonyTest
```

Wait for confirmation before proceeding.

### 3. Open the ponyc tracking issue

Compose the issue:

- **Title**: `RFC #NN: <merged PR title>` — e.g., `RFC #82: Add --shuffle option to PonyTest`.
- **Body**: the RFC's `# Summary` section verbatim, followed by a blank line and the final RFC URL: `https://github.com/ponylang/rfcs/blob/main/text/NNNN-<slug>.md`. The link will not resolve until the rename commit is pushed; that is fine — GitHub does not validate.
- **Assignee**: the invoking user, via `--assignee @me`.

Show the composed title, body, and assignee. Wait for confirmation.

Create with `gh issue create --repo ponylang/ponyc --assignee @me --title "<title>" --body "<body>"`. Capture the new issue URL from the command output.

### 4. Rename and update the file

- `git mv text/0000-<slug>.md text/NNNN-<slug>.md`. If the file is already numbered correctly, skip the rename.
- Edit the metadata block. Anchor on the line prefix, not on placeholder text — past RFCs have used `(leave this empty)`, blank, or other placeholders.

  Replace the entire `- RFC PR:` line (whatever follows the colon) with:

  ```
  - RFC PR: <merged PR URL>
  ```

  Replace the entire `- Pony Issue:` line (whatever follows the colon) with:

  ```
  - Pony Issue: <ponyc tracking issue URL>
  ```

  If a line is already correctly populated (e.g., `RFC PR:` was filled in before merge), leave it alone. "Correctly populated" means the value matches the URL we are about to write; anything else — including a different URL or any placeholder text — gets replaced.

- Stage the metadata edit: `git add text/NNNN-<slug>.md`. The `git mv` already staged the rename; the `Edit` did not stage the metadata change.

### 5. Commit

Show `git status` and `git diff --staged` to the user. Confirm the diff includes both the rename and the metadata changes before committing — if the staged diff only shows the rename, step 4's `git add` was missed.

Commit message: `RFC NN <commit-slug>` (e.g., `RFC 82 shuffle test ordering`, `RFC 81 json-ng`). No body. Use `git commit --no-gpg-sign` per machine convention.

### 6. Push to main

Show the user the commit that is about to be pushed (`git log -1 --oneline`) and the target (`origin/main`). Wait for confirmation.

Push with `git push origin main`. Do not use `--force` or any variant — this is a normal append to main. If the push is rejected because main has moved, stop and report; do not pull-rebase silently.

### 7. Post the LWIP acceptance note

Find the open Last Week in Pony issue:

```
gh issue list --repo ponylang/ponylang-website --label last-week-in-pony --state open --json number,title
```

There is always exactly one open. If the count is anything other than one, stop and tell the user — that is a maintenance problem upstream, not something the skill should guess around.

Compose a one-line comment:

```
RFC accepted: [<merged PR title>](<merged RFC PR URL>)
```

Show the comment text and the target issue number to the user. Wait for confirmation. Post with `gh issue comment <number> --repo ponylang/ponylang-website --body "<text>"`.

### 8. Report

Tell the user the shuffle is done. One sentence is enough.

## Things to watch for

- **More than one `text/0000-*.md` file**: ambiguous. Ask which RFC is being shuffled.
- **`RFC PR:` already filled in**: the prior maintainer numbered the file and filled the PR URL during review. Skip the rename and the `RFC PR:` edit; only add the `Pony Issue:` line. The commit message still uses `RFC NN <commit-slug>`.
- **No tracking issue desired (rare)**: if the user explicitly says no ponyc issue, leave the `Pony Issue:` line as `(leave this empty)` and proceed with rename + RFC PR URL only. Do not invent a placeholder URL.
- **Summary section is empty or missing**: stop. Report it. The RFC needs to be fixed in a separate PR before shuffling.
- **No open LWIP issue, or more than one**: stop before posting the comment. There should always be exactly one open issue with the `last-week-in-pony` label; anything else is a maintenance problem on the website repo.

## Why direct-to-main

Every prior shuffle/bookkeeping commit in this repo's history (RFC 47 through RFC 82) was made directly on `main`. This is the established convention for this specific maintenance task. The skill follows it, but each invocation should still confirm with the user — the global "always work on a branch" rule is being deliberately overridden, not forgotten.
