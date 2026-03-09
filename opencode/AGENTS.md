## Code Comments

- Write terse, minimal code comments. Avoid verbose or obvious explanations.
- Only comment *why*, never *what*. The code itself should convey what it does.
- No filler phrases like "This function does...", "Used to...", "Helper that...".
- Omit comments entirely when the code is self-explanatory.
- Keep inline comments to a few words max.

## Planning

- When in plan mode, always write the plan to `.opencode/plans/*.md` (descriptive filename) in addition to showing it to the user.

## Multi-step Execution

- When executing a multi-step plan, commit after each step, not all at once.
- May need SSH key authentication for commits - ask user for help if needed.

## Code Preservation

- Avoid deleting comments and code without good reason.
- Comments can be updated/removed only if no longer correct (e.g., adjacent code changed behavior or was removed).
- Otherwise, preserve existing comments.
