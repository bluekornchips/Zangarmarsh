---
name: blue-penmanship
description: Audit comments, docs, and references against current code. Finds confirmed drift that is dead, unused, outdated, incorrect, overclaimed, useless, profane, or pii. Use when the user invokes blue-penmanship, asks to audit comments or docs, or asks to check README, Makefile, CI, or comment claims against the current branch.
disable-model-invocation: true
---

# Blue Penmanship

Audit comments, docs, and references against current code. Find only confirmed drift. Ignore style. Do not expand into security, UX, or dead-code cleanup unless a comment or doc is the defect.

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

- Keep a true required function header. Correct a false one. Never delete a required header.
- Keep an inline comment only for a hidden constraint, workaround, unit, or surprising invariant.
- Do not preserve obsolete paths as history.
- Tracked files hold no swearing, profanity, or personal identifiable information. That covers real names, emails, phone numbers, home addresses, government IDs, and private account identifiers. Clearly fictional placeholders such as `user@example.com` are allowed.

Missing required headers are out of scope. Point the user at blue-review when that is the real ask.

## Drift

Report a finding only after reading the claim line and the contradicting source line.

- Dead: describes files, commands, names, or behavior that no longer exist
- Unused: orphan docs or comments attached to deleted or unreachable code
- Outdated: once true, now contradicted by code
- Incorrect: wrong paths, targets, env names, routes, or contracts
- Overclaimed: a claim about tested or supported behavior that goes past the evidence in the repo, such as a platform no test or CI job covers
- Useless: narrating comments, edit-diary comments, conversation or prompt leakage, type restatements, duplicated prose, placeholders
- Profane: swearing or profanity in a tracked file
- Pii: real personal identifiable information in a tracked file

A true inline comment is useless when it only restates the next line. Skip hunches, style nits, and notes that the prose could be clearer. Report profane and pii findings even when the surrounding claim is accurate.

## Workflow

1. List changed and untracked files in scope.
2. Collect claims: documented commands, paths, targets, env names, routes, contracts, and comments that assert behavior.
3. Verify each claim against current code.
4. Output a plan. Stop. Wait for approval before editing.
5. After approval, apply the Edit rules.

## Plan

For each finding, use this shape:

```text
- Claim: path:line
  Source: contradicting-path:line
  Class: dead | unused | outdated | incorrect | overclaimed | useless | profane | pii
  Severity: block | fix | delete
  Impact: what a reader would do wrong, or why the text does no work
  Remedy: delete the text, or the smallest correction
```

Severity:

- `block`: a reader would run a wrong command, follow a missing path, or trust a false contract; also any `pii` finding
- `fix`: current behavior is misstated; also any `overclaimed` or `profane` finding
- `delete`: the text does no work

If there is no confirmed drift, say so and stop.

## Edit

- Delete dead, unused, and useless text.
- Correct outdated and incorrect claims with the smallest wording change.
- Narrow overclaimed text to the verified scope, or delete it.
- Rewrite `profane` text without swearing.
- Replace `pii` with non-identifying wording or a clear fictional placeholder.
- Leave working prose alone.
- Add a comment or doc only when the remaining text would be false without it.

## Example

Claim: `README.md:48` says `make install-plugin`.
Source: `Makefile:12` defines `install`.
Class: incorrect. Severity: block.
Remedy: replace `make install-plugin` with `make install`.
