---
name: self-review
description: >
    Get an independent review of a change you just made, from a subagent that
    does not share your context, and address it before the change counts as
    done. Use when you have finished building or fixing what was asked, and
    always before opening a PR, merging to the main branch, or telling the user
    the work is complete. Any further code change needs another round.
---

Hand your own diff to a reviewer that was not there when you wrote it, then act on
what comes back.

## Why a subagent without your context

You just argued yourself into every line of this change. A reviewer that inherits
that reasoning inherits the blind spots with it: the case you decided was
impossible stays impossible, the helper you decided was equivalent stays
equivalent. A reviewer that only ever sees the repository and the request has to
derive all of that from the code, which is exactly where the mistakes are.

So: a fresh subagent (`general-purpose`), never a fork of yourself, and a prompt
that carries the *request* but none of your *reasoning*.

## Steps

### 1. Scope the change

```bash
git rev-parse --abbrev-ref HEAD
gh repo view --json defaultBranchRef -q .defaultBranchRef.name    # or: git remote show origin
git merge-base <default-branch> HEAD                              # the base to diff from
git diff <base>                    # everything the branch changes, committed or not
git status --short                 # new files, which the diff above does not show
git log --oneline <base>..HEAD
```

Make sure every edit you want reviewed is written to disk, and `git add -N` any new
file (or commit it) so it appears in the diff the reviewer reads.

### 2. Launch the reviewer

Use the Agent tool with `subagent_type: "general-purpose"` (in a harness without
that tool, spawn a fresh session on the repo instead). Fill the placeholders in;
send nothing else.

```
Review the changes on branch <branch> of the repository at <path>, against <base>.

You have no context on how these changes were made. That is deliberate: derive
everything from the repository itself.

    git -C <path> diff <base>              # the change, committed or not
    git -C <path> log --oneline <base>..HEAD

The change was requested as, verbatim:

    <the user's request, quoted exactly>

Load the `review-pr` skill and apply its review rubric to every part of this diff.
Skip its PR-collection steps: the commands above are the source, and some of what
you are reviewing is not committed.
Read the surrounding files, not only the diff -- most defects are in how the change
meets code it did not touch. Check CLAUDE.md and any language skill for conventions
the change has to follow, and run the tests or build if the repo has them.

Report findings only: no summary of what the change does, no praise. For each
finding give a severity (must-fix / should-fix / nit), file:line, what is wrong,
and the evidence you checked. Say so explicitly if a severity has no findings.
```

Do **not** add your explanation of how the code works, why you chose an approach,
or which parts you are confident about. That is the anchoring you are trying to
avoid. The user's request goes in verbatim because the reviewer needs the
acceptance criteria; your defence of the implementation does not.

For a large or risky change, launch two or three reviewers in one message with
different lenses (correctness, simplification, collateral damage on code the diff
does not touch) rather than one reviewer asked to do everything.

### 3. Judge every finding before acting on it

The reviewer is guessing about intent, so some findings will be wrong. Each one is
a hypothesis to test against the code, not a defect report -- verify with a grep, a
build, a test run, or the file itself. Accepting a wrong finding costs more than
rejecting a right one, since it lands in the code.

### 4. Fix, then review again

Fix what is real. Then note that you have changed the code: the review you just got
no longer describes the diff, so go back to step 1 and get another one. Stop when a
review comes back with no must-fix findings.

If a third round still turns up must-fix findings, stop and bring it to the user --
that is a sign the change needs a rethink rather than another patch.

### 5. Record the review

Once the findings are addressed:

```bash
python3 "$HOME/.claude/hooks/self-review.py" --mark      # skip where the hook is not installed
```

This records the reviewed diff. A hook refuses `git push`, `gh pr create` and
`git merge` while the branch's diff differs from the recorded ones, which is what
makes a later edit require a new round before the work can be handed on. Only mark
a diff you actually reviewed; marking is not a way to get past the gate, and the
user can see in your reply that you took it.

Marking without a review fits a change with no source in it, or work the user asked
to keep throwaway. If untracked scratch files keep waking the check, they belong in
`.gitignore` rather than in a mark.

### 6. Report

Tell the user what the review found, what you fixed, and what you rejected with the
evidence for rejecting it. If you disagreed with the reviewer on something that
matters, say so plainly so they can overrule you.
