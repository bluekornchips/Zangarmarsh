# Quest Log

Install the tracked plugin tree under `~/.cursor/plugins/local/quest-log`, sync rules into `~/.cursor/rules`, and overwrite host Cursor user settings from `tools/vscode/settings.json`. There is no generation step: `plugin/` is the plugin. Quest-log does not write project `.vscode/` files.

`make install` installs the plugin and user rules. `questlog` installs the plugin, syncs user rules, and overwrites Cursor user settings. Both paths share `apply_quest_log`.

User rules under `~/.cursor/rules` are the agent source of truth and apply in a new chat without Reload Window. The plugin path still carries skills and a copy of rules for the plugin layout. Skills discovery may still need a reload.

## Features

- Replaces `~/.cursor/plugins/local/quest-log` with a fresh copy of `tools/quest-log/plugin/` on every run
- Syncs `plugin/rules/*.mdc` into `~/.cursor/rules`, tracked by `.quest-log.manifest`, and prunes only previously managed rule files
- Overwrites host Cursor `User/settings.json` from `tools/vscode/settings.json`
- In full apply mode, syncs settings first and installs rules and the plugin only after settings succeed. Settings restore after a failed sync is best-effort. Plugin install itself stays self-atomic.

## Usage

```bash
# Source the main script, or run the standalone entry
source /path/to/zangarmarsh/zangarmarsh.sh
questlog

# Standalone, no prior source required
./tools/quest-log/quest-log.sh --help

# Show planned writes
questlog --dry-run
```

## Options and environment

| Flag              | Meaning                                  |
| ----------------- | ---------------------------------------- |
| `-r`, `--dry-run` | Report planned writes without making any |
| `-h`, `--help`    | Show usage                               |

- `DRY_RUN=true`: Same as `--dry-run`
- `QUEST_LOG_PLUGIN_DIR`: Override the plugin install path. It must still sit below `~/.cursor/plugins/local`
- `QUEST_LOG_RULES_DIR`: Override the user-rules install path. It must still be exactly `~/.cursor/rules`
- `PLUGIN_SOURCE_DIR`: Override the plugin source tree, default `tools/quest-log/plugin`
- `HOME`: Required; selects the plugin, rules, and Cursor settings destinations

Unknown flags and positional arguments fail with exit status 1. `--force` and `-f` are not supported.

## Behavior

- Always binds to the checkout that holds the script, ignoring an inherited `ZANGARMARSH_ROOT`.
- The plugin install path must be an absolute child of `~/.cursor/plugins/local` with no `..`, `.`, trailing slash, or symlink component below `HOME`; otherwise nothing is deleted or written.
- The rules install path must be exactly `~/.cursor/rules` with the same path-safety checks.
- The plugin is copied to a staging directory beside the install path and swapped in, so a failed copy leaves the previous install untouched.
- Rules sync copies each tracked `*.mdc` into `~/.cursor/rules`, prunes previously managed basenames that are no longer in source, then writes `.quest-log.manifest`. Other files in that directory stay put.
- If settings sync fails, previous Cursor settings are restored when a backup exists, or the incomplete file is removed when there were none. Restore is best-effort. Rules then the plugin are installed only after settings succeed.
- The summary reports plugin action, rules action, and counts of created, updated, and unchanged settings files. Any settings error makes the run exit with status 1.

## Plugin source layout

`tools/quest-log/plugin/` is committed, hand-authored, and installed as-is:

```text
plugin/
  .cursor-plugin/plugin.json   # plugin manifest
  rules/*.mdc                  # Cursor rules
  skills/*/SKILL.md            # blue-* and blueberry skills
```

This tracked plugin is the canonical agent configuration for this repository.
The plugin follows this repository's GPL-3.0-only license.

| Rule             | Role                                                          |
| ---------------- | ------------------------------------------------------------- |
| `always.mdc`     | Universal assistant behavior, safety, and response quality    |
| `never.mdc`      | Agent prohibitions: no legacy support, no prior-work records  |
| `shell.mdc`      | Shared shell quoting, status, and destructive-path rules      |
| `bash.mdc`       | Bash 3.2, locals, source guards, arrays, and Bats             |
| `zsh.mdc`        | Zsh 5 profile and Zsh-owned module rules                      |
| `python.mdc`     | Python standards; writing allowed, running needs approval     |
| `lua.mdc`        | Lua and WoW addon guidance                                    |
| `javascript.mdc` | JavaScript modules, async work, errors, and tests             |
| `typescript.mdc` | TypeScript typing, modules, async work, errors, and tests     |

## Skills

| Skill                    | Role                                        |
| ------------------------ | ------------------------------------------- |
| `blue-author`            | Current PR and issue delivery documents     |
| `blue-penmanship`        | Comment and doc claims vs current code      |
| `blue-review-comments`   | Short, courteous pull request comments      |
| `blue-review`            | Strict maintainability and ambition review  |
| `blue-review-bash`       | Bash repository review checklist            |
| `blue-review-lua`        | Lua review checklist                        |
| `blue-review-python`     | Python repository review checklist          |
| `blue-python-setup`      | Python project setup notes for the user     |
| `blue-review-typescript` | TypeScript review checklist                 |
| `blueberry`              | Master pass over blue-review and penmanship |

To add or change a rule or skill, edit the files under `plugin/` directly and run `questlog` to install the update.

## Install layout

- `tools/quest-log/plugin/`: tracked plugin source, installed as-is
- `~/.cursor/plugins/local/quest-log/`: live local plugin install refreshed every run
- `~/.cursor/rules/`: live user-rules sync from `plugin/rules/`, agent source of truth

The live installs are disposable. Edit the tracked source, then run `questlog` to refresh the local copies. Start a new Agent chat to pick up updated rules. Reload Window is not required for user rules.

## Cursor user settings

Canonical host Cursor settings live in `tools/vscode/settings.json`. Each `questlog` run copies that file over the host Cursor user settings:

- Linux: `~/.config/Cursor/User/settings.json`
- macOS: `~/Library/Application Support/Cursor/User/settings.json`

There is no project `.vscode/` sync. `tools/vscode/extensions.json` is a recommended extensions list only.

Edit `tools/vscode/settings.json`, then run `questlog` to apply.

## Testing

Install a Bats package so the `bats` binary is on your `PATH`, then run:

```bash
bats tools/quest-log/tests/quest-log-cli-tests.sh
bats tools/quest-log/tests/plugin-tests.sh
```

You can also run `bash -n tools/quest-log/quest-log.sh` for a quick syntax check without Bats.
