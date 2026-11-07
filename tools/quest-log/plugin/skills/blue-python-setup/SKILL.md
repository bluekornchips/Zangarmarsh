---
name: blue-python-setup
description: Python Project Setup
disable-model-invocation: true
---

# Python Project Setup

User reference for a small Python project that follows `rules/python.mdc` after `questlog` installs this plugin. Use `uv` for project creation, dependencies, virtual environments, and lock files.

Writing and editing Python are allowed. Running Python requires explicit user approval for the named command.

## Layout

```text
project-name/
├── src/project_name/main.py
├── tests/test_main.py
├── .gitignore
├── Makefile
├── pyproject.toml
└── README.md
```

## 1. Create the project

```bash
uv init --package project-name
cd project-name
uv add --dev ruff pytest pytest-cov
uv lock
```

For an existing project, keep its build backend and run only the last two commands. Keep `uv.lock` in version control and use `--locked` in CI. Add `mypy` with `uv add --dev mypy` when strict typing is needed.

Declare a supported range in `pyproject.toml`, for example `requires-python = ">=3.11"`, and add:

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "SIM"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["--cov=src", "--cov-report=term-missing", "-v"]
```

## 2. Create `src/project_name/main.py`

```python
"""Minimal module showing typing, docstrings, logging, and env validation."""

import logging
import os

logger = logging.getLogger(__name__)


def get_api_key() -> str:
    """Read the API key from the environment.

    Returns:
        The API_KEY value.

    Raises:
        ValueError: If API_KEY is not set.
    """
    api_key = os.getenv("API_KEY")
    if api_key is None:
        raise ValueError("API_KEY environment variable is not set")
    logger.info("API key loaded")
    return api_key


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    get_api_key()


if __name__ == "__main__":
    main()
```

## 3. Create `tests/test_main.py`

```python
"""Tests for main module."""

import pytest

from project_name.main import get_api_key


def test_get_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    """Return the key when API_KEY is set, raise ValueError when it is not."""
    monkeypatch.setenv("API_KEY", "test-key")
    assert get_api_key() == "test-key"
    monkeypatch.delenv("API_KEY")
    with pytest.raises(ValueError, match="API_KEY"):
        get_api_key()
```

## 4. Create `Makefile`

```makefile
.PHONY: install format lint test all

install:
	uv sync

format:
	uv run ruff format src/ tests/

lint:
	uv run ruff check src/ tests/

test:
	uv run pytest

all: format lint test
```

## 5. Create `.gitignore`

```gitignore
.venv/
__pycache__/
.mypy_cache/
.pytest_cache/
.coverage
dist/
*.egg-info/
```

## 6. Create `README.md`

````markdown
# project-name

Brief description of the project.

## Setup

```bash
make install
```

## Development

```bash
make all
```
````

## Verification

```bash
uv sync --locked
make all
```

Without `uv`, stop and document that requirement. Do not add another installer path.
