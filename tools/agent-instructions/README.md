# Agent Instructions Tool

Generate AI assistant rules for Cursor and Claude Code.

## Overview

The agent-instructions tool analyzes your project structure and generates:

- CLAUDE.md: Core development standards for Claude Code
- Cursor Rules: Individual rule files for Cursor IDE
- Backup System: Safe backup of existing rules before overwriting

## Install

None required.

## Usage

```bash
# Generate rules in current directory
./tools/agent-instructions/agent-instructions.sh

# Generate rules in specified directory
./tools/agent-instructions/agent-instructions.sh /path/to/project

# Backup existing rules before generating new ones
./tools/agent-instructions/agent-instructions.sh --backup

# Show help
./tools/agent-instructions/agent-instructions.sh --help
```

## Configuration

The tool uses a YAML schema file (`schema.yaml`) to define:

- Source Files: Template files for different rule types
- Output Formats: How rules should be generated
- File Locations: Where generated files should be placed

### Environment Variables

- `BACKUP_ENABLED`: Enable backup mode (default: false)
- `TARGET_DIR`: Directory to generate rules in (default: current directory)

## Generated Files

### CLAUDE.md

Contains core development standards wrapped in markers:

```markdown
##_USER_RULES_##

# Enhanced Development Standards

... ##_USER_RULES_##
```

### Cursor Rules (.cursor/rules/)

Individual rule files for Cursor IDE:

- `rules-vital.mdc`: Core development standards
- `rules-author.mdc`: Documentation guidelines
- `rules-python-styles.mdc`: Python coding standards
- `rules-shell-styles.mdc`: Shell scripting standards
- `rules-lotr-data.mdc`: Lord of the Rings test data
- `rules-wow-data.mdc`: World of Warcraft test data

## Rule Types

### Core Standards (vital.mdc)

Essential development practices that apply to all languages:

- Comment and logging standards
- Git command restrictions
- Documentation requirements
- Code quality gates

### Language-Specific Standards

Python Standards (python-styles.mdc)

- Type hints and error handling
- Testing with pytest and coverage
- Security scanning with bandit
- Async/await best practices

Shell Standards (shell-styles.mdc)

- Bash scripting best practices
- ShellCheck compliance
- Function and variable naming
- Error handling patterns

### Documentation Standards (author.mdc)

Guidelines for generating high-quality documentation:

- PR description templates
- README.md structure
- API documentation format
- Technical specification templates

### Test Data Standards

Lord of the Rings Data (lotr-data.mdc)

- Character names for mock data
- Location names for environments
- Quotes for test content

World of Warcraft Data (wow-data.mdc)

- Faction-based test data
- Azeroth location names
- Game-specific terminology

## Integration

### With Cursor IDE

1. Generate rules in your project directory
2. Cursor will automatically detect and apply the rules
3. Rules are applied based on file patterns and content

### With Claude Code

1. Generate rules to create CLAUDE.md
2. Claude Code will use the wrapped rules section
3. Rules are applied globally to the project

## Requirements

- yq: YAML processor for schema parsing
- Bash: Shell environment for script execution
- Standard Unix tools: grep, sed, awk, etc.

## Testing

The tool includes comprehensive Bats tests:

```bash
# Run all tests
bats tools/agent-instructions/tests/agent-instructions-tests.sh

# Run specific test
bats tools/agent-instructions/tests/agent-instructions-tests.sh -f "test name"
```

Tests cover:

- Schema validation
- File generation
- Backup functionality
- Error handling
- Template processing
