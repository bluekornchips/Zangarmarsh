# Python Standards

## Never Use

- Broad exceptions: `except Exception as e:`
- Hardcoded secrets: `api_key = "sk-abc123"`
- Wildcard imports: `from .utils import *`
- Print debugging: `print("Debug info")`
- Production assertions: `assert False`

## Always Use

- Specific exceptions: `except ValueError as e:`
- Environment variables: `api_key = os.getenv("API_KEY")`
- Absolute imports: `from myproject.utils import parse_data`
- Proper logging: `logger.info("Process started")`
- Type hints and docstrings

## Requirements

- Test coverage ≥90%: `pytest --cov=src --cov-fail-under=90`
- Type safety: `mypy src/ --strict`
- Security: `bandit -r src/ -ll`
- Formatting: `ruff format src/`
- Linting: `ruff check src/`
