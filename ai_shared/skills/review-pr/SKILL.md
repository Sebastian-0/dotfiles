---
name: review-pr
description: Review the current branch's pull request before merging. Checks diff, CI status, comments, and review state.
---

Review the current branch's PR (or branch/commits in the absence of a PR), and identify anything worth considering before merging.

## Steps (high level)

1. Determine type of review
2. Collect data
3. Perform the review
4. Write your report
5. Review the review
6. Present your report
7. Extra information

NOTE: Some tools we refer to below might not be available on all machines. For instance `gh` might not be installed. If so, fall back to treat it as a non-PR change


### 1. Determine the type of review

First determine if we are reviewing a PR or a branch

1. `gh pr view` => Does there exist a PR for our current working tree?
2. Otherwise => There is no PR, diff against where we branched of from the default branch


### 2. Collect data

Before reviewing we need to collect all the data we will need.

- If we are reviewing a PR, collect:
    1. Code diff `gh pr diff`
    2. PR comments
    3. Status checks `gh pr checks`

- If there is no PR, collect:
    1. Check the default branch with `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
    2. Code diff against `origin/<default-branch>`


### 3. Perform the review

Now we are ready to review. When reviewing we need to be VERY THOROUGH! We should spend a lot of time in this process.

For EACH PART of the diffs verify:
1. Is this change logically correct?
    - Think deeply about the change from different angles.
    - Does the change do what it should?
    - Are all possible inputs/states correctly handled?
2. Could the change be simplified?
    - Is there an api we can call instead of implementing this change?
    - Is the code unnecessarily complex and could be simplified?
3. Are there code quality issues?
    - Look for unused code/imports
    - Is naming/style following conventions?
    - Is there duplicated code?
4. Is it performant enough?
    - Verify if performance is important in this part of the code, and if so, is the change performant enough?
5. Is there any collateral damage?
    - Are there unintended side effects?
    - Will the change cause problems for code *not in the diffs* (not updated)?
6. Are other supporting changes needed, and if so, have they been made?
    - Changes to docs?
    - Updates in calling code?
    - Do we need to update CI/CD or tests?

Next, for each of the PR comments (if available) consider:
1. Is the comment correct?
2. Has the comment beed addressed?
3. If not addressed, is it important to address?


Check the PR status checks (if available) and make sure CI is building.

Check who approved or didn't approve of the PR (if available).

Check that the PR has a good title and a description.


### 4. Write the report

Write a concise report with the following contents:
1. Very brief summary of the changes
2. Status of PR approvals (if available)
3. Brief list of what looks good
4. Brief list of issues we need to fix
5. Bried list of nitpicks (minor) problems
6. Verdict, whether we can merge or not.

For the lists we mention above, always start each list item with a header, followed by the names of relevant source code files and line numbers, followed by a detailed explanation.


### 5. Review your review

We want to make sure the review is good before presenting to the user.

1. Write your review to a temporary file
2. Check if the review matches the code changes
    - Check line by line
    - Is anything missing in the review?
3. If something is missing, update the review and go back to step 1
4. If the review is good, go to the next section


### 6. Present your report

Finally present your report to the user.


### 7. Extra
Use $ARGUMENTS if provided to filter focus (e.g., a specific concern area).
