# Python Standards

## Purpose

Base level structure for Python for types, failures, and boundaries.

## Priority

- Level 1 of 2

## Standards

- Catch specific exception types. Re-raise or wrap when callers need a higher-level error.
- Use `logging` with `logger = logging.getLogger(__name__)` instead of `print` for runtime messages.
- Use context managers for files, sockets, locks, and other scoped resources.
- Type hints on public functions and at module boundaries. Add docstrings when names and types are not enough.
- Read secrets and environment-specific values from environment variables or injected config, not literals in source.

## Usage

### Allowed

- Absolute imports from the project root when the tree supports them. Relative imports inside one package when they reduce cycles.
- `pytest --cov=src --cov-fail-under=90` and `mypy src/ --strict` on production code under `src/` when the project already uses them.
- Targeted tests and lighter typing on small scripts when the repo does not require full package rigor.

### Denied

- Broad `except Exception`, bare `except:`, or `assert` for control flow in production paths.
- `eval` or `exec` on untrusted input.
- Wildcard imports such as `from module import *`.
- Hardcoded secrets or API tokens.
- Mutable default arguments such as `def f(x=[]):`.
- Global mutable state as the main application state store.
- New `__init__.py` files unless the repo already documents that layout.

## Example

```python
import logging

logger = logging.getLogger(__name__)


def read_port(value: str) -> int:
    if value == "":
        raise ValueError("read_port: value is required")

    try:
        port = int(value)
    except ValueError as exc:
        raise ValueError("read_port: invalid int") from exc

    if port < 1 or port > 65535:
        raise ValueError("read_port: out of range")

    logger.info("read_port: parsed port %s", port)

    return port
```
