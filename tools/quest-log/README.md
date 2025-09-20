# Quest Log

Generate AI assistant rules for Cursor and Claude Code based on project-specific rule templates.

## Overview

The quest-log tool processes rule templates defined in `schema.yaml` and generates:

- CLAUDE.md: Core development standards for Claude Code wrapped in quest log markers
- Cursor Rules: Individual rule files in `.cursor/rules/` directory for Cursor IDE
- Rule Processing: Converts quest template files into AI assistant rule formats

## Install

None required.

## Usage

```bash
# Generate rules in current directory
./tools/quest-log/quest-log.sh

# Generate rules in specified directory
./tools/quest-log/quest-log.sh /path/to/project

# Show help
./tools/quest-log/quest-log.sh --help
```

## Configuration

The tool uses a YAML schema file (`schema.yaml`) to define rule templates including:

- Rule Names: Unique identifiers for each rule type
- Source Files: Template files containing rule content
- Keywords: Trigger words for rule activation
- Icons: Visual identifiers for each rule type
- Cursor Settings: Whether rules should always apply

### Environment Variables

- `TARGET_DIR`: Directory to generate rules in (default: current directory)
- `SCHEMA_FILE`: Path to schema file (default: ./schema.yaml)

## Generated Files

### CLAUDE.md

Contains AI assistant rules wrapped in quest log markers:

```markdown
###!QUEST_LOG!###

# Core Development Rules

... ###!QUEST_LOG!###
```

The file is created if it doesn't exist, or updated between existing markers if present.

### Cursor Rules (.cursor/rules/)

Individual rule files for Cursor IDE based on quest templates:

- `rules-always.mdc`: Core development standards that always apply
- `rules-author.mdc`: Documentation guidelines for authoring content
- `rules-python.mdc`: Python coding standards and best practices
- `rules-shell.mdc`: Shell scripting standards and guidelines
- `rules-lotr.mdc`: Lord of the Rings reference data rules
- `rules-warcraft.mdc`: World of Warcraft reference data rules

Each rule file includes the rule content, trigger keywords, and Cursor-specific metadata.

## Rule Types

### Core Standards (rules-always.mdc)

Essential development practices that apply to every request:

- Universal development standards and restrictions
- Git command usage guidelines
- Code quality and documentation requirements
- Best practices enforcement

### Language-Specific Standards

Python Standards (rules-python.mdc)

Applied to Python code with keywords: python, python3, py, pytest, pycharm, venv, virtualenv

Shell Standards (rules-shell.mdc)

Applied to shell scripts with keywords: shell, bash, zsh, sh, script, bats, command, terminal, cli

### Documentation Standards (rules-author.mdc)

Applied to documentation tasks with keywords: author, authoring, README, JIRA, ticket, description, doc, documentation, summary, pr, pull request, github

### Reference Data Standards

Lord of the Rings Data (rules-lotr.mdc)

Applied to Lord of the Rings reference data with keywords: lotr, lord of the rings, middle earth, test data, mock

World of Warcraft Data (rules-warcraft.mdc)

Applied to World of Warcraft reference data with keywords: warcraft, world of warcraft, wow, test data, mock, game, character, location, quest

## Integration

### With Cursor IDE

1. Generate rules in your project directory using `./tools/quest-log/quest-log.sh`
2. Cursor automatically detects rule files in `.cursor/rules/` directory
3. Rules are applied based on keywords and content patterns defined in the schema
4. Each rule file contains metadata specifying when it should be triggered

### With Claude Code

1. Generate rules to create or update `CLAUDE.md` in the target directory
2. Claude Code recognizes the content wrapped between `###!QUEST_LOG!###` markers
3. Rules are applied based on the keywords and content within the markers
4. The tool can update existing CLAUDE.md files by replacing content between markers

## Requirements

- yq: YAML processor for parsing the schema file
- jq: JSON processor for manipulating quest data
- Bash: Shell environment for script execution (version 4.0+)
- Standard Unix tools: grep, sed, cat, mktemp, mkdir

## Testing

The tool includes comprehensive Bats tests:

```bash
# Run all tests
bats tools/quest-log/tests/quest-log-tests.sh

# Run specific test function
bats tools/quest-log/tests/quest-log-tests.sh -f "function_name"

# Run tests matching pattern
bats tools/quest-log/tests/quest-log-tests.sh -f "pattern"
```

Tests cover:

- Schema parsing and validation
- Rule file generation for all quest types
- CLAUDE.md file creation and updating
- Error handling for missing dependencies
- Command-line argument processing
- File system operations
