---
name: zig
description: Zig naming conventions and best practices
---

## Naming Conventions

When naming things (module imports, variable names, functions, etc...):

- Avoid abbreviations, e.g. `el` -> `element`
- Use reverse name spacing, e.g.:
  - `prev_time_max` -> `time_max_prev`
  - `weight_by_pop_change_output` -> `output_weight_change_by_pop`
- In other words: start with the larger, generic units and end with the smaller more specific units.

## Formatting
To format the code run:
zig fmt .
