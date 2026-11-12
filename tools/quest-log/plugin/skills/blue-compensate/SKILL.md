---
name: blue-compensate
description: Find compensating code and propose first-principles redesigns under which it would never have been written. Use for blue-compensate, compensating-code review, or redesign of shims, adapters, dual paths, and silent fallbacks.
disable-model-invocation: true
---

# Blue Compensate

Find all compensating code, then propose redesigns from first principles under which it would never have been written.

1. List every compensating site in the diff and the nearby code it props up.
2. Name the broken invariant or boundary each site repairs.
3. Propose the redesign where that repair is unnecessary.
4. Prefer that redesign over polishing the compensation.

For each finding: site, what it compensates for, the redesign where it would never have been written, why polishing fails.

Block when compensating code remains and a first-principles redesign is visible.
