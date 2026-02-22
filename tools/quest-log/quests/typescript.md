# TypeScript and JavaScript Standards

## Priority

- Level 1 of 2

## Critical Violations, Code Will Be Rejected

### Never Use, Immediate Rejection

- `any` type
- `@ts-ignore` or `@ts-nocheck`
- Non-null assertions without a justifying comment: `value!`
- Type assertions to silence the compiler: `value as unknown as T`
- `var` declarations
- `==` or `!=` for equality
- Hardcoded secrets
- `eval()` with dynamic input
- Callback-based async when `async/await` is available
- Mutating function arguments
- `console.log` in production code
- Silent catch blocks: `catch (_) {}`

## Mandatory Requirements, All Code Must Have

### Always Use, Non-Negotiable

- `"strict": true` and `noUncheckedIndexedAccess` in `tsconfig.json`
- Explicit return types on exported functions and public class methods
- Named exports over default exports
- `const` by default, `let` only when reassignment is required
- `async/await` over raw Promise chains
- `catch (err: unknown)`, narrow before use
- Input validation at all module boundaries
- Environment variables for configuration
- Domain-specific error classes extending `Error`
- JSDoc on all exported functions, classes, and types

### Code Quality Requirements

- `tsc --noEmit` with zero errors before committing
- Linter with zero warnings on staged files
- Formatter clean before committing
- 90 percent coverage or higher on production modules and shared libraries

## Best Practices

### Naming

- `PascalCase` for classes, interfaces, type aliases, and enums
- `camelCase` for variables, functions, and methods
- `SCREAMING_SNAKE_CASE` for module-level constants
- `is`, `has`, or `can` prefix for boolean functions: `isReady()`

### Types

- `interface` for object shapes, `type` for unions and aliases
- `readonly` on properties that must not be reassigned
- Discriminated unions over optional fields for mutually exclusive states
- `satisfies` to validate literals without widening
- Prefer `as const` object maps over `enum`

### Functions

- Small and single-purpose
- Destructure parameters when taking more than two arguments
- Prefer pure functions; isolate side effects at module edges
- Default parameter values over conditional assignments inside the body
- Never mutate arguments, return new values

### Modules

- One primary export per file
- Imports ordered: external packages, internal absolute, relative
- Avoid circular dependencies; move shared types into a dedicated module

### Error Handling

- Set `cause` when re-throwing: `throw new AppError("msg", { cause: err })`
- Handle once, never log and re-throw the same error
- Throw for unexpected errors, return results for expected failures

### Async

- Await all Promises; document any intentional fire-and-forget
- `Promise.all` for concurrent independent operations
- Always handle rejections
- Set explicit timeouts on network and external I/O calls

## Testing

- Prefix tests with the unit under test: `describe("parsePort", ...)`
- Test behavior, not implementation details
- Use factories for test fixtures, not duplicated object literals
- Mock at module boundaries
- Assert on error type or code, not message strings
- Keep unit and integration tests separate

## Example

```typescript
class PortError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = 'PortError';
  }
}

/**
 * Parses a string into a valid TCP port number.
 * @throws {PortError} When the value is missing, not an integer, or out of range.
 */
export function parsePort(value: string): number {
  if (value === '') {
    throw new PortError('parsePort: value is required');
  }

  const port = Number(value);

  if (!Number.isInteger(port)) {
    throw new PortError(`parsePort: invalid integer "${value}"`);
  }

  if (port < 1 || port > 65535) {
    throw new PortError(`parsePort: out of range (${port})`);
  }

  return port;
}
```
