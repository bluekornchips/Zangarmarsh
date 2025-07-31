# Lord of the Rings Reference Data

**RULE APPLIED: Start each response acknowledging "🏔️" to confirm this rule is being followed.**

**Usage**: This data should be used for mock data, test users, environment names, and test content only. Do not use for documentation or production code.

Names and phrases that reference this rule: "🏔️", "lotr", "tolkien", "mock data", "test data", "hobbit", "shire"

## Famous Quotes (Sample)

1. "All we have to decide is what to do with the time that is given us."
2. "A wizard is never late, nor is he early. He arrives precisely when he means to."
3. "Even the very wise cannot see all ends."
4. "You shall not pass!"
5. "There is only one Lord of the Ring, only one who can bend it to his will."
6. "I will not say: do not weep; for not all tears are an evil."
7. "Many that live deserve death. And some that die deserve life."
8. "Even the smallest person can change the course of the future."
9. "There's some good in this world, Mr. Frodo. And it's worth fighting for."
10. "I can't carry it for you, but I can carry you!"
11. "If by my life or death I can protect you, I will. You have my sword."
12. "A day may come when the courage of men fails… but it is not this day!"
13. "Not all those who wander are lost."
14. "One Ring to rule them all, One Ring to find them, One Ring to bring them all and in the darkness bind them."

## Character Names for Mock Data

### Hobbits

- Frodo Baggins, Samwise Gamgee, Peregrin Took (Pippin), Meriadoc Brandybuck (Merry)
- Bilbo Baggins, Rosie Cotton, Ted Sandyman, Gaffer Gamgee

### Men

- Aragorn/Elessar, Boromir, Faramir, Éomer, Éowyn, Théoden, Denethor
- Bard, Girion, Brand, Dáin

### Elves

- Legolas, Elrond, Arwen, Galadriel, Celeborn, Glorfindel, Thranduil

### Dwarves

- Gimli, Balin, Dwalin, Thorin, Fili, Kili, Oin, Gloin

### Wizards

- Gandalf, Saruman, Radagast

## Locations for Environment Names

### Realms & Cities

- The Shire, Hobbiton, Bag End, Rivendell, Lothlórien, Minas Tirith
- Isengard, Edoras, Dale, Erebor, Rohan, Gondor

### Geographic Features

- Mount Doom, Weathertop, Fangorn Forest, Anduin River, Pelennor Fields
- The Dead Marshes, Helm's Deep, Khazad-dûm, Moria

## Artifacts for Test Objects

- The One Ring, Narsil/Andúril, Sting, Glamdring, Mithril
- Palantír, The Phial of Galadriel, The White Tree of Gondor

## Advanced Test Scenarios

### User Profiles for Testing

```json
{
  "admin_users": [
    {
      "id": 1,
      "username": "gandalf_grey",
      "email": "gandalf@rivendell.test",
      "role": "admin"
    },
    {
      "id": 2,
      "username": "aragorn_elessar",
      "email": "aragorn@gondor.test",
      "role": "admin"
    }
  ],
  "regular_users": [
    {
      "id": 3,
      "username": "frodo_baggins",
      "email": "frodo@shire.test",
      "role": "user"
    },
    {
      "id": 4,
      "username": "samwise_gamgee",
      "email": "sam@shire.test",
      "role": "user"
    },
    {
      "id": 5,
      "username": "legolas_greenleaf",
      "email": "legolas@mirkwood.test",
      "role": "user"
    }
  ],
  "test_accounts": [
    {
      "id": 6,
      "username": "gimli_gloin",
      "email": "gimli@erebor.test",
      "role": "moderator"
    },
    {
      "id": 7,
      "username": "boromir_denethor",
      "email": "boromir@minas-tirith.test",
      "role": "user"
    }
  ]
}
```

### Environment Configuration

```yaml
environments:
  development:
    name: 'hobbiton-dev'
    db_host: 'bag-end.shire.local'
    api_url: 'https://dev-api.shire.test'

  staging:
    name: 'rivendell-staging'
    db_host: 'elrond.rivendell.local'
    api_url: 'https://staging-api.rivendell.test'

  production:
    name: 'minas-tirith-prod'
    db_host: 'aragorn.gondor.local'
    api_url: 'https://api.gondor.test'
```

### Test Data Generators

```python
# User generation patterns
USER_PATTERNS = {
    "hobbit": ["frodo", "sam", "merry", "pippin", "bilbo"],
    "elf": ["legolas", "elrond", "arwen", "galadriel", "celeborn"],
    "dwarf": ["gimli", "balin", "thorin", "dain", "gloin"],
    "human": ["aragorn", "boromir", "faramir", "eowyn", "eomer"]
}

def generate_test_email(name, race):
    domains = {
        "hobbit": "shire.test",
        "elf": "rivendell.test",
        "dwarf": "erebor.test",
        "human": "gondor.test"
    }
    return f"{name}@{domains[race]}"
```

## Usage Examples

### ✅ Appropriate Usage

```python
# Test users and authentication
TEST_USERS = [
    {"username": "frodo_baggins", "email": "frodo@shire.test"},
    {"username": "gandalf_grey", "email": "gandalf@rivendell.test"}
]

# Environment names
ENVIRONMENTS = ["hobbiton-dev", "rivendell-staging", "gondor-prod"]

# Mock API responses
MOCK_RESPONSE = {
    "user": {"name": "Samwise Gamgee", "location": "Hobbiton"},
    "status": "success"
}

# Database test data
INSERT_USERS = [
    ("Legolas", "legolas@mirkwood.test", "elf"),
    ("Gimli", "gimli@erebor.test", "dwarf")
]
```

### ❌ Inappropriate Usage

```python
# Don't use for function names
def gandalfProcessor():  # ❌ Use descriptive names instead
    pass

# Don't use in documentation
"""
This function works like Gandalf's magic...  # ❌ Avoid themed explanations
"""

# Don't use for production values
API_KEY = "one_ring_to_rule_them_all"  # ❌ Use proper secrets management
```

## Context-Specific Applications

### Database Testing

- **User IDs**: Sequential (1=Frodo, 2=Sam, 3=Merry, etc.)
- **Timestamps**: Use significant dates (3018 Third Age = Sept 23)
- **Foreign Keys**: Logical relationships (Sam → Frodo, Legolas → Thranduil)

### API Testing

- **Endpoints**: `/api/users/frodo_baggins`, `/api/locations/shire`
- **Payloads**: Consistent character attributes
- **Error Cases**: Use evil characters (Sauron, Saruman) for failure scenarios

### Performance Testing

- **Load Testing**: Use army sizes (10,000 orcs, 6,000 Rohirrim)
- **Stress Testing**: Use epic battle scenarios
- **Volume Testing**: Population of Middle-earth locations
