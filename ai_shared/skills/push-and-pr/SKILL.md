---
name: push-and-pr
description: Push the current branch to the remote and open a pull request on the repo from this VM. Use when asked to push a branch, open/create a PR, or "push and PR".
---

Push the current branch and open a PR against the repo's default branch unless told otherwise.

## Key facts about the remote

- The base / default branch must be verified (e.g. by `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`). 
- `origin` is an **SSH** remote. This VM has its own SSH key, so `git push` over SSH works directly.
- If the SSH key is **locked**, the push fails with an auth/permission error. Ask the user to run `claudesafe --unlock`, then retry the push.

## Steps

### 1. Sanity-check the branch

```bash
git status                                   # confirm branch + clean state
git log --oneline origin/<base-branch>..HEAD       # commits that will be in the PR
git diff --stat origin/<base-branch>..HEAD         # files changed
```

Only the listed commits go into the PR — leave unrelated untracked/scratch files alone unless asked.

### 2. Push over SSH

```bash
git push -u origin <branch>
```

If the push fails with an authentication / permission error, the SSH key is likely locked — ask the user to run `claudesafe --unlock` and retry.

### 3. Create the PR

```bash
gh pr create --base develop --head <branch> --title "<title>" --body "<body>"
```

Keep the body **brief** — a short summary of what changed and why, no exhaustive file-by-file detail. Don't state which branch is the base in the body.

## Notes

- Pushing may surface unrelated remote notices (e.g. Dependabot vulnerability counts on the default branch) — mention them only if relevant.
