# Zangarmarsh Tools

Short index. Full usage, options, and tests live in each tool README under this directory.

| Tool              | Role                                                               | Entry                                                                     |
| ----------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| Quest Log         | Cursor rules from `schema.json`                                    | `./tools/quest-log/quest-log.sh` or `questlog` after sourcing Zangarmarsh |
| Trilliax          | Remove caches and build artifacts                                  | `./tools/trilliax/trilliax.sh --all`                                      |
| Talent Calculator | Check or install workstation CLIs                                  | `./tools/talent-calculator/talent-calculator.sh` then `--help`            |
| Hearthstone       | jq, questlog, VS Code sync, gdlf, optional Trilliax with `--force` | `./tools/hearthstone/hearthstone.sh`                                      |
| Ice Block         | Backup dotfiles to `~/.ice-block/<hostname>/`                      | `./tools/ice-block/ice-block.sh`                                          |
| Auras             | Managed AppImage `.desktop` files                                  | `./tools/auras/auras.sh --help`                                           |

## Testing

```bash
make test
```

See [quest-log/README.md](quest-log/README.md), [trilliax/README.md](trilliax/README.md), [talent-calculator/README.md](talent-calculator/README.md), [hearthstone/README.md](hearthstone/README.md), [ice-block/README.md](ice-block/README.md), and [auras/README.md](auras/README.md).
