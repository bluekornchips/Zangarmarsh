---
name: blue-penmanship
description: Audit comments, docs, and references against current code. Finds confirmed drift that is dead, unused, outdated, incorrect, or useless. Use when the user invokes blue-penmanship, asks to audit comments or docs, or asks to check README, Makefile, CI, or comment claims against the current branch.
disable-model-invocation: true
---

# Blue Penmanship

Audit comments, docs, and references against current code. Follow local Cursor rules. Do not add comments or docs unless a claim is false without them.

Find only confirmed drift. Ignore style. Do not expand into security, UX, or dead-code cleanup unless a comment or doc is the defect.

## Scope

Audit the current branch versus `origin/main`, plus unstaged and untracked files. If the user names another base, use that. If `origin/main` is missing, use `main`.

Include:

- `README.md`
- `docs/**`
- colocated READMEs
- Makefile and CI mentions
- help text and usage strings
- comments that assert behavior
- rules or skills in the diff that name paths, commands, env names, routes, or contracts

Use read-only git:

```bash
git status --short
git diff
git diff --cached
git diff origin/main...HEAD
```

## Bar

Apply `rules/always.mdc` Comments and docs, plus the language rule for the file.

- Inline comments stay rare. Keep one only for a hidden constraint, workaround, unit, or surprising invariant.
- Required function headers stay when they are true. Correct a false header. Do not delete a required header.
- Other docs state the fact a reader needs.
- Do not add file banners, section dividers, changelog comments, or records of prior work.
- Do not preserve obsolete paths as history. Prefer the current design.

Missing required headers are out of scope. Point the user at blue-review when that is the real ask.

## Drift

Report a finding only when you have read the claim line and the contradicting source line.

- Dead: describes files, commands, names, or behavior that no longer exist
- Unused: orphan docs or comments attached to deleted or unreachable code
- Outdated: once true, now contradicted by code
- Incorrect: wrong paths, targets, env names, routes, or contracts
- Useless: narrating comments, type restatements, duplicated prose, placeholders

A true required header is not useless. A true inline comment is useless when it only restates the next line.

Skip hunches, style nits, and notes that the prose could be clearer.

## Workflow

1. List changed and untracked files in scope.
2. Collect claims: documented commands, paths, targets, env names, routes, contracts, and comments that assert behavior.
3. Verify each claim against current code. Read both lines.
4. Output a plan. Stop. Wait for approval before editing.
5. After approval, delete or correct. Do not rewrite working prose. Do not add a comment or doc unless the remaining text would be false without it.

## Plan

For each finding, use this shape:

```text
- Claim: path:line
  Source: contradicting-path:line
  Class: dead | unused | outdated | incorrect | useless
  Severity: block | fix | delete
  Impact: what a reader would do wrong, or why the text does no work
  Remedy: delete the text, or the smallest correction
```

Severity:

- `block`: a reader would run a wrong command, follow a missing path, or trust a false contract
- `fix`: current behavior is misstated
- `delete`: the text does no work

If there is no confirmed drift, say so and stop.

## Edit

When the user approves:

- Delete dead, unused, and useless text.
- Correct outdated and incorrect claims with the smallest wording change.
- Do not rewrite working prose.
- Do not add comments or docs unless a claim is false without them.
- Do not turn obsolete behavior into a history note.

## Example

Claim: `README.md:48` says `make install-plugin`.
Source: `Makefile:12` defines `install`.
Class: incorrect. Severity: block.
Remedy: replace `make install-plugin` with `make install`.
