# Hearthstone

Runs a fixed sequence to sync a development machine with this repo: ensure `jq`, generate Cursor rules, copy VS Code settings from Zangarmarsh into the current git root, then run Gandalf install. Optional cleanup runs only with `--force`.

## Requirements

- Run from a git checkout of Zangarmarsh so `GIT_ROOT` contains `tools/`
- External commands used by the script or your shell: `questlog` and `gdlf` are normally provided by Zangarmarsh aliases, see [profile/aliases.sh](../../profile/aliases.sh). `trilliax` is invoked only when `--force` is set.
- `vscodeoverride` is a **function** inside [hearthstone.sh](hearthstone.sh), not a separate binary.

## Operations order

1. `build_deck` — ensure `jq` is available, see `install_jq` in the script
2. `trilliax --all` — **only when `--force`** — runs before rule generation so cleanup hits the tree first
3. `questlog` — generate rules via `tools/quest-log/quest-log.sh`
4. `vscodeoverride` — copy `Zangarmarsh/.vscode/` into the target repo `.vscode/`, replace when `--force`
5. `gdlf -i` — Gandalf MCP install. With `--force`, adds `-f` to gdlf. With `--yes`, adds `-y` so gdlf can skip its own prompts

## Usage

```bash
hearthstone
hearthstone --yes
hearthstone --yes --force
hearthstone --help
```

## Options

- `-y`, `--yes` — skip Hearthstone confirmation, forward `-y` to `gdlf` when applicable
- `-f`, `--force` — replace VS Code settings if present, run `trilliax --all`, pass `-f` to `gdlf`
- `-h`, `--help` — print usage

## Confirmation

Without `--yes`, the script prints the planned steps and waits for `y` or `yes`. Anything else cancels.

## Testing

```bash
bats tools/hearthstone/tests/hearthstone-tests.sh
```

## Error handling

Exits non-zero when the Zangarmarsh tree is invalid, any step fails, or you cancel at the prompt.
