# Hearthstone

Runs a fixed sequence to sync a development machine with this repo: ensure `jq`,
install the local quest-log plugin, sync `tools/vscode/` into `.vscode`, and
align Cursor user theme preferences via `questlog`. Optional cleanup runs only with
`--force` and always targets the verified Zangarmarsh root.

## Requirements

- `ZANGARMARSH_ROOT` must be set, normally by sourcing `zangarmarsh.sh`
- External commands used by the script or your shell: `questlog` is normally
  provided by Zangarmarsh aliases, see [profile/aliases.sh](../../profile/aliases.sh).
  `trilliax` is invoked only when `--force` is set.
- VS Code settings sync runs inside `questlog` via
  [tools/lib/vscodeoverride.sh](../lib/vscodeoverride.sh).

## Operations order

1. `build_deck` — ensure `jq` is on `PATH`; this step does not install packages
2. `trilliax --all "$ZANGARMARSH_ROOT"` — **only when `--force`** — cleanup the
   verified Zangarmarsh root before the sync
3. `questlog "$ZANGARMARSH_ROOT"` — install the quest-log plugin under
   `~/.cursor/plugins/local/quest-log`, sync `tools/vscode/` into `.vscode/`,
   and align Cursor user theme settings via `tools/quest-log/quest-log.sh`

## Usage

```bash
hearthstone
hearthstone --yes
hearthstone --yes --force
hearthstone --help
```

## Options

- `-y`, `--yes` — skip Hearthstone confirmation
- `-f`, `--force` — run `trilliax --all` against the Zangarmarsh root before questlog
- `-h`, `--help` — print usage

## Confirmation

Without `--yes`, the script prints the planned steps and waits for `y` or `yes`.
Anything else cancels.

## Testing

```bash
bats tools/hearthstone/tests/hearthstone-tests.sh
```

## Error handling

Exits non-zero when the Zangarmarsh tree is invalid, any step fails, or you
cancel at the prompt.
