## Code Comments

- Write terse, minimal code comments. Avoid verbose or obvious explanations.
- Only comment *why*, never *what*. The code itself should convey what it does.
- No filler phrases like "This function does...", "Used to...", "Helper that...".
- Omit comments entirely when the code is self-explanatory.
- Keep inline comments to a few words max.

## Planning

- When finished planning in plan mode ALWAYS ask the user to switch to build mode and then WRITE THE PLAN to `.opencode/plans/*.md` (descriptive filename)

## Multi-step Execution

- When executing a multi-step plan, commit after each step, not all at once.
- Code must always compile after EACH STEP!
- May need SSH key authentication for commits - ask user for help if needed.

## Git Commits

- Before committing:
  - ALWAYS run `git status` to ensure no files are missing from the commit.
  - ALWAYS format files according to the SKILL you are using
- Amend commits with small fixes

## Code Preservation

- DO NOT delete existing comments unless they become irrelavant!
- DO NOT change code you don't need to change!
- DO NOT do formatting changes to existing code!
- If unsure about a piece of code ASK ME!

## Skills
When you get a task ALWAYS check for relevant skills first and load them!
