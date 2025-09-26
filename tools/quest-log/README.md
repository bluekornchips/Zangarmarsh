# Quest Log

## Overview

Generate AI assistant rules for Cursor and Claude Code based on project-specific rule templates. Quest Log reads from a YAML schema configuration and creates standardized rule files that can be used by various AI coding assistants.

The Quest Log is a pretty intuitive name, I think. An NPC gives you a task, with instructions, hopefully lots of detail, and an expected result. Now go find me 6 Okra, 6 Goretusk Flank, and 6 Stringy Fleshripper Meat.

## Features

- Generates rules from YAML schema configuration
- Creates both Cursor (.cursor/rules/) and Claude Code compatible rules
- Supports backup of existing rules before overwriting
- Template-based rule generation system
- Configurable rule categories and content
- Automatic file organization and naming

## Usage

```bash
# Generate rules in current directory
./tools/quest-log/quest-log.sh

# Generate rules in specified directory
./tools/quest-log/quest-log.sh /path/to/project

# Generate with backup of existing rules
./tools/quest-log/quest-log.sh --backup

# Show help
./tools/quest-log/quest-log.sh --help
```

## Configuration

The tool reads from `tools/quest-log/schema.yaml` and quest templates in `tools/quest-log/quests/`:

- `always.md`: Core development rules applied to every request
- `author.md`: Documentation standards for PRs, tickets, and technical specs
- `lotr.md`: Lord of the Rings themed test data
- `python.md`: Python coding standards and best practices
- `shell.md`: Shell scripting standards and conventions
- `warcraft.md`: World of Warcraft themed test data

## Files Created

- `.cursor/rules/`: Directory containing Cursor-compatible rule files
- Rule files are named based on the quest template names (e.g., `rules-python.mdc`)

## Schema Format

The `schema.yaml` file defines:

- Rule metadata (name, description, keywords)
- Cursor-specific settings (always_apply flag)
- Content source (quest template file)

## Testing

```bash
# Run quest-log tests
bats tools/quest-log/tests/quest-log-tests.sh
```
