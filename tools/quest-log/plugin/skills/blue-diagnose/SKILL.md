---
name: blue-diagnose
description: Diagnose a hard bug or performance regression from a red feedback loop before any fix.
disable-model-invocation: true
---

# Blue Diagnose

Build a loop that goes red on the bug, then let the loop decide every later step. Reading code to build a theory before the loop exists is the failure this skill prevents.

## Redact

Write `<REDACTED>` in place of every secret in commands, output, and captured artifacts. Keep credentials in environment variables so the loop never shows them. When the redacted output cannot explain the bug, say so and ask the user.

## 1. Feedback loop

Try these in order and keep the first one that reaches the bug:

1. An existing test at a seam that reaches the bug
2. A CLI call with a fixture input, diffed against known-good output
3. A request against a local server
4. A bisect harness for `git bisect run` between a good and a bad state
5. A differential run of the same input through two versions or two configs

A loop that would invoke Python, directly or through a Make target, script, hook, or test suite, waits for explicit user approval of that command.

The step is done when one named command has already run once, with its redacted output shown, and it is:

- Red-capable: it drives the bug path and asserts the user's exact symptom
- Deterministic: same verdict every run, or a pinned high reproduction rate for a flaky bug
- Fast: seconds, not minutes
- Unattended: no human in the loop

When no loop is possible, stop. List what was tried, then ask for access to an environment that reproduces it, a redacted artifact, or permission for temporary instrumentation.

## 2. Reproduce and minimize

Confirm the loop shows the failure the user described, not a nearby one. Cut inputs, callers, config, and steps one at a time, rerunning after each cut. Done when removing any remaining element turns the loop green.

## 3. Hypothesise

Rank 3 to 5 hypotheses before testing any. Each one states a prediction:

```text
If <X> is the cause, then changing <Y> clears the symptom.
```

A hypothesis with no prediction is discarded. Show the ranked list to the user, then proceed with the ranking unless the user re-ranks it.

## 4. Instrument

Each probe tests one prediction and changes one variable. Prefer a debugger, then targeted logs at the boundaries that separate hypotheses. Tag every debug line with one prefix such as `[DEBUG-a4f2]` so one grep finds them all.

For a performance bug, take a baseline measurement first, then bisect against it.

## 5. Fix

Write a regression test only when the current request asks for tests and a seam exists that exercises the real failure as callers hit it. Otherwise name the missing seam in the reply; a missing seam is itself a finding.

Apply the fix, then rerun the original loop from step 1 against the original scenario.

## 6. Cleanup

- The step 1 loop is green
- `rg -n 'DEBUG-a4f2'` with the chosen prefix returns nothing
- Throwaway harnesses and fixtures are deleted
- The reply states which hypothesis held
