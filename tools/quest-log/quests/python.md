# Python Standards

## Core Rules

### Never Use

```python
# Never
except Exception as e:  # Too broad
api_key = "sk-abc123"  # Hardcoded secrets
from .utils import *  # Wildcard imports
print("Debug info")  # Console output for debugging
assert False, "This should not happen"  # Assertions in production
```

### Always Use

```python
# Always
except ValueError as e:  # Specific exceptions
api_key = os.getenv("API_KEY")  # Environment variables
from myproject.utils import parse_data  # Absolute imports
logger.info("Process started")  # Proper logging
raise ValueError("Invalid input")  # Meaningful error messages
```

## Requirements

- Test coverage ≥90%: `pytest --cov=src --cov-fail-under=90`
- 100% test pass rate: `pytest -x --tb=short`
- Type safety: `mypy src/ --strict`
- Security scan: `bandit -r src/ -ll`
- Code formatting: `ruff format src/`
- Linting: `ruff check src/`

## Import Standards

```python
# Standard library imports
import os
import logging
from pathlib import Path
from typing import List, Dict, Optional

# Third-party imports
import requests
from fastapi import FastAPI

# Local imports
from .models import User
from .utils import validate_email
```

## Function Standards

```python
def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two geographic points.

    Args:
        lat1: Latitude of first point
        lon1: Longitude of first point
        lat2: Latitude of second point
        lon2: Longitude of second point

    Returns:
        Distance in kilometers

    Raises:
        ValueError: If coordinates are invalid
    """
    # Implementation here
    pass

# Async functions
async def fetch_user_data(user_id: int) -> Dict[str, str]:
    """Fetch user data asynchronously."""
    pass
```

## Class Standards

```python
class UserService:
    """Service class for user operations."""

    def __init__(self, database_url: str):
        """Initialize with database connection."""
        self.database_url = database_url
        self.logger = logging.getLogger(__name__)

    @property
    def active_users(self) -> List[User]:
        """Get all active users."""
        return [user for user in self._users if user.is_active]

    async def get_user(self, user_id: int) -> Optional[User]:
        """Retrieve user by ID."""
        try:
            return await self._fetch_from_db(user_id)
        except DatabaseError as e:
            self.logger.error(f"Failed to fetch user {user_id}: {e}")
            return None
```

## Error Handling

```python
# Good
try:
    value = int(user_input)
except ValueError as e:
    logger.error(f"Invalid integer input: {user_input}")
    raise ValueError(f"Expected integer, got: {type(user_input).__name__}")

# Custom exceptions
class ValidationError(Exception):
    """Raised when data validation fails."""
    pass

# Context managers
with open("config.yaml", "r") as f:
    config = yaml.safe_load(f)
```

## Logging Standards

```python
import logging

logger = logging.getLogger(__name__)

# Use structured logging with context
logger.info("User created", extra={"user_id": user.id, "action": "create"})

# Avoid console output
api_key = "sk-abc123def456"  # Never hardcode secrets
```

## Testing Standards

```python
def test_user_creation():
    """Test user creation with valid data."""
    # Arrange
    user_data = {
        "name": "Gandalf",
        "email": "gandalf@middle-earth.test",
        "role": "wizard"
    }

    # Act
    user = create_user(user_data)

    # Assert
    assert user.name == "Gandalf"
    assert user.email == "gandalf@middle-earth.test"
    assert user.role == "wizard"

# Test patterns with mocks
@mock.patch("validate_user")
def test_user_validation_with_valid_data(mock_validate_user):
    """Test user validation with valid data."""

    user_data = {"name": "Frodo Baggins", "email": "frodo@shire.test"}
    mock_validate_user.return_value = UserValidationResult(is_valid=True, name="Frodo Baggins")

    result = validate_user(user_data)

    assert result.is_valid
    assert result.name == "Frodo Baggins"

    mock_validate_user.assert_called_once_with(user_data)
```

## Code Review Checklist

- [ ] All tests pass (`pytest -x --tb=short`)
- [ ] Type checking passes (`mypy src/ --strict`)
- [ ] Linting passes (`ruff check src/`)
- [ ] Formatting passes (`ruff format --check src/`)
- [ ] Security scan passes (`bandit -r src/ -ll`)
- [ ] Test coverage ≥90%
- [ ] No hardcoded secrets or API keys
- [ ] Functions have single responsibility
- [ ] Type hints are used consistently
- [ ] Error handling is specific and meaningful
- [ ] Documentation is clear and concise
- [ ] Imports are properly organized
- [ ] Logging is appropriate and informative
- [ ] Performance considerations addressed
- [ ] Async code properly handled
