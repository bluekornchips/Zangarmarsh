# Zangarmarsh Tools

Short index. Full usage, options, and tests live in each tool README under this directory.

| Tool              | Role                                                             | Entry                                                                     |
| ----------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Quest Log         | Install plugin; overwrite host Cursor user settings              | `./tools/quest-log/quest-log.sh` or `questlog` after sourcing Zangarmarsh |
| Trilliax          | Remove caches and build artifacts                                | `./tools/trilliax/trilliax.sh --all`                                      |
| Talent Calculator | Check or install workstation CLIs                                | `./tools/talent-calculator/talent-calculator.sh` then `--help`            |
| Hearthstone       | jq, questlog (host Cursor settings), optional Trilliax `--force` | `./tools/hearthstone/hearthstone.sh`                                      |
| Auras             | Managed AppImage `.desktop` files and `~/.local/bin` symlinks    | `./tools/auras/auras.sh --help`                                           |

## Testing

```bash
make test
```

See [quest-log/README.md](quest-log/README.md), [trilliax/README.md](trilliax/README.md), [talent-calculator/README.md](talent-calculator/README.md), [hearthstone/README.md](hearthstone/README.md), and [auras/README.md](auras/README.md).
