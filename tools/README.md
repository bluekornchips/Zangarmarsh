# Zangarmarsh Tools

Development workflow utilities for shell environments.

## Tools

### Quest Log

AI assistant rules generator for Cursor from JSON schema.

```bash
./tools/quest-log/quest-log.sh
./tools/quest-log/quest-log.sh --all
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
