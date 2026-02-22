# Ice Block

Backs up a predefined list of dotfiles and directories to `~/.ice-block/<hostname>/`. Uses `cp -a` (archive mode) to preserve permissions, timestamps, and symlinks.

## Backed-up Paths

| Path             | Description         |
| ---------------- | ------------------- |
| `~/.aliases`     | Shell aliases       |
| `~/.bashrc`      | Bash config         |
| `~/.zshrc`       | Zsh config          |
| `~/.zsh_history` | Zsh history         |
| `~/.gitconfig`   | Git config          |
| `~/.ssh`         | SSH keys and config |

Missing paths are skipped without failing.

## Usage

```bash
bash tools/ice-block/ice-block.sh
```

The backup is written to `~/.ice-block/<hostname>/`.

## Testing

```bash
bats tools/ice-block/tests/ice-block-tests.sh
```
