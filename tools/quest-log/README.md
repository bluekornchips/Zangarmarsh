# Quest Log

## Overview

Generate AI assistant rules for Cursor based on project-specific rule templates. Quest Log reads from a JSON schema configuration and creates standardized rule files. Rules are installed locally in the project directory.

## Install

```bash
# Source the main script
source /path/to/zangarmarsh/zangarmarsh.sh

# Quest-log will be available as an alias
questlog
```

## Features

- Generates rules from JSON schema configuration
- Creates Cursor rules locally (.cursor/rules/)
- Generates daily-quests (Cursor commands) from markdown files (.cursor/commands/)
- Template-based rule generation system
- Configurable rule categories and content
- Automatic file organization and naming

## Usage

```bash
# Generate rules in current directory
questlog

# Generate rules in specified directory
questlog /path/to/project

# Generate all rules including warcraft and lotr
questlog --all

# Show help
questlog --help
```

## Configuration

The tool reads from `tools/quest-log/schema.json` and quest templates in `tools/quest-log/quests/`:

- `always.md`: Core development rules applied to every request
- `lotr.md`: Lord of the Rings themed test data
- `python.md`: Python coding standards and best practices
- `shell.md`: Shell scripting standards and conventions
- `warcraft.md`: World of Warcraft themed test data

## Daily Quests

Quest Log generates daily-quests (Cursor commands) from markdown files in `tools/quest-log/commands/`. Daily-quests are reusable workflows that can be triggered with a `/` prefix in the Cursor chat input.

For more information about Cursor commands, see the [Cursor Commands documentation](https://cursor.com/docs/agent/chat/commands).

### Available Daily Quests

- `bash-review.md`: Comprehensive bash repository review checklist
- `author.md`: Documentation templates for PRs, Jira tickets, README files, and technical specs

Daily-quests are automatically copied to `.cursor/commands/` when you run `questlog`. You can then use them in Cursor by typing `/` followed by the command name (e.g., `/bash-review` or `/author`).

## Files Created

- `.cursor/rules/`: Local Cursor rules directory in project
  - Rule files are named based on the quest template names (e.g., `rules-python.mdc`)
- `.cursor/commands/`: Local Cursor daily-quests directory in project
  - Daily-quest files are generated from `tools/quest-log/commands/*.md`
  - Daily-quests can be invoked in Cursor chat with `/command-name`
  - See [Cursor Commands documentation](https://cursor.com/docs/agent/chat/commands) for details

## Schema Format

The `schema.json` file defines:

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
- [ ] Daily-quests are generated in `.cursor/commands/` directory (if commands directory exists)
- [ ] All quest templates are processed correctly
- [ ] `--all` flag includes warcraft and lotr rules
