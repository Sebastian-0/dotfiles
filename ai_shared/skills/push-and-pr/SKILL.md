---
name: push-and-pr
description: Push the current branch to the remote and open a pull request on the repo from this VM. Use when asked to push a branch, open/create a PR, or "push and PR".
---

Push the current branch and open a PR against the repo's default branch unless told otherwise.

## Key facts about the remote

- The base / default branch must be verified (e.g. by `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`). 
- `origin` may be an SSH URL, but in the sandbox git sends GitHub traffic over https with the sandbox's gh token, so `git push` needs no SSH key.
- If the push fails with an auth/permission error, check `gh auth status`; if the token is missing or expired, ask the user to run `gh auth login`, then retry.

## Steps

### 1. Sanity-check the branch

```bash
git status                                   # confirm branch + clean state
git log --oneline origin/<base-branch>..HEAD       # commits that will be in the PR
git diff --stat origin/<base-branch>..HEAD         # files changed
```

Only the listed commits go into the PR — leave unrelated untracked/scratch files alone unless asked.

Commit messages must not carry a `Co-Authored-By: Claude ...` trailer.

### 2. Push

```bash
git push -u origin <branch>
```

If the push fails with an authentication / permission error, see `gh auth status` and ask the user to run `gh auth login`, then retry.

### 3. Create the PR

```bash
gh pr create --base <base-branch> --head <branch> --title "<title>" --body "<body>"
```

Write the title and body by the "PR Descriptions" rules in the global CLAUDE.md. Two things specific to this flow: don't state which branch is the base in the body, and never link to a Claude Code session — only the user can open those.

## Notes

- Pushing may surface unrelated remote notices (e.g. Dependabot vulnerability counts on the default branch) — mention them only if relevant.
