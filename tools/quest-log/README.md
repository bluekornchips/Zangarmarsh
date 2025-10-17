# Quest Log

## Overview

Generate AI assistant rules for Cursor and Claude Code based on project-specific rule templates. Quest Log reads from a YAML schema configuration and creates standardized rule files using a hybrid approach: Cursor rules are installed locally in the project directory, while Claude rules are installed globally for system-wide availability.

## Install

```bash
# Source the main script
source /path/to/zangarmarsh/zangarmarsh.sh

# Quest-log will be available as an alias
questlog
```

## Features

- Hybrid installation approach: Cursor rules local, Claude rules global
- Generates rules from YAML schema configuration
- Creates Cursor rules locally (.cursor/rules/) and Claude rules globally (~/.claude/rules.md)
- Supports backup of existing rules before overwriting
- Template-based rule generation system
- Configurable rule categories and content
- Automatic file organization and naming

## Usage

```bash
# Generate rules in current directory
questlog

# Generate rules in specified directory
questlog /path/to/project

# Generate with backup of existing rules
questlog --backup

# Generate all rules including warcraft and lotr
questlog --all

# Show help
questlog --help
```

### Hybrid Installation

Quest-log uses a hybrid approach for optimal compatibility:

- Cursor: Rules are installed locally to `.cursor/rules/` in the project directory
- Claude Code: Rules are installed globally to `~/.claude/rules.md` for system-wide availability

This approach ensures Cursor rules are available in the project context window while Claude rules are accessible globally.

## Configuration

The tool reads from `tools/quest-log/schema.yaml` and quest templates in `tools/quest-log/quests/`:

- `always.md`: Core development rules applied to every request
- `author.md`: Documentation standards for PRs, tickets, and technical specs
- `lotr.md`: Lord of the Rings themed test data
- `python.md`: Python coding standards and best practices
- `shell.md`: Shell scripting standards and conventions
- `warcraft.md`: World of Warcraft themed test data

## Files Created

### Local Installation (Cursor)

- `.cursor/rules/`: Local Cursor rules directory in project
- Rule files are named based on the quest template names (e.g., `rules-python.mdc`)

### Global Installation (Claude)

- `~/.claude/rules.md`: Global Claude Code rules file

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

## Verification Steps

- [ ] Rules are generated in `.cursor/rules/` directory
- [ ] Claude rules are updated in `~/.claude/rules.md`
- [ ] All quest templates are processed correctly
- [ ] Backup functionality works when `--backup` flag is used
- [ ] `--all` flag includes warcraft and lotr rules
