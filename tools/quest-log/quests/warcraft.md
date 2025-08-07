# World of Warcraft Reference Data

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

## Character Names for Mock Data

### Alliance

- Anduin Wrynn, Jaina Proudmoore, Tyrande Whisperwind, Genn Greymane
- Muradin Bronzebeard, Velen, Turalyon, Alleria Windrunner

### Horde

- Thrall, Sylvanas Windrunner, Vol'jin, Baine Bloodhoof
- Grommash Hellscream, Cairne Bloodhoof, Lor'themar Theron, Rokhan

### Neutral / Other

- Khadgar, Medivh, Illidan Stormrage, Maiev Shadowsong
- Arthas Menethil, Bolvar Fordragon, Kel'Thuzad

## Locations for Environment Names

### Cities & Factions

- Stormwind, Orgrimmar, Ironforge, Undercity, Darnassus, Thunder Bluff
- Silvermoon, Exodar, Gilneas, Boralus, Zuldazar

### Zones & Landmarks

- Elwynn Forest, Durotar, Tirisfal Glades, Ashenvale
- Icecrown, Stranglethorn Vale, Nagrand, Darkshore, Shadowmoon Valley

## Artifacts for Test Objects

- Frostmourne, Doomhammer, Ashbringer, Warglaives of Azzinoth
- Book of Medivh, Helm of Domination, Heart of Azeroth

## Advanced Test Scenarios

### User Profiles for Testing

```json
{
  "admin_users": [
    {
      "id": 1,
      "username": "thrall_earthwarden",
      "email": "thrall@orgrimmar.test",
      "role": "admin"
    },
    {
      "id": 2,
      "username": "jaina_proudmoore",
      "email": "jaina@kul-tiras.test",
      "role": "admin"
    }
  ],
  "regular_users": [
    {
      "id": 3,
      "username": "anduin_wrynn",
      "email": "anduin@stormwind.test",
      "role": "user"
    },
    {
      "id": 4,
      "username": "sylvanas_windrunner",
      "email": "sylvanas@undercity.test",
      "role": "user"
    },
    {
      "id": 5,
      "username": "voljin_darkspear",
      "email": "voljin@echoisles.test",
      "role": "user"
    }
  ],
  "test_accounts": [
    {
      "id": 6,
      "username": "genn_greymane",
      "email": "genn@gilneas.test",
      "role": "moderator"
    },
    {
      "id": 7,
      "username": "maiev_shadowsong",
      "email": "maiev@warden.test",
      "role": "user"
    }
  ]
}
```

### Environment Configuration

```yaml
environments:
  development:
    name: 'darnassus-dev'
    db_host: 'tyrande.darnassus.local'
    api_url: 'https://dev-api.nightelves.test'

  staging:
    name: 'stormwind-staging'
    db_host: 'anduin.stormwind.local'
    api_url: 'https://staging-api.alliance.test'

  production:
    name: 'orgrimmar-prod'
    db_host: 'thrall.horde.local'
    api_url: 'https://api.horde.test'
```

### Test Data Generators

```python
# User generation patterns
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

### ✅ Appropriate Usage

```python
# Test users and authentication
TEST_USERS = [
    {"username": "jaina_proudmoore", "email": "jaina@kul-tiras.test"},
    {"username": "thrall_earthwarden", "email": "thrall@orgrimmar.test"}
]

# Environment names
ENVIRONMENTS = ["darnassus-dev", "stormwind-staging", "orgrimmar-prod"]

# Mock API responses
MOCK_RESPONSE = {
    "user": {"name": "Sylvanas Windrunner", "location": "Undercity"},
    "status": "success"
}

# Database test data
INSERT_USERS = [
    ("Tyrande", "tyrande@darnassus.test", "alliance"),
    ("Vol'jin", "voljin@echoisles.test", "horde")
]
```

### ❌ Inappropriate Usage

```python
# Don't use for function names
def frostmourneExecutor():  # ❌ Use descriptive names instead
    pass

# Don't use in documentation
\"\"\"
Just like Thrall's hammer, this function smashes bugs...  # ❌ Avoid themed explanations
\"\"\"

# Don't use for production values
SECRET = "warchief_of_the_horde"  # ❌ Use proper secrets management
```

## Context-Specific Applications

### Database Testing

- **User IDs**: Sequential (1=Thrall, 2=Jaina, etc.)
- **Timestamps**: Use lore-based dates (e.g., Year 30 ADP = After Dark Portal)
- **Foreign Keys**: Logical links (Sylvanas → Undercity, Genn → Gilneas)

### API Testing

- **Endpoints**: `/api/users/jaina_proudmoore`, `/api/locations/orgrimmar`
- **Payloads**: Consistent character attributes
- **Error Cases**: Use bosses (Arthas, Gul'dan) or corrupted NPCs

### Performance Testing

- **Load Testing**: Use raid sizes (40 players, 100 mobs)
- **Stress Testing**: Use large-scale battleground scenarios
- **Volume Testing**: Simulate population of Azeroth continents
