---
name: blue-review-lua
description: Lua Repository Review Criteria
disable-model-invocation: true
---

# Lua Repository Review Criteria

## Overview

Pragmatic review criteria for Lua repositories, including WoW add-on Lua files loaded by a TOC. Focus on security, namespace boundaries, error handling, style choices, and tests.

---

## Critical Security Must Fix

- [ ] _No implicit globals_: Declare all variables with `local` unless documented as intentional WoW API or saved variable globals
- [ ] _No hardcoded secrets_: Tokens, passwords, keys, and service URLs come from config or environment
- [ ] _Input validation_: Public APIs validate external input before use
- [ ] _No unsafe dynamic execution_: Avoid `load`, `loadstring`, and dynamic module names from untrusted input
- [ ] _Path safety_: Normalize and constrain user file paths so they cannot drive arbitrary reads or writes
- [ ] _Shell safety_: Calls to `os.execute` or `io.popen` avoid untrusted input and quote arguments safely
- [ ] _Safe logging_: Logs exclude secrets, credentials, and sensitive user data

---

## Error Handling and Reliability Must Fix

- [ ] _Expected failures return values_: I/O, network, parse, and user input failures return `nil, err` and an optional error code
- [ ] _Misuse fails loudly_: Programmer errors use `error()` or `assert()` with useful messages
- [ ] _Early validation_: Functions reject bad arguments before doing work
- [ ] _No swallowed failures_: Check return values from file, process, network, and parser calls
- [ ] _Resource cleanup_: Files, sockets, and handles have explicit close paths, including failure paths
- [ ] _No `__gc` resource dependency_: Garbage collection is never the only closer of non-memory resources
- [ ] _Deterministic require_: Requiring test-only library modules does not mutate global state, start work, or configure anything

---

## WoW Lua Style Choices

- [ ] _TOC chunk namespace_: TOC-loaded add-on files start with `local _, ns = ...` and keep shared public APIs on `ns`
- [ ] _Public namespace naming_: Public functions on `ns` use `PascalCase` so shared APIs stand out from local helpers
- [ ] _TOC side effects are intentional_: Frame, event, saved-variable, and slash command registration happen in TOC-loaded files when needed
- [ ] _Saved variables documented_: Document addon-specific saved variables, `SLASH_*`, and `SlashCmdList` entries in `.luacheckrc`
- [ ] _2-space indentation_: WoW add-on Lua files and Lua tests use 2 spaces, no tabs, and no mixed indentation

---

## General Lua Style

- [ ] _Line endings_: Files use LF line endings
- [ ] _One statement per line_: Semicolons are not statement terminators
- [ ] _Naming_: Local variables and helpers use `snake_case`, and class-style tables use `CamelCase`
- [ ] _Local scope_: Declare variables in the smallest useful scope
- [ ] _Function syntax_: Use `local function name(...)` for named local functions and `function ns.Name(...)` for public namespace APIs matching existing public names
- [ ] _Call syntax_: String and single-line table arguments use explicit parentheses
- [ ] _String style_: Default to double quotes and use single quotes only to avoid escaping double quotes
- [ ] _Spacing_: Operators, assignment, commas, and comments use consistent spacing
- [ ] _No visual alignment churn_: Declarations are not padded into columns unless logical correspondence matters

---

## Namespaces, Modules, and APIs

- [ ] _TOC files use namespace APIs_: TOC-loaded files attach shared behavior to `ns` instead of creating globals
- [ ] _Require-only modules return tables_: Test-only library modules loaded through `require` return a table and avoid globals
- [ ] _Require naming_: Name locals holding required modules after the last module path component
- [ ] _No arbitrary aliases_: Module aliases never shorten names in ways that hide meaning
- [ ] _Public API declarations_: Declare public functions on `ns` or a returned module table with dot syntax
- [ ] _Private helpers_: Local helper functions stay private and are not exposed through `ns` or a returned module table
- [ ] _No hidden module state_: Avoid mutable module state unless it is intentional add-on runtime state
- [ ] _Known table fields_: Use dot notation for known object fields
- [ ] _Dynamic keys_: Use subscript notation for variable keys and list access
- [ ] _Table construction_: Multiline tables use trailing commas and plain key syntax when possible

---

## OOP and Metatables

- [ ] _Class table local_: Class tables and metatables are local to the TOC chunk or require-only module
- [ ] _Methods use colon syntax_: Method calls and declarations use `:` when `self` is intended
- [ ] _Metamethods grouped_: Metamethod functions live inside the metatable declaration when practical
- [ ] _Constructor clear_: Constructors create a table, attach metatable behavior, and return the instance
- [ ] _Explicit close_: Objects owning files, sockets, or handles expose and document a close method

---

## Documentation

- [ ] _LDoc headers_: Every function except `main` has an LDoc header stating purpose, params, and returns
- [ ] _Comments explain why_: Inline comments are rare and explain rationale or non-obvious behavior
- [ ] _TODO and FIXME meaning_: `TODO` marks missing future work and `FIXME` marks known problems in current code
- [ ] _README accuracy_: Setup, usage, and Lua version notes match the repository
- [ ] _Config docs_: Document required environment variables and config files

---

## Static Analysis and Tooling

- [ ] _luacheck enabled_: `luacheck` runs locally or in CI when Lua code is present
- [ ] _.luacheckrc documented_: WoW globals, saved variables, unused args, and warning suppressions have clear scope
- [ ] _No broad suppressions_: `luacheck` ignores do not hide real correctness issues
- [ ] _Whitespace warnings understood_: Class 6xx whitespace warnings are not treated as logic issues
- [ ] _Formatting consistent_: Formatting follows the chosen WoW Lua style and adds no unrelated churn
- [ ] _Lua versions declared_: Document and test supported Lua or LuaJIT versions

---

## Testing

- [ ] _Test framework present_: Configure Busted or another Lua test runner when the repo has non-trivial logic
- [ ] _Core logic covered_: Public API behavior and failure modes have tests
- [ ] _Loading tested_: TOC-loaded files and require-only modules load in the test harness without missing dependencies
- [ ] _Resource cases tested_: Cover file, socket, and handle cleanup paths
- [ ] _Fixtures realistic_: Fixtures match real Lua tables, config shapes, and edge cases
- [ ] _Deterministic tests_: Tests avoid live network and host-specific paths unless isolated
- [ ] _Honest assertions_: Tests assert through the public interface, and expected values come from a literal or the spec, never recomputed the way the code computes them
- [ ] _CI gates_: Lint and tests run in CI with documented commands

---

## Repository Structure

- [ ] _Lowercase Lua files_: Lua source file names are lowercase
- [ ] _TOC layout documented_: The add-on TOC lists Lua files in the intended load order when WoW add-on code is present
- [ ] _Tests layout_: Tests live under the repo-documented test directory
- [ ] _Optional LuaRocks layout_: Library code uses `src/`, `spec/`, and rockspec metadata only when the project follows LuaRocks layout
- [ ] _Rock metadata_: Rockspec files define dependencies, supported Lua versions, and test commands where applicable
- [ ] _Ignore files_: Ignore generated rocks, coverage, temp files, and local tool output

---

## Review Process

### Priority Order

1. _Critical Security_ - Globals, dynamic execution, shell calls, path handling, and secrets
2. _Error Handling and Reliability_ - Return contracts, cleanup, load-time side effects, and unchecked failures
3. _Namespace and Module Boundaries_ - TOC namespace behavior, require behavior, public API shape, state, and OOP contracts
4. _Testing and Tooling_ - `luacheck`, tests, CI, and supported Lua versions
5. _Style and Maintainability_ - WoW Lua style choices, naming, comments, and file layout

### Review Output Format

- Use checkboxes for each criterion.
- Document specific `file:line` references for issues.
- Mark priority: Critical, Important, or Enhancement.
- Provide actionable fix suggestions.

### Example Output

```markdown
## Review: Repository Name - Date

### Critical Issues

- [ ] Unsafe dynamic execution - File: `src/loader.lua:42`

### Important Improvements

- [ ] TOC-loaded file creates an undocumented global - File: `addon/init.lua:12`
```

---
