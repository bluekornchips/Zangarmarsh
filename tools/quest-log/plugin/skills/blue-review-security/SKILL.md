---
name: blue-review-security
description: Review the current change for security defects that cross a real trust boundary.
disable-model-invocation: true
---

# Blue Review Security

Find defects that let a lower-trust principal cross a real trust boundary. Give each one a source trace, a verdict, and the smallest fix. A missing best practice is a hardening note, not a finding.

## Scope

Review the current branch versus `origin/main`, plus unstaged and untracked files. If the user names another base, use that. If `origin/main` is missing, use `main`.

```bash
git status --short
git diff
git diff --cached
git diff origin/main...HEAD
```

## Boundary test

Every candidate names all six:

1. Lower-trust principal
2. Input or action that principal controls
3. Intended control on the path
4. Boundary the input crosses
5. Affected principal or resource
6. Observed or owner-observable result

A candidate missing any of the six goes under hardening notes.

## Evidence

Trace the path in source first, from entry point to sink. Run only tests or commands that already exist, and only when they never invoke Python without explicit approval. Use dummy principals and secrets. Leave deployed endpoints, shared services, and dependency installs alone.

When a decisive fact lives outside the repository, such as branch protection, runner config, or a host setting, keep the candidate as `needs_validation` and name that fact.

## Verdicts

- `confirmed`: full source trace and observed result. Gets a severity.
- `needs_validation`: source trace plus the exact missing fact and the check an owner can run. No severity.
- `rejected`: source or a visible control refutes it. State the reason.

Give each `confirmed` candidate to a fresh subagent that did not find it, with the instruction to refute it from source. Keep the verdict that survives.

## Severity

Severity never exceeds the demonstrated impact.

- critical: an unauthenticated actor gains code execution, full data access, or account takeover
- high: an explicit control is fully defeated with real consequences
- medium: a real boundary violation with narrow blast radius or uncommon preconditions
- low: disclosure of non-secret internals, or high effort for little gain
- informational: confirmed but minimal, useful mainly as a step in a larger finding

## Focus

Follow [blue-review-bash](../blue-review-bash/SKILL.md) for shell detail. Hunt these in the diff:

- Shell injection, unquoted expansion into commands, and `eval`
- Destructive paths that follow a symlink or a path the script did not create
- Temp files with loose modes or no cleanup
- Secrets, tokens, or personal data in tracked files
- `curl | sh` installs and checksums fetched from the same place as the artifact
- Mutable dependency pins such as branches, floating tags, and unpinned CI actions
- CI jobs where an untrusted trigger runs contributor code with secrets or write tokens
- Plugins, hooks, and rules installed or run before their source is checked

## Fix

State the invariant the code must hold, then the narrowest change at the last trusted decision point. Name a regression case. Describe the fix; edit source only when the user asks.

## Anti-patterns

- Checklist deviations reported as vulnerabilities
- Defense-in-depth advice when an earlier layer already blocks the path
- Guessed provider, proxy, or deployment behavior
- Same-user impact treated as a crossed boundary
- A stronger result claimed than the one observed
- Severity on a `needs_validation` record

## Output

```text
- Title: short name
  Verdict: confirmed | needs_validation | rejected
  Severity: critical | high | medium | low | informational | none
  Trace: entry-path:line -> sink-path:line
  Boundary: principal, input, control, boundary, resource, result
  Missing fact: needs_validation only
  Fix: invariant and smallest change
```

List confirmed findings first, then `needs_validation`, then hardening notes. A clean change has zero findings; say so.
