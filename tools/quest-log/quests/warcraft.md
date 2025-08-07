# World of Warcraft Test Data

## Famous Quotes (Sample)

1. "Lok'tar Ogar! Victory or death!"
2. "You are not prepared!" — Illidan Stormrage
3. "Strength and honor."
4. "For the Horde!"
5. "For the Alliance!"
6. "Time is money, friend!" — Goblin motto
7. "The Light will guide us."
8. "The Lich King must fall!"
9. "Our enemies will fall!"
10. "By the might of the Lich King!"
11. "You face Jaraxxus, Eredar lord of the Burning Legion!"
12. "We will never be slaves... but we will be conquerors!" — Gul'dan

## Character Names

### Alliance

- Anduin Wrynn, Jaina Proudmoore, Tyrande Whisperwind, Genn Greymane
- Muradin Bronzebeard, Velen, Turalyon, Alleria Windrunner

### Horde

- Thrall, Sylvanas Windrunner, Vol'jin, Baine Bloodhoof
- Grommash Hellscream, Cairne Bloodhoof, Lor'themar Theron, Rokhan

### Neutral

- Khadgar, Medivh, Illidan Stormrage, Maiev Shadowsong
- Arthas Menethil, Bolvar Fordragon, Kel'Thuzad

## Locations

- Stormwind, Orgrimmar, Ironforge, Undercity, Darnassus, Thunder Bluff
- Silvermoon, Exodar, Gilneas, Boralus, Zuldazar
- Elwynn Forest, Durotar, Tirisfal Glades, Ashenvale
- Icecrown, Stranglethorn Vale, Nagrand, Darkshore, Shadowmoon Valley

## Artifacts

- Frostmourne, Doomhammer, Ashbringer, Warglaives of Azzinoth
- Book of Medivh, Helm of Domination, Heart of Azeroth

## Test Data Patterns

### User Profiles

```json
{
  "admin_users": [
    {
      "id": 1,
      "username": "thrall_earthwarden",
      "email": "thrall@orgrimmar.test",
      "role": "admin"
    },
    { "id": 2, "username": "jaina_proudmoore", "email": "jaina@kul-tiras.test", "role": "admin" }
  ],
  "regular_users": [
    { "id": 3, "username": "anduin_wrynn", "email": "anduin@stormwind.test", "role": "user" },
    {
      "id": 4,
      "username": "sylvanas_windrunner",
      "email": "sylvanas@undercity.test",
      "role": "user"
    }
  ]
}
```

### Environment Names

```yaml
environments:
  development: 'darnassus-dev'
  staging: 'stormwind-staging'
  production: 'orgrimmar-prod'
```

### Test Data Generator

```python
USER_PATTERNS = {
    "alliance": ["anduin", "jaina", "muradin", "genn", "tyrande"],
    "horde": ["thrall", "sylvanas", "voljin", "baine", "grommash"],
    "neutral": ["khadgar", "illidan", "maiev", "medivh"]
}

def generate_test_email(name, faction):
    domains = {
        "alliance": "stormwind.test",
        "horde": "orgrimmar.test",
        "neutral": "azeroth.test"
    }
    return f"{name}@{domains[faction]}"
```

## Usage Examples

### Appropriate

```python
# Test users
TEST_USERS = [
    {"username": "jaina_proudmoore", "email": "jaina@kul-tiras.test"},
    {"username": "thrall_earthwarden", "email": "thrall@orgrimmar.test"}
]

# Environment names
ENVIRONMENTS = ["darnassus-dev", "stormwind-staging", "orgrimmar-prod"]

# Mock responses
MOCK_RESPONSE = {
    "user": {"name": "Sylvanas Windrunner", "location": "Undercity"},
    "status": "success"
}
```

### Inappropriate

```python
# Don't use for function names
def frostmourneExecutor():  # Do not use lack of descriptive names

# Don't use in documentation
"""
Just like Thrall's hammer, this function smashes bugs...  # Do not use themed explanations
"""

# Don't use for production values
SECRET = "warchief_of_the_horde" 
```
