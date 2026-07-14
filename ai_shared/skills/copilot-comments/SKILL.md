---
name: copilot-comments
description: Read GitHub Copilot's automated review comments on a PR, verify each claim against the code, fix the ones that are real, reject the ones that aren't, and reply to every thread. Use when asked to check/handle/address Copilot comments, Copilot review feedback, or "what did Copilot say".
---

Work through Copilot's review comments on a PR: judge each on the merits, fix what deserves fixing, and answer every thread.

## Core principle: verify, don't trust

Copilot's comments are **unverified guesses**. Treat each as a hypothesis to test against the code, not a defect report. Typically a minority are real. Common failure modes:

- **Hedged FUD** — "may not work", "may be unsupported on older versions", "could be a problem". Check the actual toolchain / version / config before acting. Usually the concern doesn't apply.
- **Actively wrong suggestions** — advice that looks idiomatic but breaks under the file's real scoping or resolution rules. Applying it verbatim can break the build.
- **Self-contradiction across rounds** — it posts a wrong suggestion, then silently posts a corrected one in a later round without withdrawing the first.
- **No-op churn** — proposing a "more consistent" form that is exactly equivalent to what is already there.
- **Cargo-culted consistency** — asserting a convention exists ("the rest of the repo does X") when it doesn't. Grep and confirm before believing it.

Never apply a suggestion just because it is plausible. If a command can settle it — a build, a query, a grep, reading the pinned version — run it.

## Steps

### 1. Fetch the comments

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR=$(gh pr view --json number -q .number)

gh api "repos/$OWNER_REPO/pulls/$PR/comments?per_page=100" \
  --jq '.[] | select(.user.login|test("[Cc]opilot")) | {id, path, line, body, in_reply_to: .in_reply_to_id}'
```

### 2. Deduplicate

**Copilot re-reviews and posts the same issue repeatedly.** Cluster by `path` + `line` before judging — a long list of raw comments is often only two or three distinct issues. Judge each *issue* once; you still reply to every *thread* (step 5).

### 3. Verify each claim against the code

Read the file and whatever the claim depends on: the pinned version, the other call sites, the convention it says exists. Where a claim is empirically testable, test it — a build, a config/dependency query, or a targeted grep beats an opinion. Record the evidence; you will cite it in the reply.

### 4. Fix what's real — one commit per issue

Only fix genuine problems.

- **Worth fixing:** anything factually wrong, especially comments or docs that misstate a **pinned version or a value defined elsewhere** — those mislead during upgrades.
- **Not worth fixing:** equivalent-form style churn.

When a stale fact duplicates a value defined elsewhere, prefer **removing the duplication** over correcting it — pointing at the single source of truth stops the same drift recurring.

Make each fix a **separate, standalone commit** so it can be amended/squashed into the right place later:

```bash
git commit -m "fix: <what>"
```

Note which existing commit each fixup belongs to and report that. Follow the repo's commit-message conventions.

### 5. Reply to every thread

Reply to each thread, **prefixing every reply with `Claude:`** so the human author stays distinguishable from the agent.

```bash
gh api "repos/$OWNER_REPO/pulls/$PR/comments/<comment_id>/replies" -f body="Claude: ..."
```

- **Accepted** — say it is fixed, what the fix was, and which commit it will be squashed into. Don't cite a bare SHA that a later rebase will invalidate; name the target commit instead.
- **Rejected** — give the reasoning *and the evidence* (the command you ran, the version you checked). If the suggestion was wrong, or would have broken something, say so plainly.
- **Duplicates** — write the full reasoning once on the first thread of a cluster, then a short reply on the rest pointing to it. Every thread gets an answer; don't paste the same wall of text many times.

### 6. Don't push unless asked

Leave the fixup commits local by default and report what is ready for the user to amend or squash.

## Reporting

Lead with the verdict: how many comments, how many were real. Then per issue: what it claimed, what you found, what you did. Explicitly call out any suggestion that would have **broken** the build — that is the most useful signal for how much to trust the bot next time.
