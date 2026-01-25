# TypeScript Standards

## Priority

- Level 1 of 2

## Critical Violations, Code Will Be Rejected

### Never Use, Immediate Rejection

- `any` in production code
- `@ts-ignore` or `@ts-nocheck`
- `as any` or double assertions
- Non null assertion operator `!`
- `eval` or `Function` constructor
- `require` in module code
- `// eslint-disable` without a tracked issue

## Mandatory Requirements, All Code Must Have

### Always Use, Non Negotiable

- `tsconfig.json` with `strict`, `noImplicitAny`, `strictNullChecks`, and `noUncheckedIndexedAccess`
- `eslint` with TypeScript rules and `prettier` formatting
- Explicit return types for exported functions and public class methods
- Input validation for all boundary functions, use `unknown` and narrow types
- Error handling with typed errors and `catch (err: unknown)`
- `const` and `readonly` to prevent mutation
- Absolute imports from a project root alias when configured, otherwise use relative imports within the package

### Code Quality Requirements

- Production modules and shared libraries must reach coverage 90 percent or higher with `vitest --coverage` or `jest --coverage`
- Run `tsc --noEmit` and `eslint .` in CI for every change
- Run dependency and license scans in CI, and keep lockfiles up to date

## Best Practices

- Prefer named exports, avoid default exports
- Use `interface` for object shapes and `type` for unions and primitives
- Use `PascalCase` for type names, `camelCase` for values, and `UPPER_CASE` for constants
- Keep files focused with one primary export per file
- Use function components and hooks for React code
- Keep components pure and avoid side effects
- Type props and state with explicit interfaces
- Use memoization only for proven performance issues
- Centralize error handling and logging with typed error classes
- Enforce module boundaries with lint rules
- Prefer immutable data structures and avoid shared mutable state

## Example

```ts
export class InputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InputError';
  }
}

export function readPort(value: string): number {
  if (value === '') {
    throw new InputError('readPort: value is required');
  }

  const port = Number(value);
  if (!Number.isInteger(port)) {
    throw new InputError('readPort: invalid int');
  }

  if (port < 1 || port > 65535) {
    throw new InputError('readPort: out of range');
  }

  return port;
}
```
