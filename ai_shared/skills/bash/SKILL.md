---
name: bash
description: >
    Use when you are about to create or modify a bash script, or when the user asks you to create or modify a bash script.
---

## Code conventions
- Avoid using [[ and (( unless it's strictly necessary. These are a security risk!
- Declare variables inside functions with `local`, otherwise they are global and
  leak into the caller. Assign on a separate line when the value comes from a
  command: `local out` then `out="$(cmd)"`, since `local out="$(cmd)"` returns
  local's exit status and hides a failing command from `set -e`.

## Formatting
To format the code look up the `shfmt` command arguments in `nvim/lua/format.lua` and run it.
