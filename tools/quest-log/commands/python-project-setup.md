# Python Project Setup

Create a barebones Python project that explicitly follows the Python coding standards defined in `.cursor/rules/rules-python.mdc`.

## Project Structure

Create the following directory structure:

```
project-name/
├── src/
│   └── project_name/
│       └── main.py
├── tests/
│   └── test_main.py
├── Makefile
└── pyproject.toml
```

## Step-by-Step Setup

### 1. Create Project Directory Structure

```bash
mkdir -p project-name/src/project_name
mkdir -p project-name/tests
cd project-name
```

### 2. Create `pyproject.toml`

This file configures the required tools: black, isort, mypy, and pytest.

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "project-name"
version = "0.1.0"
description = "A Python project following strict coding standards"
requires-python = ">=3.10"
dependencies = []

[project.optional-dependencies]
dev = [
    "black>=23.0.0",
    "isort>=5.12.0",
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "mypy>=1.0.0",
]

[tool.black]
line-length = 80
target-version = ["py310"]

[tool.isort]
profile = "black"
line_length = 80

[tool.mypy]
python_version = "3.10"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = [
    "--cov=src",
    "--cov-report=term-missing",
    "--cov-report=html",
    "--cov-fail-under=90",
    "-v",
]
```

### 3. Create `src/project_name/main.py`

This file demonstrates all mandatory requirements:

```python
"""Main module demonstrating Python coding standards."""

import logging
import os
from contextlib import contextmanager
from typing import Any

# Configure logging (never use print for debugging)
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)


@contextmanager
def example_context_manager() -> Any:
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

    # Input validation
    if not isinstance(items, list):
        raise ValueError(f"Expected list, got {type(items)}")

    # Specific exception handling
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

    # Example usage
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

Create a `Makefile` with targets for virtual environment setup, formatting, import sorting, and testing:

```makefile
.PHONY: venv install format lint test all

VENV = .venv
PYTHON = $(VENV)/bin/python
PIP = $(VENV)/bin/pip

venv:
	python3 -m venv $(VENV)

install: venv
	$(PIP) install -e ".[dev]"

format:
	$(VENV)/bin/black src/ tests/

lint:
	$(VENV)/bin/isort src/ tests/

test:
	$(VENV)/bin/pytest

all: format lint test
```

## Verification Commands

After setup, run these commands to verify everything works:

```bash
# Create virtual environment and install dependencies
make install

# Format code with black
make format

# Sort imports with isort
make lint

# Run tests with coverage
make test

# Or run all formatting, linting, and tests
make all

# Type check (requires venv to be activated or use full path)
.venv/bin/mypy src/
```

Alternatively, activate the virtual environment and run commands directly:

```bash
# Activate virtual environment
source .venv/bin/activate

# Then run commands directly
black src/ tests/
isort src/ tests/
mypy src/
pytest
```

All commands should pass without errors.
