# Python Standards

## Critical Violations, Code Will Be Rejected

### Never Use, Immediate Rejection

- Broad exceptions: `except Exception as e:`
- Hardcoded secrets: `api_key = "sk-abc123"`
- Wildcard imports: `from .utils import *`
- Print debugging: `print("Debug info")`
- Production assertions: `assert False`
- Bare `except:` clauses
- `eval()` or `exec()` with user input
- Mutable default arguments: `def func(items=[]):`
- Global variables for state management
- `__init__.py` files

## Mandatory Requirements, All Code Must Have

### Always Use, Non-Negotiable

- Specific exceptions: `except ValueError as e:`
- Environment variables: `api_key = os.getenv("API_KEY")`
- Absolute imports: `from myproject.utils import parse_data`
- Proper logging: `logger.info("Process started")`
- Type hints and docstrings
- Input validation for all functions
- Proper error handling with specific exceptions
- Context managers for resource management

### Code Quality Requirements

- Production modules and shared libraries must reach coverage 90 percent or higher with `pytest --cov=src --cov-fail-under=90`
- Run `mypy src/ --strict` on production modules and shared libraries
- For scripts, add type hints and targeted tests when practical

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

## Enforcement Level, Strict

- Python code without type hints will be rejected
- Functions without proper error handling will be rejected
- Code with security vulnerabilities will be rejected
- Missing tests for critical functions will be rejected
