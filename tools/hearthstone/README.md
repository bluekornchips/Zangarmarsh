# Hearthstone

Hearthstone setup and sync tool. Runs a series of setup and sync commands to initialize and synchronize the development environment.

## Requirements

- Must be run from within a git repository
- Must be run from the top level of the git repository
- Requires the following commands to be available:
  - `trilliax`
  - `questlog`
  - `vscodeoverride`
  - `gdlf`

## Operations

Hearthstone executes the following operations in order:

1. `trilliax --all` - Clean generated files and directories
2. `questlog` - Generate agentic tool rules
3. `vscodeoverride` - Sync VSCode settings
4. `gdlf --install -f` - Force install Gandalf MCP server

## Usage

Run with confirmation prompt:

```bash
hearthstone
```

Skip confirmation prompt:

```bash
hearthstone --yes
```

## Options

- `-y, --yes` - Skip confirmation prompt and proceed immediately
- `-h, --help` - Show help message

## Confirmation

Since this script performs destructive operations, it will prompt for confirmation before proceeding unless the `-y` flag is provided. Enter `y` or `yes` to confirm, any other input will cancel the operation.

## Testing

Run the test suite:

```bash
bats tools/hearthstone/tests/hearthstone-tests.sh
```

## Error Handling

The script will fail if:

- Not run from within a git repository
- Not run from the git repository root
- Any of the operations fail
