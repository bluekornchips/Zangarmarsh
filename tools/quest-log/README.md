# Quest Log

Install the tracked plugin tree under `~/.cursor/plugins/local/quest-log`, sync rules into `~/.cursor/rules`, and overwrite host Cursor user settings from `tools/vscode/settings.json`. There is no generation step: `plugin/` is the plugin. Quest-log does not write project `.vscode/` files.

`make install` and `questlog` both install the plugin, sync user rules, and overwrite Cursor user settings through `apply_quest_log`. `make install` also installs the bundled DejaVu Sans Mono font.

User rules under `~/.cursor/rules` are the agent source of truth and apply in a new chat without Reload Window. The plugin path still carries skills and a copy of rules for the plugin layout. Skills discovery may still need a reload.

## Features

- Replaces `~/.cursor/plugins/local/quest-log` with a fresh copy of `tools/quest-log/plugin/` on every run
- Syncs `plugin/rules/*.mdc` into `~/.cursor/rules` as `zangarmarsh-*.mdc` files and deletes only managed files whose source rule is gone
- Overwrites host Cursor `User/settings.json` from `tools/vscode/settings.json`
- Writes settings first, then rules, then the plugin, and checks the plugin and rules destinations before the first write

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

Run `questlog --help` for the flags.

- `DRY_RUN`: `true` or `false`. Any other value stops the run before any write.
- `PLUGIN_SOURCE_DIR`: Plugin source tree, default `tools/quest-log/plugin`
- `HOME`: Required; selects the plugin, rules, and Cursor settings destinations

## Behavior

- Always binds to the checkout that holds the script, ignoring an inherited `ZANGARMARSH_ROOT`.
- The plugin and rules install paths pass `owned_path` before the first write. A symlink in either path stops the run before anything is written.
- Dry run writes nothing, including directories, and prints what it would change.
- The plugin is copied to `quest-log.staging` beside its install path. The live install moves to `quest-log.removing`, the staged copy moves into place, and `quest-log.removing` is deleted. A failed copy leaves the live install untouched. A run that stops between the two moves leaves the plugin missing until the next run, which clears leftover staging and removing paths and copies again.
- Each tracked rule is written as `zangarmarsh-<name>.mdc` through `write_atomic`. Managed `zangarmarsh-*.mdc` files with no source rule are deleted. Files without the `zangarmarsh-` prefix are never touched.
- Settings are written first. A failed settings write stops the run before any rule or plugin change.
- Rules and settings print `Created`, `Updated`, `No changes`, or `Would write` for each file.

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
| `javascript.mdc` | JavaScript and shared TypeScript modules, async, and errors   |
| `typescript.mdc` | TypeScript strict typing, catches, headers, and type checks   |

## Skills

| Skill                    | Role                                        |
| ------------------------ | ------------------------------------------- |
| `blue-author`            | Current PR and issue delivery documents     |
| `blue-compensate`        | Compensating-code inventory and redesigns   |
| `blue-diagnose`          | Feedback-loop-first bug diagnosis           |
| `blue-penmanship`        | Comment and doc claims vs current code      |
| `blue-review-comments`   | Short, courteous pull request comments      |
| `blue-review`            | Strict maintainability and ambition review  |
| `blue-review-bash`       | Bash repository review checklist            |
| `blue-review-lua`        | Lua review checklist                        |
| `blue-review-python`     | Python repository review checklist          |
| `blue-review-security`   | Trust-boundary security review              |
| `blue-scribe`            | Writing rules, skills, and READMEs          |
| `blue-python-setup`      | Python project setup notes for the user     |
| `blue-review-typescript` | TypeScript review checklist                 |
| `blueberry`              | Master pass over blue-review and penmanship |

To add or change a rule or skill, edit the files under `plugin/` directly and run `questlog` to install the update.

## Install layout

- `tools/quest-log/plugin/`: tracked plugin source, installed as-is
- `~/.cursor/plugins/local/quest-log/`: live local plugin install refreshed every run
- `~/.cursor/rules/zangarmarsh-*.mdc`: live user-rules sync from `plugin/rules/`, agent source of truth

The live installs are disposable. Edit the tracked source, then run `questlog` to refresh the local copies. Start a new Agent chat to pick up updated rules. Reload Window is not required for user rules.

## Cursor user settings

Canonical host Cursor settings live in `tools/vscode/settings.json`. Each `questlog` run writes that file over the host Cursor user settings when the content differs:

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
