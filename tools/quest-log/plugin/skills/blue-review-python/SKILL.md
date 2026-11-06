---
name: blue-review-python
description: Python Repository Review Criteria
disable-model-invocation: true
---

# Python Repository Review Criteria

## Overview

Pragmatic review criteria for Python repositories. Enforce `rules/python.mdc`, `skills/blue-python-setup/SKILL.md`, and Google Python Style Guide standards across security, typing, docstrings, imports, errors, logging, configuration, tooling, and tests.

This skill is review criteria only.

---

## Critical Security Must Fix

- [ ] _No secrets in source_: API keys, tokens, passwords, and environment-specific values come from environment variables or injected config, never source literals
- [ ] _No unsafe dynamic execution_: No `eval`, `exec`, `pickle.loads`, or dynamic imports on untrusted input
- [ ] _Input validation_: Public entry points validate external input before doing work
- [ ] _Path safety_: User-supplied paths are normalized, constrained to expected roots, and not used for arbitrary reads or writes
- [ ] _Shell safety_: `subprocess` calls pass argument sequences with `shell=False`, never shell strings built from untrusted input
- [ ] _Safe logging_: Logs do not emit secrets, credentials, or sensitive personal data
- [ ] _Locked dependencies_: `uv.lock` is committed and install or CI paths use `--locked` when the project uses `uv`

---

## Error Handling and Reliability Must Fix

- [ ] _Specific exceptions_: `try` blocks wrap the smallest needed statement range and catch specific exception classes, never bare `except:` or broad `except Exception` on production paths
- [ ] _Exception chaining_: Re-raised or wrapped errors preserve cause with `raise ValueError("...") from exc`
- [ ] _No swallowed errors_: Caught exceptions are re-raised, wrapped, or logged with operation context
- [ ] _No assert for control flow_: `assert` is never used to validate runtime inputs or enforce production invariants
- [ ] _Context managers_: Files, sockets, locks, database sessions, and temporary resources use `with` or `@contextmanager`
- [ ] _Early validation_: Functions check preconditions up front and raise clear errors such as `ValueError("func_name: reason")`

---

## Google Python Style and Language Rules

- [ ] _Google docstrings_: Modules, classes, and every public function or method have `"""..."""` docstrings with a one-line summary, blank line, and `Args:`, `Returns:`, `Yields:`, `Raises:`, or `Attributes:` sections as applicable
- [ ] _Naming conventions_: `module_name`, `package_name`, `ClassName`, `ExceptionName`, `function_name`, `method_name`, `local_var_name`, `GLOBAL_CONSTANT_NAME`, and `_internal_name` follow Google style
- [ ] _Imports order and form_: Imports sit at the top of the file grouped as standard library, third-party, then repository packages, separated by blank lines and sorted lexicographically; no wildcard `from module import *`
- [ ] _Absolute and package-relative imports_: Prefer absolute imports from the project root; single-dot relative imports stay inside one package only when they reduce cycles
- [ ] _Immutable default arguments_: Function signatures use `None` instead of mutable defaults such as `[]` or `{}` and initialize inside the body
- [ ] _Implicit truthiness and None checks_: Identity checks use `is None` or `is not None`; emptiness checks use `if not seq:` unless `0`, `False`, and `None` must be distinguished
- [ ] _Simple comprehensions_: List, dict, and set comprehensions stay single-clause and readable without multiple `for` clauses or complex filters
- [ ] _No global mutable state_: Module-level state is limited to constants and `logger = logging.getLogger(__name__)`; mutable globals are not used as application state
- [ ] _Main guard_: Executable modules guard startup work behind `if __name__ == "__main__": main()` and avoid import-time side effects

---

## Typing and Public Contracts

- [ ] _Public signatures typed_: Public functions, methods, and class attributes declare parameter and return type annotations, including `-> None`
- [ ] _Modern union and builtin generics_: Type annotations prefer builtin generics and `X | None` on Python 3.11 and newer when the target runtime supports them
- [ ] _Narrow type ignores_: Any `# type: ignore[code]` names the specific error code and reason
- [ ] _Strict typing compatibility_: When the repository defines `mypy src/ --strict` or equivalent, modules stay clean under that user-run check
- [ ] _Lighter script typing_: Small standalone scripts may use lighter typing only when the repository does not require full package rigor

---

## Logging and Configuration

- [ ] _Module logger_: Runtime messages use `logging` with `logger = logging.getLogger(__name__)`, never `print`
- [ ] _Structured log calls_: Log calls pass format strings and arguments or structured fields without leaking secrets
- [ ] _Config isolation_: Environment reads and runtime configuration are centralized and validated at startup or boundary helpers
- [ ] _Required environment documented_: Required environment variables fail with a clear error when unset and are listed in project docs

---

## Code Structure and Packaging

- [ ] _Single responsibility_: Functions, classes, and modules have one clear job and stay under 1000 lines
- [ ] _Less code_: No unneeded wrappers, pass-through helpers, feature flags, or extra layers when a direct change works
- [ ] _Package layout_: Application and library packages follow `src/<package_name>/` and `tests/` when the repository uses the standard layout
- [ ] _No stray `__init__.py`_: New `__init__.py` files are added only when the repository already documents that package layout

---

## Linting, Formatting, and Static Analysis

- [ ] _Line length and formatting_: Formatting is consistent with Ruff and the configured line length, 80 under strict Google style or up to 100 when configured in `pyproject.toml`
- [ ] _Ruff lint rules_: Ruff checks cover `E`, `F`, `I`, `B`, `UP`, and `SIM` or the repository's documented rule set
- [ ] _Scoped suppressions_: `# noqa: CODE` suppressions name the exact rule code and stay on the narrowest line
- [ ] _uv workflow_: `pyproject.toml`, `uv.lock`, and thin `Makefile` targets (`install`, `format`, `lint`, `test`, `all`) match the repository workflow

---

## Testing

- [ ] _pytest conventions_: Tests live under `tests/` with `test_*.py`, `Test*`, and `test_*` naming
- [ ] _Happy and failure paths_: Unit tests cover expected inputs, boundary values, default arguments, and `pytest.raises(..., match=...)` error cases
- [ ] _Isolated environment and mocks_: External state and environment variables are isolated with `unittest.mock.patch` or fixtures, with no live network calls
- [ ] _Coverage configured_: Test runs report coverage against `src` when configured in `pyproject.toml`
- [ ] _Documented verification_: `README.md` documents the user-run `uv` and `make` verification commands

---

## Repository Structure

- [ ] _Logical layout_: Source under `src/`, tests under `tests/`, and config in `pyproject.toml`
- [ ] _Python version declared_: `requires-python` in `pyproject.toml` matches `README.md` requirements
- [ ] _Ignore rules_: `.gitignore` excludes `.venv/`, `__pycache__/`, `*.pyc`, `*.pyo`, `.mypy_cache/`, `.pytest_cache/`, `htmlcov/`, `.coverage`, `dist/`, and `*.egg-info/`
- [ ] _README accuracy_: Setup, usage, and development commands match the actual project files

---

## Review Process

### Priority Order

1. _Critical Security_ - Secrets, dynamic execution, shell and path safety, and lockfile integrity
2. _Error Handling and Reliability_ - Specific exceptions, exception chaining, resource cleanup, and `assert` misuse
3. _Google Style and Typing_ - Docstrings, naming, imports, mutable defaults, type annotations, and module state
4. _Logging, Tooling, and Tests_ - `logging` usage, Ruff and mypy cleanliness, and `pytest` coverage of failure modes
5. _Structure and Packaging_ - `src/` layout, unexpected `__init__.py` files, and unnecessary complexity

### Review Output Format

- Use checkboxes for each criterion.
- Cite exact `file:line` locations for every finding.
- Mark priority as Critical, Important, or Enhancement.
- Give concrete fix instructions for the user to apply.

### Example Output

```markdown
## Review: Repository Name - Date

### Summary

- Overall Assessment: Good, Fair, or Needs Work
- Critical Issues: 1
- Important Issues: 2

### Critical Issues

- [ ] Hardcoded API token in source - File: `src/project_name/client.py:18`

### Important Improvements

- [ ] Broad `except Exception` without chaining - File: `src/project_name/store.py:64`
- [ ] Public function missing Google `Args:` and `Raises:` docstring sections - File: `src/project_name/main.py:42`

### Recommendations

1. Read the token from `os.getenv` and raise `ValueError` when missing.
2. Catch the specific exception class and re-raise with `from exc`.
3. Add a Google-style docstring header and full parameter and return type annotations.
```

---
