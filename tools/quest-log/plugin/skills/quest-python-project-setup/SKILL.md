---
name: quest-python-project-setup
description: Python Project Setup
disable-model-invocation: true
---

# Python Project Setup

User reference for creating a small Python project that follows the Python
coding standards in `rules/python.mdc` after `questlog` installs this plugin.
Use `uv` for project creation, dependency resolution, virtual environments, and
lock files. Require `uv` for dependency installation.

This skill does not authorize the agent to write or execute Python.

## Project Structure

Create the following directory structure:

```text
project-name/
├── src/
│   └── project_name/
│       └── main.py
├── tests/
│   └── test_main.py
├── .gitignore
├── Makefile
├── pyproject.toml
└── README.md
```

## Step-by-Step Setup

### 1. Create Project Directory Structure

```bash
mkdir -p project-name/src/project_name
mkdir -p project-name/tests
cd project-name
```

### 2. Create the project with `uv`

For a new application or library, start with:

```bash
uv init --package project-name
cd project-name
uv add --dev ruff pytest pytest-cov
uv lock
```

For an existing project, preserve its build backend and add the tools with:

```bash
uv add --dev ruff pytest pytest-cov
uv lock
```

Keep `uv.lock` in version control for applications and reproducible
development environments. Use `--locked` in CI.

If the project needs strict static typing, add mypy separately:

```bash
uv add --dev mypy
```

The project should declare a supported Python range in `pyproject.toml`, for
example `requires-python = ">=3.11"`.

Recommended tool configuration:

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "SIM"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = ["--cov=src", "--cov-report=term-missing", "-v"]
```

### 3. Create `src/project_name/main.py`

This file demonstrates all mandatory requirements:

```python
"""Main module demonstrating Python coding standards."""

import logging
import os
from collections.abc import Generator
from contextlib import contextmanager

# Configure logging (never use print for debugging)
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)


@contextmanager
def example_context_manager() -> Generator[None, None, None]:
    """Example context manager for resource management."""
    logger.info("Entering context")
    try:
        yield
    finally:
        logger.info("Exiting context")


def validate_input(value: int) -> None:
    """Validate input parameter.

    Args:
        value: Integer value to validate.

    Raises:
        ValueError: If value is negative.
    """
    if value < 0:
        raise ValueError(f"Value must be non-negative, got {value}")


def example_function(items: list[str] | None = None) -> list[str]:
    """Example function demonstrating proper practices.

    Uses immutable default arguments, type hints, and proper error handling.

    Args:
        items: Optional list of strings. Defaults to None.

    Returns:
        List of strings.

    Raises:
        ValueError: If items contains invalid data.
    """
    if items is None:
        items = []

    if not isinstance(items, list):
        raise ValueError(f"Expected list, got {type(items)}")

    try:
        result = [item.upper() for item in items]
        logger.info(f"Processed {len(result)} items")
        return result
    except AttributeError as e:
        logger.error(f"Invalid item type in list: {e}")
        raise ValueError("All items must be strings") from e


def get_api_key() -> str:
    """Get API key from environment variable.

    Returns:
        API key string.

    Raises:
        ValueError: If API_KEY environment variable is not set.
    """
    api_key = os.getenv("API_KEY")
    if api_key is None:
        raise ValueError("API_KEY environment variable is not set")
    return api_key


def main() -> None:
    """Main entry point."""
    logger.info("Application started")

    with example_context_manager():
        try:
            result = example_function(["hello", "world"])
            logger.info(f"Result: {result}")
        except ValueError as e:
            logger.error(f"Error processing items: {e}")


if __name__ == "__main__":
    main()
```

### 4. Create `tests/test_main.py`

```python
"""Tests for main module."""

import os
import pytest
from unittest.mock import patch

from project_name.main import (
    example_function,
    get_api_key,
    validate_input,
)


def test_example_function_with_items() -> None:
    """Test example_function with provided items."""
    result = example_function(["hello", "world"])
    assert result == ["HELLO", "WORLD"]


def test_example_function_with_none() -> None:
    """Test example_function with None (default argument)."""
    result = example_function()
    assert result == []


def test_example_function_with_empty_list() -> None:
    """Test example_function with empty list."""
    result = example_function([])
    assert result == []


def test_example_function_raises_value_error_for_invalid_type() -> None:
    """Test example_function raises ValueError for invalid input type."""
    with pytest.raises(ValueError, match="Expected list"):
        example_function("not a list")  # type: ignore[arg-type]


def test_example_function_raises_value_error_for_non_string_items() -> None:
    """Test example_function raises ValueError for non-string items."""
    with pytest.raises(ValueError, match="All items must be strings"):
        example_function([123, 456])  # type: ignore[list-item]


def test_get_api_key_success() -> None:
    """Test get_api_key retrieves API key from environment."""
    with patch.dict(os.environ, {"API_KEY": "test-key-123"}):
        result = get_api_key()
        assert result == "test-key-123"


def test_get_api_key_raises_value_error_when_missing() -> None:
    """Test get_api_key raises ValueError when API_KEY is not set."""
    with patch.dict(os.environ, {}, clear=True):
        with pytest.raises(ValueError, match="API_KEY environment variable is not set"):
            get_api_key()


def test_validate_input_success() -> None:
    """Test validate_input accepts non-negative values."""
    validate_input(0)
    validate_input(1)
    validate_input(100)


def test_validate_input_raises_value_error_for_negative() -> None:
    """Test validate_input raises ValueError for negative values."""
    with pytest.raises(ValueError, match="Value must be non-negative"):
        validate_input(-1)
```

### 5. Create `Makefile`

If a project wants a Makefile, keep it as a thin wrapper around `uv`:

```makefile
.PHONY: install format lint typecheck test all

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

### 6. Create `.gitignore`

```gitignore
.venv/
__pycache__/
*.pyc
*.pyo
.mypy_cache/
.pytest_cache/
htmlcov/
.coverage
dist/
*.egg-info/
```

### 7. Create `README.md`

````markdown
# project-name

Brief description of the project.

## Requirements

- Python 3.11 or greater

## Setup

```bash
make install
```
````

## Usage

```bash
source .venv/bin/activate
python -m project_name.main
```

## Development

```bash
make format   # Format with Ruff
make lint     # Lint with Ruff
make test     # Run tests with coverage
make all      # Run all of the above
```

````

## Verification Commands

After setup, run these commands to verify everything works:

```bash
# Create the environment and install locked dependencies
uv sync --locked

# Format code with Ruff
uv run ruff format src/ tests/

# Lint code with Ruff
uv run ruff check src/ tests/

# Type check with mypy when configured
uv run mypy src/

# Run tests with coverage
uv run pytest

# Or run all formatting, linting, typing, and tests
make all
````

For projects that cannot use `uv`, stop and document that requirement rather
than adding another installer path:

```bash
# Install uv, then use the locked project environment
curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync --locked
uv run pytest
```

All commands should pass without errors.
