# Python Standards

## Core Rules

### Never Use

```python
# Never
except Exception as e:  # Too broad
api_key = "sk-abc123"  # Hardcoded secrets
from .utils import *  # Wildcard imports
```

### Always Use

```python
# Always
except ValueError as e:  # Specific exceptions
api_key = os.getenv("API_KEY")  # Environment variables
from myproject.utils import parse_data  # Absolute imports
```

## Requirements

- Test coverage ≥80%: `pytest --cov=src --cov-fail-under=90`
- 100% test pass rate: `pytest -x --tb=short`
- Type safety: `mypy src/ --strict`
- Security scan: `bandit -r src/ -ll`

## Function Documentation

```python
def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two geographic points."""
```

## Test Structure

```python
@mock.patch("validate_user")
def test_user_validation_with_valid_data(mock_validate_user):
    """Test user validation with valid data."""
    # Arrange
    user_data = {"name": "Frodo Baggins", "email": "frodo@shire.test"}
    mock_validate_user.return_value = UserValidationResult(is_valid=True, name="Frodo Baggins")

    # Act
    result = validate_user(user_data)

    # Assert
    assert result.is_valid
    assert result.name == "Frodo Baggins"

    # Verify
    mock_validate_user.assert_called_once_with(user_data)
```

## Type Hints

```python
from typing import List, Dict, Optional, Union

def process_users(users: List[Dict[str, str]]) -> List[str]:
    """Process a list of user dictionaries and return usernames."""
    return [user["name"] for user in users]

def get_user_by_id(user_id: int) -> Optional[Dict[str, str]]:
    """Retrieve user by ID, returns None if not found."""
    pass
```

## Error Handling

```python
# Good
try:
    value = int(user_input)
except ValueError:
    logger.error(f"Invalid integer input: {user_input}")
    raise ValueError(f"Expected integer, got: {user_input}")

# Avoid
try:
    value = int(user_input)
except Exception as e:  # Too broad
    pass
```

## Security

```python
# Good
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("API_KEY")
database_url = os.getenv("DATABASE_URL")

# Avoid
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
```

## Code Review Checklist

- [ ] All tests pass (`pytest -x --tb=short`)
- [ ] Type checking passes (`mypy src/ --strict`)
- [ ] Linting passes (`ruff check src/`)
- [ ] Security scan passes (`bandit -r src/ -ll`)
- [ ] Test coverage ≥90%
- [ ] No hardcoded secrets or API keys
- [ ] Functions have single responsibility
- [ ] Type hints are used consistently
- [ ] Error handling is specific and meaningful
- [ ] Documentation is clear and concise
