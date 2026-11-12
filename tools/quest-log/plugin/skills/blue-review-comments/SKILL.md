---
name: blue-review-comments
description: Write extremely short, courteous pull request comments that apply the blue-review maintainability bar. Use when the user asks for a PR review, pull request comments, or invokes blue-review-comments.
disable-model-invocation: true
---

# Pull Request Comments

Review the current diff with the blue-review bar. Leave the comments in the reply. Post them only when the user asks.

## Bar

Apply the Standards in [blue-review](../blue-review/SKILL.md).

## Voice

Speak as we. Name the code, not the author. One comment per issue, two sentences at most: one fact, then the action. Use the words already in the code.

Skip you, your, let's, can we, question marks, praise, summaries, and nits when a structural note is present.

Say it this way:

- `This pushes the file past 1000 lines. We should split it first.`
- `This adds another special-case branch. We can keep the behavior and delete the branch.`
- `This helper is longer than the direct change. We should remove it.`
- `This function is missing its header. We should state the purpose and the signature.`
- `This comment narrates the line. We should delete it, or state the hidden constraint.`
- `This duplicates a helper that already exists. We should reuse it.`

## Output

Leave a few high-conviction comments, each standing alone on the line it concerns, in this order:

1. Structural regressions and missed simplifications
2. Extra branches and spaghetti
3. Wrong layer, wrapper, or type-boundary problems
4. File size
5. Missing function headers and bad comments
6. Legibility

When the structure is clean, say `The structure is clean. We can merge this.`

## Approval

We approve when the behavior is correct and the structure is clean.

We hold the merge on any blue-review Approval block the author cannot justify.
