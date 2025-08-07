# Python Style Guide

## Python Standards

### Never Allow

```python
# Never
catch Exception as e:  # Too broad
hardcoded_key = "sk-abc123"  # Secret in code
from .utils import *  # Relative import
```

```python
# Not required for test files
if __name__ == "__main__":
    unittest.main()
```

### Always Allow

```python
# Always
catch ValueError as e: # Specific exception
api_key = os.getenv("API_KEY") # Environment variable
from myproject.utils import parse_data # Absolute import
```

### Always Require

- Test coverage ≥80%: `pytest --cov=src --cov-fail-under=90`
- 100% test pass rate: `pytest -x --tb=short`
- Type safety: `mypy src/ --strict`
- Security scan: `bandit -r src/ -ll`

### Function Documentation

```python
# Short description, no args, no returns
def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two geographic points."""
```

### Test Structure

```python
# pytest example
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

## Code Quality Standards

### Type Hints

Always use type hints for function parameters and return values.

```python
from typing import List, Dict, Optional, Union

def process_users(users: List[Dict[str, str]]) -> List[str]:
    """Process a list of user dictionaries and return usernames."""
    return [user["name"] for user in users]

def get_user_by_id(user_id: int) -> Optional[Dict[str, str]]:
    """Retrieve user by ID, returns None if not found."""
    # Implementation
    pass
```

### Error Handling

Use specific exceptions and provide meaningful error messages.

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

### Security Practices

Never hardcode secrets or sensitive information.

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

### Import Standards

Use absolute imports and avoid wildcard imports.

```python
# Good
from myproject.utils import parse_data
from myproject.models import User

# Avoid
from .utils import *  # Wildcard imports
from utils import parse_data  # Relative imports
```

## Testing Standards

### Test Organization

Organize tests using the Arrange-Act-Assert pattern.

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

### Mocking

Use mocks for external dependencies and complex objects.

```python
@mock.patch("requests.get")
def test_api_call(mock_get):
    """Test API call with mocked response."""
    # Arrange
    mock_response = mock.Mock()
    mock_response.json.return_value = {"status": "success"}
    mock_get.return_value = mock_response

    # Act
    result = call_external_api("https://api.example.com/data")

    # Assert
    assert result["status"] == "success"
    mock_get.assert_called_once_with("https://api.example.com/data")
```

### Coverage Requirements

Maintain high test coverage with meaningful tests.

```bash
# Run tests with coverage
pytest --cov=src --cov-fail-under=90 --cov-report=html

# Run type checking
mypy src/ --strict

# Run security scan
bandit -r src/ -ll
```

## Performance and Best Practices

### List Comprehensions

Prefer list comprehensions over explicit loops when appropriate.

```python
# Good
squares = [x**2 for x in range(10) if x % 2 == 0]

# Also good for complex logic
def get_active_users(users):
    return [user for user in users if user.is_active and user.email_verified]
```

### Context Managers

Use context managers for resource management.

```python
# Good
with open("file.txt", "r") as f:
    content = f.read()

# Also good
with database.connection() as conn:
    result = conn.execute("SELECT * FROM users")
```

### Async/Await

Use async/await for I/O operations and concurrent tasks.

```python
import asyncio
import aiohttp

async def fetch_user_data(user_id: int) -> Dict[str, str]:
    """Fetch user data asynchronously."""
    async with aiohttp.ClientSession() as session:
        async with session.get(f"/api/users/{user_id}") as response:
            return await response.json()

async def fetch_multiple_users(user_ids: List[int]) -> List[Dict[str, str]]:
    """Fetch multiple users concurrently."""
    tasks = [fetch_user_data(user_id) for user_id in user_ids]
    return await asyncio.gather(*tasks)
```

## Code Review Checklist

Before submitting Python code, verify:

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
