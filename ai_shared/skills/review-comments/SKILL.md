---
name: review-comments
description: Read review comments on a PR — from Copilot or from human reviewers — verify each claim against the code, fix what's real, file what belongs in a task, and reply to every thread. Use when asked to address review feedback, handle review comments, answer a reviewer, check/handle Copilot comments, or "what did the reviewer say".
---

Work through the review comments on a PR: judge each on the merits, act on it, and answer every thread.

## Calibrate to the reviewer

The bar for verifying a claim is the same whoever made it. What differs is the failure mode you are guarding against.

### Bot reviewers (Copilot)

Comments are **unverified guesses** — a hypothesis to test against the code, not a defect report. Typically a minority are real. Common failure modes:

- **Hedged FUD** — "may not work", "may be unsupported on older versions", "could be a problem". Check the actual toolchain / version / config before acting. Usually the concern doesn't apply.
- **Actively wrong suggestions** — advice that looks idiomatic but breaks under the file's real scoping or resolution rules. Applying it verbatim can break the build.
- **Self-contradiction across rounds** — it posts a wrong suggestion, then silently posts a corrected one in a later round without withdrawing the first.
- **No-op churn** — proposing a "more consistent" form that is exactly equivalent to what is already there.
- **Cargo-culted consistency** — asserting a convention exists ("the rest of the repo does X") when it doesn't. Grep and confirm before believing it.

Never apply a suggestion just because it is plausible. If a command can settle it — a build, a query, a grep, reading the pinned version — run it.

### Human reviewers

A human comment usually rests on context that isn't in the diff: a convention, a past incident, where the code is headed. The failure mode is not FUD, it is answering the literal words and missing the point.

Verify the claim the same way — being right matters more than being agreeable — but where a bot's wrong comment gets rejected with evidence, a human's gets a question. Say what you found and ask.

Human feedback also lands outside the inline list: review summary bodies and plain PR comments. Collect those too.

## The four outcomes

Every comment ends in exactly one of these:

1. **Fix it** — a real problem, in scope for this PR.
2. **Reject it** — with the evidence that settles it.
3. **File it** — real, but not this PR's job. Create the task, link it in the reply, say it isn't happening here.
4. **Ask** — it needs a decision that is the user's: scope, a design direction, agreeing to rework. Bring it back before replying.

Outcomes 3 and 4 are the ones that get missed. A reviewer raising a design concern usually wants it tracked, not patched into the current PR.

## Steps

### 1. Fetch the comments

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=$(gh pr view --json number -q .number)

# inline review comments
gh api "repos/$OWNER_REPO/pulls/$PR/comments?per_page=100" \
  --jq '.[] | {id, user: .user.login, path, line, body, in_reply_to: .in_reply_to_id}'

# review summary bodies
gh api "repos/$OWNER_REPO/pulls/$PR/reviews?per_page=100" \
  --jq '.[] | select(.body != "") | {user: .user.login, state, body}'

# plain PR comments
gh pr view "$PR" --json comments
```

Skip threads whose last reply is already yours (they open with `Claude:`) unless something new has been said under them.

### 2. Cluster before judging

Bots re-review and post the same issue repeatedly; humans repeat themselves across files. Cluster by `path` + `line`, and by claim. Judge each *issue* once; you still reply to every *thread* (step 5).

### 3. Verify each claim against the code

Read the file and whatever the claim depends on: the pinned version, the other call sites, the convention it says exists. Where a claim is empirically testable, test it — a build, a config/dependency query, or a targeted grep beats an opinion. Record the evidence; you will cite it in the reply.

### 4. Act — one commit per fix

Only fix genuine problems.

- **Worth fixing:** anything factually wrong, especially comments or docs that misstate a **pinned version or a value defined elsewhere** — those mislead during upgrades.
- **Not worth fixing:** equivalent-form style churn.

When a stale fact duplicates a value defined elsewhere, prefer **removing the duplication** over correcting it — pointing at the single source of truth stops the same drift recurring.

Make each fix a **separate, standalone commit** so it can be amended/squashed into the right place later:

```bash
git commit -m "fix: <what>"
```

Note which existing commit each fixup belongs to and report that. Follow the repo's commit-message conventions.

For outcome 3, file the task before replying so the reply can carry the link.

### 5. Reply to every thread

```bash
gh api "repos/$OWNER_REPO/pulls/$PR/comments/<comment_id>/replies" -f body="Claude: ..."
```

The `Claude:` prefix and terseness are the global GitHub writing rules — they apply to every reply here.

Replying on threads is not the same act as submitting a review; if the task turns into posting a review (approve / request changes / a summary body), stop and use the `post-pr-review` skill instead.

- **Fixed** — what the fix was and which commit it will be squashed into. Don't cite a bare SHA that a later rebase will invalidate; name the target commit instead.
- **Rejected** — the reasoning *and the evidence*: the command you ran, the version you checked. If the suggestion would have broken something, say so plainly.
- **Filed** — link the task and state in one line what it covers.
- **Duplicates** — full reasoning once on the first thread of a cluster, then a short pointer on the rest. Every thread gets an answer; don't paste the same wall of text many times.

Posting on a human's thread commits the account owner to a position. Factual replies ("fixed in X", "filed as Y") go straight out; agreeing to rework, pushing back on a reviewer's judgment, or anything scope-shaped gets confirmed with the user first.

### 6. Don't push unless asked

Leave the fixup commits local by default and report what is ready for the user to amend or squash.

## Reporting

Lead with the verdict: how many comments, how many were real. Then per issue: what it claimed, what you found, what you did. Explicitly call out any suggestion that would have **broken** the build — that is the most useful signal for how much to trust the bot next time — plus anything you filed and anything still waiting on a decision.
