---
name: blue-pr
description: Write extremely short, courteous pull request comments that apply the blue-review maintainability bar. Use when the user asks for a PR review, pull request comments, or invokes blue-pr.
disable-model-invocation: true
---

# Pull Request Comments

Review the current diff with the blue-review bar. Leave the comments on the pull request in the reply. Post them only when the user asks.

One comment per issue. Two sentences at most. Skip praise, summaries, and nits when a structural note is present.

## Bar

1. Delete complexity. A new helper, option, wrapper, flag, or layer needs a reason. A new abstraction is for real duplication only.
2. Keep files under 1000 lines. Ask to split when this diff crosses that line and the new code has its own responsibility.
3. Stop spaghetti growth. Prefer one default flow with fewer exceptions.
4. Keep the code direct. Reuse the helper and module that already own the concept.
5. Require the function header the language rule requires. An inline comment stays only for a hidden constraint, workaround, unit, or surprising invariant.
6. Flag avoidable orchestration. Skip micro-optimizations.

## Voice

Speak as we. Stay polite. Name the code, not the author.

- Use we.
- Skip you, your, let's, can we, and question marks.
- One fact, then the action.
- Use the words already in the code.

Say it this way:

- `This pushes the file past 1000 lines. We should split it first.`
- `This adds another special-case branch. We can keep the behavior and delete the branch.`
- `This helper is longer than the direct change. We should remove it.`
- `This function is missing its header. We should state the purpose and the signature.`
- `This comment narrates the line. We should delete it, or state the hidden constraint.`
- `This duplicates a helper that already exists. We should reuse it.`

## Output

Leave a few high-conviction comments, in this order:

1. Structural regressions and missed simplifications
2. Extra branches and spaghetti
3. Wrong layer, wrapper, or type-boundary problems
4. File size
5. Missing function headers and bad comments
6. Legibility

Each comment stands alone on the line it concerns. When the structure is clean, say `The structure is clean. We can merge this.`

## Approval

We approve when the behavior is correct and the structure is clean.

We hold the merge when any of these are true and we cannot justify them:

- A simpler structure would delete the incidental complexity
- A file goes from below 1000 lines to above 1000 lines
- The diff adds ad-hoc branching that tangles an existing flow
- The diff scatters feature checks through shared code
- The diff adds a helper, wrapper, flag, or cast the change does not need
- The diff duplicates a helper or puts logic in the wrong module
- A required function header is missing
- Inline comments narrate the code
