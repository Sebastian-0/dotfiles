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

## STD lib documentation
NEVER assume your zig knowledge is up-to-date! Always verify by visiting either:
- Online STD lib docs: https://ziglang.org/documentation/0.15.2/std
- On-disk STD lib source: /var/lib/snapd/snap/zig/current/lib/std (example location, look for zig install folder)
