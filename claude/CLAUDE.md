# Comments Policy

Default to NO comment. Applies to all languages. Write one only when the code
alone would mislead: a reader would "simplify" it and break something, or it
encodes an outside constraint they cannot see from here (an API quirk, device
behavior, version skew, a bug being worked around).

Rationale does NOT go in the code. A comment states the constraint to preserve;
the argument for the decision goes in the commit message. If a comment reads as
a defense of the choice, that is the tell.

Past 2 lines, a comment must be earning it -- naming something that would cost
real time to rediscover. A genuine landmine can take as many lines as it needs;
justification cannot take even one. Check the length before committing, not
while writing: the drift is never obvious in the moment.

Explain the "why" as cause and observable effect, not the underlying mechanism.
Use plain language over jargon, and lead with the decision or constraint the
reader must preserve.

    good: must be a directory because a file mount isn't updated when the file
          is overwritten, so reload has no effect
    bad:  a file mount pins the inode at container start, so the atomic rename
          is not seen                                    (mechanism, jargon)

    bad:  Hands the container the host Docker daemon, which means full root on
          the host: anything inside can start a privileged container mounting
          /. This defeats the sandbox; it is here only for a task that needs
          to drive Docker.                          (3 lines arguing a choice)
    good: Reaching the host Docker daemon is equivalent to root on the host.

Do NOT delete comments in code unless:
1. The code they refer to is being removed
2. They are factually incorrect and cannot be reasonably corrected

Never reference memories or local-only files in the code!


# Skills policy

When you get a task ALWAYS check and load relevant skills first!


# Multi-step Execution

When executing a multi-step plan, after each step:
- Code must compile
- Commit (may need SSH key authentication - ask user for help)


# Code Review

A feature we discussed and then built gets reviewed before the PR is presented
-- the review is part of "done". Small or incidental changes do not need one.

Work that runs in stages gets reviewed at the end of each stage, not once at
the end -- a problem found in the finished product has already been built on.

Run `/code-review` for it, on Opus, rather than a hand-rolled review agent.
Relay the findings, fix what we agree on, then push, and note in the PR body
that it was reviewed.

Not every review finding is worth fixing. For each one, name the input that
would actually reach it -- if that is a case this system will never see, leave
it and say so. An edge case that cannot occur is not worth the complexity of
the fix. Fix the clearly-real findings; list the rest with the reason and let
the user choose.

Do NOT re-review a stage after acting on its findings. One review per stage.


# "Merge" Means A PR

"Merge", "land" and "ship it" mean push the branch and open a PR via the
`push-and-pr` skill, targeting the default branch unless told otherwise. Never
merge into a local default branch -- that skips the PR record and CI.


# Commit Messages

The subject line names the ONE core change: the point of the commit, not an
inventory of it. Most commits are a subject and nothing else. Never pack
several changes into the subject -- a `;` or an "and also" there means the
rest belongs in a body.

Add a body when the commit carries more than its theme. Either list the
secondary changes, naming only the ones a reader would care about:

    Lock the screen with the real wallpaper

    Also changed:
    - Lock blurs instead of pixelating
    - Added a 5s grace period
    - Removed the old screenshot helper

or, when the point is WHY, write that as prose:

    Lock the screen with the real wallpaper

    The screenshot path raced with the compositor on resume, so the lock
    sometimes showed a stale frame.

When the main change needs a why AND other work came along, use both: the
prose first, then the list:

    Lock the screen with the real wallpaper

    The screenshot path raced with the compositor on resume, so the lock
    sometimes showed a stale frame.

    Also changed:
    - Lock blurs instead of pixelating
    - Added a 5s grace period

Keep the body brief and to the point in every case.

Follow the seven rules from https://cbea.ms/git-commit.

Never add a `Co-Authored-By: Claude ...` trailer
Never add a `Claude-Session: ...` trailer


# PR Descriptions

PR titles and descriptions follow the same rules as commit messages, plus
the ones below. One exception: do NOT hard-wrap lines. GitHub reflows the
text, so manual breaks only make it ragged.

Lead with what the PR changes and why. How it was done belongs in the
commits; mention it only when the reviewer needs it to read the diff (e.g.
"review commit by commit"). Background comes after the change, and only as
much as the reader needs to follow it.

Keep before and after apart: the reader must be able to tell which sentences
describe the old state and which the new. "Previously X; now Y" is the plain
way to do it when behavior changes. The tell: a sentence that would still be
true if the PR were closed unmerged is describing the system, not the
change. Cut it, or move it to the background stated as what already held.

Write for someone who has never seen the repo, the PR chain or the commits,
possibly reading years later. Don't use terms coined in the repo, the branch
or this session without saying what they mean. This applies to the title
first of all: it is read on its own, in lists and in history.

    bad:  Expand the engine's bootstrap
          A clone sets itself up, and stays set up: direnv runs the bootstrap
          on every cd.         (undefined "engine"; old and new facts mixed)
    good: Rerun the setup script on every cd
          Previously a fresh clone ran `./setup.sh` once, on the first cd;
          after a tool version bump you had to rerun it by hand. Now direnv
          runs it on every cd, so tools stay current without anyone
          remembering to.

Size the description to the change. A small change is a sentence or two;
minor side changes go in an "Also changed:" list as in commits. A larger
feature or refactor can use sections such as Background, Changes and Tests,
plus others like Before/After when they help.

Never add a `🤖 Generated with [Claude Code](...)` line.


# GitHub Writing

Everything posted to GitHub goes out under the account running the session, so
prefix every body with `Claude: ` — inline review comments, thread replies,
issue and PR comments. Once per body, on the first line, not
per paragraph. Three exceptions: a PR review's summary body, commit messages
(see above) and PR descriptions.

Keep it terse. A reply is a sentence or two: the verdict and the evidence it
rests on. Don't restate the comment being answered, don't preamble. Go longer
only when the reasoning is genuinely hard to follow and a reader would
otherwise be left guessing.


# Abbreviations

Shorthand I may use in a prompt. It can appear anywhere in the message and
applies to that message only.

- `DAJA` = Don't act, just answer. Explain, investigate, quote the code --
  but change nothing on disk.


# Git Worktrees

Never run `git worktree prune`, and never remove a worktree you did not create
in this session. Worktrees often live outside the directories mounted into a
container or VM, so git reports them as missing or `prunable` even though they
exist on the host; pruning deletes their metadata and breaks them there.
