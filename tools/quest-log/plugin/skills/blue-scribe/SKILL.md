---
name: blue-scribe
description: Write or tighten a rule, skill, or README that an agent reads.
disable-model-invocation: true
---

# Blue Scribe

Write documents an agent follows the same way every run. Apply `rules/always.mdc` Comments and docs and `rules/never.mdc` first; this skill adds what those rules leave open.

## Description

- With `disable-model-invocation: true`, the description is a one-line summary for the human who types the name.
- Without it, the description is always in context. Put the trigger word first and list one trigger per distinct case. Collapse synonyms into one trigger.

## Body

- Steps: what the agent does, in order. Each step ends on a criterion the agent can check, such as `every changed file listed` rather than `understanding reached`.
- Reference: rules and facts consulted on demand. Keep each concept, its rules, and its caveats under one heading.
- Material only some cases need moves to a sibling file behind a link that names when to read it.

## Pruning

- Keep each meaning in one place. Point to that place instead of restating it.
- Leave facts that a Makefile target, `--help`, config file, or the directory layout already shows. Write down what no lookup reveals: the unwritten convention, the reason, the gotcha.
- Delete any sentence that does not change behavior versus the default. Delete the whole sentence, not words from it.
- Replace a phrase spelled out at several sites with one word the model already knows.
- State the target behavior. When a prohibition is the only safe form, pair it with the target behavior.

## Workflow

1. Read the target file and every file it links.
2. For each line, name the behavior it changes. A line with no answer is a no-op.
3. Find meanings stated in more than one file.
4. Output a plan: path:line, problem, remedy. Stop and wait for approval before editing an existing file.
5. After approval, apply the smallest edits. For a new file, write it directly and check it against this list.

Done when every remaining line changes behavior and every meaning has one home.
