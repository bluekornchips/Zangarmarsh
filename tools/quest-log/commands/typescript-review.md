# JavaScript and TypeScript Repository Review Criteria

## Overview

Pragmatic review criteria for JavaScript and TypeScript repositories. Focus on security, correctness, reliability, and maintainability at scale.

Items marked with `[TS]` apply only to TypeScript projects.

---

## Critical Security (Must Fix)

- [ ] _No secrets in repo_: Secrets are stored in a vault or CI secrets, never committed
- [ ] _No unsafe dynamic execution_: Avoid `eval`, `Function`, and dynamic imports from untrusted input
- [ ] _Input validation_: All external inputs validated and sanitized at trust boundaries
- [ ] _XSS prevention_: Output encoding, safe templating, and strict Content Security Policy where applicable
- [ ] _CSRF protection_: CSRF tokens or SameSite cookies for state-changing requests
- [ ] _Auth and authz enforced server-side_: Never rely on client checks for authorization
- [ ] _SSRF safeguards_: URL allowlists, IP range checks, and strict URL parsing
- [ ] _Sensitive data handling_: PII redacted in logs, encrypted at rest, and TLS in transit
- [ ] _Dependency risk controls_: Lockfiles checked in, integrity verified, `npm audit` issues addressed

---

## Error Handling and Reliability (Must Fix)

- [ ] _No swallowed errors_: Errors are surfaced or logged with context
- [ ] _Promise handling_: No floating promises or unhandled rejections
- [ ] _Timeouts and retries_: External calls use timeouts, retries with backoff, and jitter
- [ ] _Graceful shutdown_: Servers handle SIGTERM and close resources cleanly
- [ ] _Error boundaries_: UI apps use error boundaries and fallback UI
- [ ] _Consistent error shape_: Errors returned in a consistent format with safe messages

---

## Type Safety and Runtime Validation

- [ ] _TypeScript strict mode_: `[TS]` `strict: true` in `tsconfig.json`
- [ ] _No `any` without justification_: `[TS]` `any` requires explicit justification or refactor
- [ ] _Narrowing for `unknown`_: `[TS]` External data starts as `unknown` and is narrowed safely
- [ ] _Runtime schema validation_: Use schemas for untrusted inputs and API payloads
- [ ] _No unsafe assertions_: `[TS]` Avoid `as` casts unless verified by runtime checks
- [ ] _Versioned types_: `[TS]` Public APIs use versioned types for backward compatibility

---

## Secure API and Data Handling

- [ ] _Least privilege_: Tokens and service accounts have minimal scopes
- [ ] _PII minimization_: Collect only required fields and document retention
- [ ] _Data access auditing_: Access to sensitive records is logged and auditable
- [ ] _Rate limiting_: Apply per-user or per-IP limits on sensitive endpoints
- [ ] _Idempotency_: Write endpoints include idempotency where relevant

---

## Code Structure and Architecture

- [ ] _Layered boundaries_: Clear separation between API, domain, and data layers
- [ ] _No circular deps_: Module graph is acyclic, enforced via tooling
- [ ] _Single responsibility_: Functions and classes do one job and are testable
- [ ] _Config isolation_: Runtime config is centralized, validated, and immutable
- [ ] _Feature flags_: Risky changes are gated and can be rolled back

---

## Linting, Formatting, and Static Analysis

- [ ] _ESLint enforced_: Linting enabled with TypeScript or JavaScript rulesets
- [ ] _Prettier or formatter_: Formatting is consistent and automated
- [ ] _No disabled rules_: `eslint-disable` is documented with reason and scope
- [ ] _Type checks in CI_: `[TS]` `tsc --noEmit` runs in CI for TypeScript
- [ ] _SAST tooling_: Static analysis runs in CI with findings tracked

---

## Testing

- [ ] _Unit tests_: Core logic covered by unit tests
- [ ] _Integration tests_: Critical workflows covered end to end
- [ ] _Coverage thresholds_: Enforced by CI and aligned with risk
- [ ] _Deterministic tests_: Tests are stable and do not rely on network
- [ ] _Realistic fixtures_: Test data mirrors production constraints
- [ ] _Test documentation_: README includes test and coverage commands

---

## Build, Release, and Dependency Management

- [ ] _Reproducible builds_: Lockfiles are present and respected
- [ ] _SBOM generated_: Software bill of materials produced in CI
- [ ] _Dependency updates_: Automated patch updates with review gates
- [ ] _Release tagging_: Releases are tagged and changelog maintained
- [ ] _CI gates_: Lint, test, typecheck, and security scan in CI

---

## Performance and Observability

- [ ] _Performance budgets_: Bundle size and latency budgets enforced
- [ ] _Structured logging_: Logs are structured, searchable, and PII-safe
- [ ] _Metrics and tracing_: Request metrics and traces are emitted and linked
- [ ] _Client performance_: Core Web Vitals monitored for front-end apps
- [ ] _Profiling ready_: Profiling hooks or flags are documented

---

## Accessibility

- [ ] _Semantic HTML_: Use appropriate elements for structure and meaning
- [ ] _Keyboard navigation_: All interactive elements reachable and operable via keyboard
- [ ] _ARIA labels_: Dynamic content and custom controls have proper ARIA attributes
- [ ] _Color contrast_: Text meets WCAG AA contrast ratios
- [ ] _Screen reader testing_: Key flows tested with assistive technology
- [ ] _Focus management_: Focus state visible and managed correctly on navigation

---

## Documentation

- [ ] _README accuracy_: README matches actual implementation and usage
- [ ] _Architecture overview_: High level design and data flow documented
- [ ] _Runbooks_: Oncall steps and rollback guidance included
- [ ] _Config docs_: Required env vars and defaults documented

---

## Repository Structure

- [ ] _Logical layout_: Code organized into `src/`, `tests/`, `scripts/`
- [ ] _LICENSE_: License file present
- [ ] _.gitignore_: Build output and secrets excluded
- [ ] _Code owners_: Ownership and review paths defined

---

## Review Process

### Priority Order

1. _Critical Security_ - Secrets, injection, authz, and data protection issues
2. _Error Handling and Reliability_ - Unhandled errors and missing fallbacks
3. _Type Safety and Validation_ - Unsafe typing and missing runtime checks
4. _Testing and CI_ - Coverage gaps and missing gates
5. _Code Quality_ - Structure, readability, and maintainability

### Review Output Format

- Use checkboxes for each criterion
- Document specific `file:line` references for issues
- Mark priority: Critical/Important/Enhancement
- Provide actionable fix suggestions

### Example Output

```markdown
## Review: [Repository Name] - [Date]

### Summary

- Overall Assessment: [Good or Fair or Needs Work]
- Critical Issues: [Count]
- Important Issues: [Count]

### Critical Issues

- [ ] Unsafe dynamic execution - File: `path/to/file.ts:123`
- [ ] Missing input validation - File: `path/to/api.ts:45`

### Important Improvements

- [ ] Missing runtime schema validation - File: `path/to/handler.ts:88`

### Recommendations

1. Add runtime schema validation for external inputs
2. Enforce strict TypeScript settings in CI
```

---
