---
name: post-pr-review
description: Publish a review to an existing GitHub PR — the summary body, inline comments with suggested fixes, and the Approve/Request-changes/Comment verdict — after getting the user's sign-off. Use when asked to post/submit/leave a review on a PR, approve a PR, request changes, or post findings as PR comments. NOT for reviewing code locally (that is review-pr / code-review); this skill only covers writing to GitHub.
---

Publish a review to a PR on GitHub, under the user's account, with their explicit sign-off.

## Scope — read this first

This skill is about **writing to GitHub**. "Review this PR" on its own means a *local* review: use `code-review` (or `review-pr`) and report in the terminal. Only invoke this skill when something is to be posted — "post a review", "approve it", "leave that as a comment on the PR", "request changes".

The two chain naturally: review locally, present the findings, and when the user says "post that", come here. Do not carry the local report over verbatim — it was written for the terminal, and a PR review is a different, far shorter artifact. Nothing that reads as an essay belongs on GitHub.

## Core principle: the user's name is on it

Everything posted goes out under the user's account to colleagues whose time they respect highly. A bloated or incorrect review costs those people directly. So **verify every finding before it goes out** (run the repro, read the file, check the pinned version) and **never submit without sign-off**.

## Steps

### 1. Collect the state of the PR

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=<number>   # or: gh pr view --json number -q .number

gh pr view "$PR" --json author,title,baseRefName,reviewRequests,reviews,isDraft,mergeable
gh api "repos/$OWNER_REPO/pulls/$PR/comments?per_page=100" \
  --jq '.[] | {id, path, line, start_line, body, in_reply_to: .in_reply_to_id, user: .user.login}'
```

Thread resolution state, which the REST comments endpoint does not carry:

```bash
gh api graphql -f query='
{ repository(owner:"OWNER",name:"REPO"){ pullRequest(number:PR){
  reviewThreads(first:50){nodes{id isResolved isOutdated line
    comments(first:1){nodes{databaseId author{login} body}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | {id, isResolved, isOutdated, line, first: .comments.nodes[0].databaseId,
           author: .comments.nodes[0].author.login}'
```

**Read the existing threads before writing anything.** If a finding is already covered by someone else's comment — including Copilot's — reply on that thread rather than opening a competing one. Bot reviews are mostly noise, so confirming *which* comment is the real one is itself useful to the author.

### 2. Draft

Draft to a scratchpad file, not to GitHub.

- **Summary body**: brief. "LGTM", "LGTM, one thing to fix first", or similar. It is not where findings go — reviewers do not look there for actions. **No `Claude:` prefix on the summary body**; it is the one GitHub exception.
- **Each finding**: an inline comment on the exact line, prefixed `Claude: `, a sentence or two, carrying a ` ```suggestion ` block so the author can click-apply it. Include the evidence that settles it (repro output, the command run) and nothing more — no restating the diagnosis, no rationale essay.
- **Must-fix items have to end up as unresolved inline threads.** An approval whose only blocking note sits in the summary body lets the fix slip through; unresolved conversations are what gate the merge.

A suggestion block replaces the comment's whole anchor range (`start_line`..`line`), so it must contain **every** line of that range at the original indentation. One mechanical fix in three places is one comment plus "same swap on lines N and M" — not three threads.

### 3. Get sign-off — mandatory

Present in the terminal, then stop:

1. The exact summary-comment text.
2. Every inline comment: file, line, text, and the suggestion.
3. The intended verdict: **Approve / Request changes / Comment**.

Ask for input on the summary content, on the verdict, and on whether the review as a whole is good and correct. Use `AskUserQuestion` for the verdict when it is genuinely open — approving while asking for a fix, versus blocking the merge, is the user's call and not a default. Wait for the answer; post no part of the review early.

### 4. Post

One review carrying its inline comments, so the author gets a single notification:

```bash
cat > "$TMPDIR/review.json" <<'EOF'
{
  "event": "APPROVE",
  "body": "LGTM, one thing to fix first.",
  "comments": [
    {"path": "path/to/file.py", "line": 334, "start_line": 330, "side": "RIGHT",
     "body": "Claude: <finding>\n\n```suggestion\n<replacement for lines 330-334>\n```"}
  ]
}
EOF
gh api "repos/$OWNER_REPO/pulls/$PR/reviews" --method POST --input "$TMPDIR/review.json"
```

`event` is `APPROVE`, `REQUEST_CHANGES` or `COMMENT`. Replying on an existing thread is a separate call:

```bash
jq -Rs '{body: .}' "$TMPDIR/reply.md" > "$TMPDIR/reply.json"   # sidesteps every shell quoting trap
gh api "repos/$OWNER_REPO/pulls/$PR/comments/<comment_id>/replies" \
  --method POST --input "$TMPDIR/reply.json"
```

Corrections, if wording needs changing after it lands:

```bash
gh api "repos/$OWNER_REPO/pulls/$PR/reviews"                         # numeric review id
gh api "repos/$OWNER_REPO/pulls/$PR/reviews/<review_id>" --method PUT -f body='...'
gh api "repos/$OWNER_REPO/pulls/comments/<comment_id>" --method PATCH --input "$TMPDIR/reply.json"
```

The edit path for a comment takes no PR number. A submitted verdict cannot be edited, only superseded by a new review.

### 5. Verify and report

```bash
gh pr view "$PR" --json reviews --jq '.reviews[-1] | {author: .author.login, state}'
```

Re-run the `reviewThreads` query and confirm each blocking thread is `isResolved: false`. Report the verdict, the thread URLs, and which threads gate the merge.
