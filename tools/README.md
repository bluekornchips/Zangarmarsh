# Zangarmarsh Tools

Development workflow utilities for shell environments.

## Tools

### Dalaran

ZSH command history analyzer that builds a library of your most-used commands.

```bash
./tools/dalaran/dalaran.sh
./tools/dalaran/dalaran.sh --dry-run
```

### Quest Log

AI assistant rules generator for Cursor and Claude Code from YAML templates.

```bash
./tools/quest-log/quest-log.sh
./tools/quest-log/quest-log.sh --backup
```

### Trilliax

Development environment cleanup tool for generated files and build artifacts.

```bash
./tools/trilliax/trilliax.sh
./tools/trilliax/trilliax.sh --dry-run
```

## Testing

```bash
make test-all
bats tools/*/tests/*.sh
```

See individual tool README files for detailed documentation.
