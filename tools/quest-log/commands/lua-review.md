# Lua Repository Review Criteria

## Overview

Pragmatic review criteria for Lua repositories, including WoW add-on Lua files loaded by a TOC. Focus on security, namespace boundaries, error handling, style choices, and tests.

---

## Critical Security Must Fix

- [ ] _No implicit globals_: All variables are declared with `local`, or are documented intentional globals for WoW APIs or saved variables.
- [ ] _No hardcoded secrets_: Tokens, passwords, keys, and service URLs come from config or environment.
- [ ] _Input validation_: Public APIs validate external input before use.
- [ ] _No unsafe dynamic execution_: Avoid `load`, `loadstring`, and dynamic module names from untrusted input.
- [ ] _Path safety_: File paths from users are normalized, constrained, and not used for arbitrary reads or writes.
- [ ] _Shell safety_: Calls to `os.execute` or `io.popen` avoid untrusted input and quote arguments safely.
- [ ] _Safe logging_: Logs do not include secrets, credentials, or sensitive user data.

---

## Error Handling and Reliability Must Fix

- [ ] _Expected failures return values_: I/O, network, parse, and user input failures return `nil, err` and optional error code.
- [ ] _Misuse fails loudly_: Programmer errors use `error()` or `assert()` with useful messages.
- [ ] _Early validation_: Functions reject bad arguments before doing work.
- [ ] _No swallowed failures_: Return values from file, process, network, and parser calls are checked.
- [ ] _Resource cleanup_: Files, sockets, and handles have explicit close paths, including failure paths.
- [ ] _No `__gc` resource dependency_: Non-memory resources are not only closed by garbage collection.
- [ ] _Deterministic require_: Requiring test-only library modules does not mutate global state, start work, or perform configuration.

---

## WoW Lua Style Choices

- [ ] _TOC chunk namespace_: TOC-loaded add-on files use `local _, ns = ...` at the top, and shared public APIs live on `ns`.
- [ ] _Public namespace naming_: Public functions on `ns` use `PascalCase` so shared APIs stand out from local helpers.
- [ ] _TOC side effects are intentional_: Frame registration, event registration, saved-variable setup, and slash command registration happen in TOC-loaded files when needed.
- [ ] _Saved variables documented_: Addon-specific saved variables, `SLASH_*`, and `SlashCmdList` entries are documented in `.luacheckrc`.
- [ ] _2-space indentation_: WoW add-on Lua files and Lua tests use 2 spaces, no tabs, and no mixed indentation.

---

## General Lua Style

- [ ] _Line endings_: Files use LF line endings.
- [ ] _One statement per line_: Semicolons are not used as statement terminators.
- [ ] _Naming_: Local variables and local helpers use `snake_case`; class-style tables use `CamelCase`.
- [ ] _Local scope_: Variables are declared in the smallest useful scope.
- [ ] _Function syntax_: Named local functions use `local function name(...)`, and public namespace APIs use `function ns.Name(...)` when matching existing public names.
- [ ] _Call syntax_: String and single-line table arguments use explicit parentheses.
- [ ] _String style_: Double quotes are the default; single quotes are only used to avoid escaping double quotes.
- [ ] _Spacing_: Operators, assignment, commas, and comments use consistent spacing.
- [ ] _No visual alignment churn_: Declarations are not padded into columns unless logical correspondence is important.

---

## Namespaces, Modules, and APIs

- [ ] _TOC files use namespace APIs_: TOC-loaded files attach shared behavior to `ns` instead of creating globals.
- [ ] _Require-only modules return tables_: Test-only library modules loaded through `require` return a table and avoid globals.
- [ ] _Require naming_: Required modules are stored in locals named after the last module path component when `require` is used.
- [ ] _No arbitrary aliases_: Module aliases are not shortened in ways that hide meaning.
- [ ] _Public API declarations_: Public functions are declared on `ns` or on a returned module table with dot syntax.
- [ ] _Private helpers_: Local helper functions are truly private and not exposed through `ns` or a returned module table.
- [ ] _No hidden module state_: Mutable module state is avoided unless it represents intentional add-on runtime state.
- [ ] _Known table fields_: Dot notation is used for known object fields.
- [ ] _Dynamic keys_: Subscript notation is used for variable keys and list access.
- [ ] _Table construction_: Multiline tables use trailing commas and plain key syntax when possible.

---

## OOP and Metatables

- [ ] _Class table local_: Class tables and metatables are local to the TOC chunk or require-only module.
- [ ] _Methods use colon syntax_: Method calls and declarations use `:` when `self` is intended.
- [ ] _Metamethods grouped_: Metamethod functions live inside the metatable declaration when practical.
- [ ] _Constructor clear_: Constructors create a table, attach metatable behavior, and return the instance.
- [ ] _Explicit close_: Objects that own files, sockets, or handles expose and document a close method.

---

## Documentation

- [ ] _LDoc for public APIs_: Public namespace APIs, modules, and functions document purpose, params, returns, and errors.
- [ ] _Comments explain why_: Inline comments are rare and explain rationale or non-obvious behavior.
- [ ] _TODO and FIXME meaning_: `TODO` marks missing future work; `FIXME` marks known problems in current code.
- [ ] _README accuracy_: Setup, usage, and Lua version notes match the repository.
- [ ] _Config docs_: Required environment variables and config files are documented.

---

## Static Analysis and Tooling

- [ ] _luacheck enabled_: `luacheck` runs locally or in CI when Lua code is present.
- [ ] _.luacheckrc documented_: WoW globals, saved variables, unused args, or warning suppressions have clear scope.
- [ ] _No broad suppressions_: `luacheck` ignores do not hide real correctness issues.
- [ ] _Whitespace warnings understood_: Class 6xx whitespace warnings are not treated as logic issues.
- [ ] _Formatting consistent_: Formatting follows the chosen WoW Lua style and does not add unrelated churn.
- [ ] _Lua versions declared_: Supported Lua or LuaJIT versions are documented and tested.

---

## Testing

- [ ] _Test framework present_: Busted or another Lua test runner is configured when the repo has non-trivial logic.
- [ ] _Core logic covered_: Public API behavior and failure modes have tests.
- [ ] _Loading tested_: TOC-loaded files and require-only modules can load in the test harness without missing dependencies.
- [ ] _Resource cases tested_: File, socket, and handle cleanup paths are covered.
- [ ] _Fixtures realistic_: Fixtures match real Lua tables, config shapes, and edge cases.
- [ ] _Deterministic tests_: Tests avoid live network or host-specific paths unless isolated.
- [ ] _CI gates_: Lint and tests run in CI with documented commands.

---

## Repository Structure

- [ ] _Lowercase Lua files_: Lua source file names are lowercase.
- [ ] _TOC layout documented_: The add-on TOC lists Lua files in the intended load order when WoW add-on code is present.
- [ ] _Tests layout_: Tests live under the repo-documented test directory.
- [ ] _Optional LuaRocks layout_: Library code uses `src/`, `spec/`, and rockspec metadata only when the project follows LuaRocks layout.
- [ ] _Rock metadata_: Rockspec files define dependencies, supported Lua versions, and test commands where applicable.
- [ ] _Ignore files_: Generated rocks, coverage, temp files, and local tool output are ignored.

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

### Summary

- Overall Assessment: Good, Fair, or Needs Work
- Critical Issues: 0
- Important Issues: 2

### Critical Issues

- [ ] Unsafe dynamic execution - File: `src/loader.lua:42`

### Important Improvements

- [ ] TOC-loaded file creates an undocumented global - File: `addon/init.lua:12`
- [ ] Missing `nil, err` handling for file reads - File: `lib/store.lua:88`

### Recommendations

1. Replace dynamic loading with an allowlist of module names.
2. Move shared add-on APIs onto `ns` and document intentional WoW globals in `.luacheckrc`.
3. Add `luacheck` and Busted commands to CI.
```

---
