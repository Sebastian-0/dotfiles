---
name: review-pr
description: Review the current branch's pull request before merging. Checks diff, CI status, comments, and review state.
---

Review the current branch's PR and identify anything worth considering before merging.

## Steps

1. **Get PR metadata** using `gh pr view` (title, description, base branch, state, URL).

2. **Diff against the base branch**: Run `gh pr diff` to see the full set of changes. Use `--names-only` first for an overview, then the full diff for details.

3. **Thoroughly review the code**: Using the diff from the previous step do a thorough review of the code. Make sure to look for bugs, performance issues, style violations and other pitfalls. Load any files you need for context!

4. **Check CI status** with `gh pr checks`.

5. **Read all comments** — both conversation comments (`gh pr view --comments`) and inline review comments (`gh api repos/{owner}/{repo}/pulls/{number}/comments`). Pay attention to unresolved concerns from human reviewers, not just automated bots.

6. **Check review state** — note who approved, who requested changes, and who commented without a formal review status.

## Output

Provide a concise summary covering:

- **CI status** — passing, failing, or skipped. Flag if failures might be related to the PR.
- **Review status** — who approved (briefly), any outstanding requests for changes.
- **Unresolved comments** — highlight substantive concerns from reviewers that haven't been addressed.
- **Remaining issues** — Major issues and bugs (missing null checks, potential bugs, performance concerns, etc.).
  - When referencing an issue in a specific file, write `file_name:line` to be very clear where the problem is. You can use a range of lines to `l1-l2`.
- **Nitpicks** — Any minor issues you found (style violations, known limitations, possible bugs that are unlikely to materialize)
- **Verdict** — are there any blockers, or is this safe to merge?
  - If any specific comments should be addressed before merging reference them with their number and name

Use $ARGUMENTS if provided to filter focus (e.g., a specific concern area).
