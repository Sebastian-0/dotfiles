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


# Finishing a change

A change is not done when it compiles and you believe it is right -- it is done
when a reviewer who does not share your context has seen it. When you have
finished what was asked, and always before opening a PR, merging to the main
branch, or reporting a feature complete, run the `self-review` skill.

Every further code change invalidates the last review, including the fixes you
make in response to one: address the feedback, then review the new diff again.
A hook refuses `git push`, `gh pr create` and `git merge` while the branch's diff
differs from the ones recorded as reviewed. It only guards that boundary, so
finishing a change without pushing it is still yours to get right.


# Commit Messages

Prefer a subject line only. Include a body only when necessary for
clarification, and keep it brief.
