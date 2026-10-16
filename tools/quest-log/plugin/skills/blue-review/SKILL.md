---
name: blue-review
description: Run an extremely strict maintainability review for less code, required function headers, abstraction quality, giant files, and spaghetti growth. Use for blue-review, a thermo-nuclear code quality review, thermonuclear review, deep code quality audit, or especially harsh maintainability review.
disable-model-invocation: true
---

# Blue Review

Review the current branch for implementation quality. Preserve behavior. Require the smallest structure that still does the job.

Less code is a requirement. Fewer lines means fewer defects. A shorter direct change beats a longer clever one.

## Baseline

Audit the current diff. Rethink the structure so the same behavior needs fewer concepts, branches, and layers. When a clearer design deletes complexity, require that design. Measure twice, cut once.

## Standards

1. Delete complexity.
   - Local cleanup is not the goal. Look for a restructuring that makes whole branches, helpers, modes, or layers unnecessary.
   - A new helper, option, wrapper, flag, or layer is a defect when a shorter direct change exists.
   - A new abstraction is allowed only when it removes real duplication.
   - Delete unused code. Leave nothing in place for a later caller.
   - Match the file that is already there.

2. Keep files under 1000 lines.
   - A PR that pushes a file from under 1000 lines to over 1000 lines is a defect.
   - Split the file when the new code has a separate responsibility.
   - Waive the limit only when the file stays clearly organized and a split would add indirection.

3. Stop spaghetti growth.
   - A new ad-hoc conditional, one-off boolean, or special case in an unrelated flow is a design defect.
   - Prefer one default flow with fewer exceptions.
   - A change that makes the surrounding code harder to scan fails even when the behavior is correct.

4. Keep the code direct.
   - Flag magic behavior, identity wrappers, and pass-through helpers.
   - Flag casts, `any`, `unknown`, and needless optionality when a clearer type would hold the invariant.
   - Flag a silent fallback that hides an unclear invariant.
   - Reuse the existing helper. Put the logic in the module that already owns the concept.

5. Require function headers. Keep inline comments rare.
   - Require the header the language rule for that file requires. When no language rule applies, require a header on every function.
   - The header states the purpose and the signature. Include inputs, outputs, side effects, returns, and thrown errors for each section that applies.
   - A short or obvious function still needs its required header.
   - An inline comment is allowed only when the next reader would misuse the code without it: a hidden constraint, a workaround, a unit, or a surprising invariant.
   - Say that in one or two plain sentences, using the words already in the code.
   - Reject narration, file banners, section dividers, changelog comments, and stock wording such as robust, leverage, seamless, comprehensive, utilize, or "this function".

6. Flag avoidable orchestration.
   - Independent work serialized for no reason.
   - Related updates that can leave state half-applied.
   - Skip micro-optimizations.

## Questions

For each meaningful change, ask:

- Can this be reframed so fewer concepts, branches, or layers remain?
- Did the diff add a helper, flag, or branch the change does not need?
- Did a cohesive module become more coupled or harder to scan?
- Is the logic in the module that already owns the concept?
- Did a file cross 1000 lines?
- Does every required function header state the purpose and the signature?
- Does an inline comment narrate the line?

## Flag these

- A complicated implementation where a simpler framing deletes a whole category of complexity.
- A refactor that moves code around and leaves the same concepts in the reader's head.
- A file crossing 1000 lines because of this PR.
- New conditionals bolted onto unrelated paths.
- Feature logic in a shared path.
- A wrapper, cast, or optional that obscures the contract.
- A near-duplicate of an existing helper.
- A missing required function header.
- An inline comment that narrates the next line.
- Temporary branching that will stay.

## Remedies

Prefer these fixes:

- Delete a layer.
- Change the model so the conditionals disappear.
- Keep the direct flow when the abstraction does not remove duplication.
- Reuse the canonical helper.
- Move the logic to the module that already owns the concept.
- Split a file when the split removes a mixed responsibility.
- Add the missing header in the form the language rule shows.
- Delete narrating comments.

A rename is the wrong fix when the structure is the problem. A tidier copy of the same idea is the wrong fix when a simpler idea is visible.

## Tone

Be direct and serious. Stay polite. State a maintainability defect as a defect.

Say it plainly:

- `this pushes the file past 1000 lines. decompose this first.`
- `this adds another special-case branch. keep the behavior and delete the branch.`
- `this helper is longer than the direct change. remove it.`
- `this function is missing its header. state the purpose and the signature.`
- `this comment narrates the line. delete it, or state the hidden constraint.`
- `this duplicates a helper that already exists. reuse it.`

## Output

Order findings like this:

1. Structural regressions and missed simplifications
2. Extra branches and spaghetti
3. Wrong layer, wrapper, or type-boundary problems
4. File size
5. Missing function headers and bad comments
6. Legibility

Prefer a few high-conviction comments. Skip cosmetic nits when a structural defect is present.

## Approval

Approval requires correct behavior and a clean structure.

Block when any of these are true and the author cannot justify them:

- A simpler structure would delete the incidental complexity
- A file goes from below 1000 lines to above 1000 lines
- The diff adds ad-hoc branching that tangles an existing flow
- The diff scatters feature checks through shared code
- The diff adds a helper, wrapper, flag, or cast the change does not need
- The diff duplicates a helper or puts logic in the wrong module
- A required function header is missing
- Inline comments narrate the code

Leave the failing item as explicit, actionable feedback.
