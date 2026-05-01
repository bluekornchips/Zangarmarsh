# Lua Standards

Keywords when this doc applies: lua, luajit, luarocks, rockspec, luacheck, busted

## Purpose

Keep Lua code small, local by default, easy to scan, and aligned with sensible Lua habits. Retail WoW add-on code often loads through a TOC, so some strict LuaRocks module rules do not apply to those chunks.

## Priority

- Level 1 of 2

## WoW Lua style choices

These rules apply to Lua files loaded by a WoW add-on TOC and to Lua tests that exercise those files. They are style choices for WoW Lua, not strict rules for every Lua ecosystem.

- Use `local _, ns = ...` at the top of each TOC chunk. Shared public APIs live on `ns`.
- Public functions on `ns` use `PascalCase`. Keep that convention for shared APIs so calls are easy to spot beside local helpers.
- TOC-loaded files may register frames, events, and slash commands at load time. That is normal for WoW add-ons.
- Addon-specific saved variables, `SLASH_*`, and `SlashCmdList` entries belong in `.luacheckrc` when used.
- Use `2 spaces` for indentation in WoW add-on Lua files and Lua tests. Do not use tabs or mixed tab and space indent.

## Standards, general Lua

- Use LF line endings and one statement per line. Do not use semicolons as statement terminators.
- Use `snake_case` for local variables and local helpers when they are not part of the public `ns` API. Use `CamelCase` for class-style tables when they are the class table.
- Always declare variables with `local`. Keep each variable in the smallest useful scope.
- Prefer `local function name(...)` for named local functions. For `ns` APIs, use `function ns.Name(...)` when that matches existing public names.
- Validate early and return early. For expected failures, return `nil` plus an error string and optional code. For API misuse, use `error()` or `assert()`.
- Use LDoc comments for public functions and modules when names and signatures are not enough.
- Require modules into local variables named after the last module path component.
- Test-only library modules that ship only through `require` should `return` a table and avoid globals and side effects beyond loading dependencies. TOC-loaded add-on files are exempt, see WoW section above.
- Prefer tables populated all at once, use trailing commas in multiline tables, and use plain key syntax when the key is a valid identifier.
- Use double quotes for strings. Use single quotes only when the string contains double quotes.
- Run `luacheck` when the repo uses it. Add a `.luacheckrc` for intentional exceptions.

## Usage

### Allowed

- `TODO` for missing future work and `FIXME` for known problems in existing code.
- `_` for ignored variables and small iterator scopes.
- `i` only for numeric counters or `ipairs` loops.
- Dot notation for known table fields and subscript notation for dynamic keys or list access.
- Omit function call parentheses only for multiline table constructor arguments used as a standalone call.
- The `and` and `or` idiom when the middle value cannot be `nil` or `false` and the expression stays simple.
- Type-checking assertions in non-performance critical code when they make API contracts clearer.
- Metamethod functions inside a metatable declaration so behavior is visible at a glance.

### Denied

- Implicit globals except documented WoW and saved-variable patterns in `.luacheckrc`.
- Uppercase names starting with `_`, since Lua reserves them.
- Arbitrary module aliases such as `local skt = require("socket")`.
- `require "module"` syntax. Use `require("module")`.
- Omitting parentheses for string literal function calls.
- Aligning variable declarations only for visual columns.
- APIs that depend on callers knowing the difference between `nil` and `false`.
- Single-line blocks except `then return`, `then break`, and one-line callback returns.
- Relying on `__gc` to close files, sockets, handles, or other non-memory resources.
- Side effects when requiring a `pure` test or library module, including configuration changes or global writes. TOC-loaded add-on files are exempt.

## Example

```lua
local _, ns = ...

local function normalize_message(message)
  assert(type(message) == "string")

  if message == "" then
    return nil, "normalize_message: message is required"
  end

  return message
end

--- Send a namespaced add-on message.
-- @param message string: Message to send.
-- @return boolean or nil: True on success.
-- @return string: Error message on failure.
function ns.SendMessage(message)
  local normalized, err = normalize_message(message)
  if not normalized then
    return nil, err
  end

  print(normalized)
  return true
end
```
