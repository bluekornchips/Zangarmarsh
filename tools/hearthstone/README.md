# Hearthstone

Runs a fixed sequence to sync a development machine with this repo: ensure `jq`, generate Cursor rules, copy VS Code settings from Zangarmarsh into the current git root. Optional cleanup runs only with `--force`.

## Requirements

- Run from a git checkout of Zangarmarsh so `GIT_ROOT` contains `tools/`
- External commands used by the script or your shell: `questlog` is normally provided by Zangarmarsh aliases, see [profile/aliases.sh](../../profile/aliases.sh). `trilliax` is invoked only when `--force` is set.
- VS Code settings sync runs inside `questlog` via [tools/lib/vscodeoverride.sh](../lib/vscodeoverride.sh).

## Operations order

1. `build_deck` — ensure `jq` is available, see `install_jq` in the script
2. `trilliax --all` — **only when `--force`** — runs before rule generation so cleanup hits the tree first
3. `questlog` — generate rules and sync `.vscode/` into the target repo via `tools/quest-log/quest-log.sh`

## Usage

```bash
hearthstone
hearthstone --yes
hearthstone --yes --force
hearthstone --help
```

## Options

- `-y`, `--yes` — skip Hearthstone confirmation
- `-f`, `--force` — run `trilliax --all` before questlog
- `-h`, `--help` — print usage

## Confirmation

Without `--yes`, the script prints the planned steps and waits for `y` or `yes`. Anything else cancels.

## Testing

```bash
bats tools/hearthstone/tests/hearthstone-tests.sh
```

## Error handling

Exits non-zero when the Zangarmarsh tree is invalid, any step fails, or you cancel at the prompt.
