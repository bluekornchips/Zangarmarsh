# Lord of the Rings Test Data

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

## Character Names

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

## Locations

- The Shire, Hobbiton, Bag End, Rivendell, Lothlórien, Minas Tirith
- Isengard, Edoras, Dale, Erebor, Rohan, Gondor
- Mount Doom, Weathertop, Fangorn Forest, Anduin River, Pelennor Fields

## Artifacts

- The One Ring, Narsil/Andúril, Sting, Glamdring, Mithril
- Palantír, The Phial of Galadriel, The White Tree of Gondor

## Test Data Patterns

### User Profiles

```json
{
  "admin_users": [
    { "id": 1, "username": "gandalf_grey", "email": "gandalf@rivendell.test", "role": "admin" },
    { "id": 2, "username": "aragorn_elessar", "email": "aragorn@gondor.test", "role": "admin" }
  ],
  "regular_users": [
    { "id": 3, "username": "frodo_baggins", "email": "frodo@shire.test", "role": "user" },
    { "id": 4, "username": "samwise_gamgee", "email": "sam@shire.test", "role": "user" }
  ]
}
```

### Environment Names

```yaml
environments:
  development: 'hobbiton-dev'
  staging: 'rivendell-staging'
  production: 'minas-tirith-prod'
```

### Test Data Generator

```python
USER_PATTERNS = {
    "hobbit": ["frodo", "sam", "merry", "pippin", "bilbo"],
    "elf": ["legolas", "elrond", "arwen", "galadriel"],
    "dwarf": ["gimli", "balin", "thorin", "dain"],
    "human": ["aragorn", "boromir", "faramir", "eowyn"]
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

### Appropriate

```python
# Test users
TEST_USERS = [
    {"username": "frodo_baggins", "email": "frodo@shire.test"},
    {"username": "gandalf_grey", "email": "gandalf@rivendell.test"}
]

# Environment names
ENVIRONMENTS = ["hobbiton-dev", "rivendell-staging", "gondor-prod"]

# Mock responses
MOCK_RESPONSE = {
    "user": {"name": "Samwise Gamgee", "location": "Hobbiton"},
    "status": "success"
}
```

### Inappropriate

```python
# Don't use for function names
def gandalfProcessor():  # Do not use lack of descriptive names

# Don't use in documentation
"""
This function works like Gandalf's magic...  # Do not use themed explanations
"""

# Don't use for production values
API_KEY = "one_ring_to_rule_them_all"
```
