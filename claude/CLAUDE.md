# Comments Policy

Keep comments brief. Omit them when the code is self-explanatory; comment only
the non-obvious "why", not the "what". Applies to all languages.

Explain the "why" as cause and observable effect, not the underlying mechanism.
Use plain language over jargon, and lead with the decision or constraint the
reader must preserve. E.g. prefer "must be a directory because a file mount
isn't updated when the file is overwritten, so reload has no effect" over "a
file mount pins the inode at container start, so the atomic rename is not seen".

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


# Commit Messages

Prefer a subject line only. Include a body only when necessary for
clarification, and keep it brief.
