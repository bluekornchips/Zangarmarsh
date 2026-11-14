# Auras

Creates, refreshes, and removes user `.desktop` launcher entries and `~/.local/bin` symlinks for AppImage files.

```text
~/.local/share/applications/<name>.desktop
~/.local/bin/<name>  ->  resolved AppImage path
```

The name is used for the desktop file stem, the desktop entry `Name=` value, and the shell command under `~/.local/bin`.

With `--buff`, supply an explicit AppImage path.

## Managed Entry Safety

Auras writes these markers into every launcher it creates:

```text
X-Auras-Managed=true
X-Auras-Version=1
```

If a target `.desktop` file already exists, Auras overwrites it only when both current markers are present. This avoids clobbering launchers installed by a package manager or another tool.

`--debuff` follows the same rule for the desktop file and for a matching bin symlink. It removes only current Auras-managed launchers and symlinks that point at the same AppImage path as the desktop `Exec=` line.

## Usage

The CLI runs standalone. It loads its libraries from the checkout that holds the script and ignores any inherited `ZANGARMARSH_ROOT`.

```bash
# Create or refresh one managed launcher and shell command
./tools/auras/auras.sh --buff demoapp --appimage "$HOME/Apps/DemoApp/DemoApp-1.0.0.AppImage"

# Short AppImage flag
./tools/auras/auras.sh --buff SampleApp -a "$HOME/Apps/SampleApp/SampleApp.AppImage"

# Relative AppImage paths are resolved from the current directory
./tools/auras/auras.sh --buff demoapp --appimage ./Apps/DemoApp/DemoApp-1.0.0.AppImage

# Remove one managed launcher and bin symlink
./tools/auras/auras.sh --debuff demoapp

# Show help
./tools/auras/auras.sh --help
```

If the desktop launcher cache does not update immediately, refresh it:

```bash
update-desktop-database "$HOME/.local/share/applications"
```

## Options

Run `./tools/auras/auras.sh --help` for the flag list.

Exactly one of `--buff` or `--debuff` is allowed per run; giving more than one fails with `use only one of --buff or --debuff`. Running with none of them prints usage and exits with status 1. The required user environment input is `HOME`, which must be set because both outputs live under `~/.local`.

## Shell access

Buff creates `~/.local/bin/<name>` as a symlink to the resolved AppImage. For `demoapp` to work in zsh or bash, `~/.local/bin` must be on `PATH`. Many distros add it by default. If `command -v demoapp` is empty, add this to your shell config:

```bash
PATH="${HOME}/.local/bin:${PATH}"
```

`PATH` is already exported by your login shell, so assigning it is enough.

The `.desktop` file is for application menus and desktop environments. The bin symlink is for terminal use.

## Behavior

- Relative AppImage directories are resolved before writing `Exec=` and the bin symlink.
- The AppImage must exist, be readable, and be executable.
- Existing unmarked `.desktop` files are not overwritten. Unmanaged bin paths are refused unless the matching desktop is Auras-managed. A bin symlink that already points at the same AppImage is accepted as is.
- App and desktop names must be a single path segment, with no slashes.
- The AppImage path must be absolute after resolution, end in `.AppImage` or `.appimage`, and must not contain control characters, quotes, `%`, `$`, backticks, or backslashes.
- If creating the bin symlink fails, the desktop file stays in place. Run the same command again to repair the link.
- Name validation runs before any file is touched.
- Auras does not manage `Icon=` entries.

## Requirements

- Linux. Auras exits with status 1 on other hosts.
- Bash
- A desktop environment that reads Freedesktop `.desktop` launchers

## Testing

```bash
bats tools/auras/tests/*-tests.sh
```
