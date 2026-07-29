# TypeScript and JavaScript Standards

## Purpose

Keep TypeScript strict at the edges so mistakes surface early and types stay honest.

## Priority

- Level 1 of 2

## Standards

- Enable `"strict": true` and `noUncheckedIndexedAccess` in `tsconfig.json` when the project uses TypeScript.
- Named exports for library code. Explicit return types on exported functions, public class methods, and shared types.
- `const` by default, `let` only when reassignment is needed. Use `===` and `!==`.
- `async` and `await` instead of raw `Promise` chains when both are available.
- In `catch`, use `unknown` and narrow before use. Set `cause` on re-throw when the runtime supports it.
- Validate untrusted input at module boundaries. Read config from environment variables or injected config, not literals.
- Run `tsc --noEmit` with zero errors before merge when TypeScript is in use. Keep formatter and linter clean on touched files when the repo defines them.

## Usage

### Allowed

- `interface` for object shapes, `type` for unions and aliases when both read well.
- `readonly` on fields that must not change after construction.
- Discriminated unions instead of large optional bags for mutually exclusive states.
- `satisfies` and `as const` when they tighten inference without widening.
- JSDoc or TSDoc on exports when contracts, errors, or units are not obvious.
- `Promise.all` for independent concurrent work with rejection handling on work you start.

### Denied

- The `any` type.
- `@ts-ignore` or `@ts-nocheck`.
- Non-null `value!` without a short nearby comment that states the invariant.
- Type assertions such as `value as unknown as T` to silence the compiler.
- `var`.
- Hardcoded secrets.
- `eval` on dynamic input.
- Mutating function parameters.
- `console.log` on production paths.
- Silent catches such as `catch (_) {}`.

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
