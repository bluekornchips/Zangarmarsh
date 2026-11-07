---
name: blue-review-typescript
description: JavaScript and TypeScript Repository Review Criteria
disable-model-invocation: true
---

# JavaScript and TypeScript Repository Review Criteria

## Overview

Pragmatic review criteria for JavaScript and TypeScript repositories. Focus on security, correctness, reliability, and maintainability at scale.

Items marked with `[TS]` apply only to TypeScript projects.

---

## Critical Security Must Fix

- [ ] _No secrets in repo_: Store secrets in a vault or CI secrets, never in commits
- [ ] _No unsafe dynamic execution_: Avoid `eval`, `Function`, and dynamic imports from untrusted input
- [ ] _Input validation_: Validate and sanitize all external inputs at trust boundaries
- [ ] _XSS prevention_: Use output encoding, safe templating, and a strict Content Security Policy where applicable
- [ ] _CSRF protection_: Use CSRF tokens or SameSite cookies for state-changing requests
- [ ] _Auth and authz enforced server-side_: Never rely on client checks for authorization
- [ ] _SSRF safeguards_: Use URL allowlists, IP range checks, and strict URL parsing
- [ ] _Sensitive data handling_: Redact PII in logs, encrypt it at rest, and use TLS in transit
- [ ] _Dependency risk controls_: Check in lockfiles, verify integrity, and address `npm audit` issues

---

## Error Handling and Reliability Must Fix

- [ ] _No swallowed errors_: Surface errors or log them with context
- [ ] _Promise handling_: No floating promises or unhandled rejections
- [ ] _Timeouts and retries_: External calls use timeouts, retries with backoff, and jitter
- [ ] _Graceful shutdown_: Servers handle SIGTERM and close resources cleanly
- [ ] _Error boundaries_: UI apps use error boundaries and fallback UI
- [ ] _Consistent error shape_: Return errors in a consistent format with safe messages

---

## Type Safety and Runtime Validation

- [ ] _TypeScript strict mode_: `[TS]` Set `strict: true` in `tsconfig.json`
- [ ] _No `any` without justification_: `[TS]` Justify every `any` explicitly or refactor it
- [ ] _Narrowing for `unknown`_: `[TS]` External data starts as `unknown` and is narrowed safely
- [ ] _Runtime schema validation_: Use schemas for untrusted inputs and API payloads
- [ ] _No unsafe assertions_: `[TS]` Avoid `as` casts unless runtime checks verify them

---

## Secure API and Data Handling

- [ ] _Least privilege_: Tokens and service accounts have minimal scopes
- [ ] _PII minimization_: Collect only required fields and document retention
- [ ] _Data access auditing_: Log access to sensitive records so it is auditable
- [ ] _Rate limiting_: Apply per-user or per-IP limits on sensitive endpoints
- [ ] _Idempotency_: Write endpoints include idempotency where relevant

---

## Code Structure and Architecture

- [ ] _Layered boundaries_: Separate API, domain, and data layers clearly
- [ ] _No circular deps_: The module graph is acyclic and enforced via tooling
- [ ] _Single responsibility_: Functions and classes do one job and are testable
- [ ] _Config isolation_: Runtime config is centralized, validated, and immutable
- [ ] _Feature flags_: Gate risky changes so they can be rolled back

---

## Linting, Formatting, and Static Analysis

- [ ] _ESLint enforced_: Enable linting with TypeScript or JavaScript rulesets
- [ ] _Prettier or formatter_: Formatting is consistent and automated
- [ ] _No disabled rules_: Document every `eslint-disable` with reason and scope
- [ ] _Type checks in CI_: `[TS]` Run `tsc --noEmit` in CI for TypeScript
- [ ] _SAST tooling_: Run static analysis in CI and track findings

---

## Testing

- [ ] _Unit tests_: Unit tests cover core logic
- [ ] _Integration tests_: Critical workflows are covered end to end
- [ ] _Coverage thresholds_: CI enforces thresholds aligned with risk
- [ ] _Deterministic tests_: Tests are stable and never rely on network
- [ ] _Realistic fixtures_: Test data mirrors production constraints
- [ ] _Test documentation_: README includes test and coverage commands

---

## Build, Release, and Dependency Management

- [ ] _Node version declared_: `"engines": { "node": ">=X" }` in `package.json` documents the required runtime
- [ ] _Reproducible builds_: Lockfiles are present and respected
- [ ] _SBOM generated_: CI produces a software bill of materials
- [ ] _Dependency updates_: Automate patch updates with review gates
- [ ] _CI gates_: CI runs lint, test, typecheck, and security scan

---

## Performance and Observability

- [ ] _Performance budgets_: Enforce bundle size and latency budgets
- [ ] _Structured logging_: Logs are structured, searchable, and PII-safe
- [ ] _Metrics and tracing_: Emit and link request metrics and traces
- [ ] _Client performance_: Monitor Core Web Vitals for front-end apps
- [ ] _Profiling ready_: Document profiling hooks or flags

---

## Accessibility

- [ ] _Semantic HTML_: Use appropriate elements for structure and meaning
- [ ] _Keyboard navigation_: All interactive elements are reachable and operable via keyboard
- [ ] _ARIA labels_: Dynamic content and custom controls have proper ARIA attributes
- [ ] _Color contrast_: Text meets WCAG AA contrast ratios
- [ ] _Screen reader testing_: Test key flows with assistive technology
- [ ] _Focus management_: Focus state is visible and managed correctly on navigation

---

## Documentation

- [ ] _README accuracy_: README matches actual implementation and usage
- [ ] _Architecture overview_: Document high level design and data flow
- [ ] _Runbooks_: Include oncall steps and rollback guidance
- [ ] _Config docs_: Document required env vars and defaults

---

## Repository Structure

- [ ] _Logical layout_: Organize code into `src/`, `tests/`, and `scripts/`
- [ ] _README_: README covers usage, examples, and requirements
- [ ] _LICENSE_: License file is present
- [ ] _.gitignore_: Exclude build output and secrets
- [ ] _Code owners_: Define ownership and review paths

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
## Review: Repository Name - Date

### Critical Issues

- [ ] Unsafe dynamic execution - File: `path/to/file.ts:123`

### Important Improvements

- [ ] Missing runtime schema validation - File: `path/to/handler.ts:88`
```

---
