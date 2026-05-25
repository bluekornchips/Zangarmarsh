# Auras

Creates, refreshes, and removes user `.desktop` launcher entries and `~/.local/bin` symlinks for explicit AppImage files.

## What It Does

Auras installs one AppImage at a time. You provide a name and an AppImage path:

```text
~/.local/share/applications/<name>.desktop
~/.local/bin/<name>  ->  resolved AppImage path
```

The name is used for the desktop file stem, the desktop entry `Name=` value, and the shell command under `~/.local/bin`. Auras does not scan package directories and does not pick the newest AppImage.

## Managed Entry Safety

Auras writes these markers into every launcher it creates:

```text
X-Auras-Managed=true
X-Auras-Version=1
```

If a target `.desktop` file already exists, Auras overwrites it only when both current markers are present. This avoids clobbering launchers installed by a package manager or another tool.

`--debuff` follows the same rule for the desktop file and for a matching bin symlink. It removes only current Auras-managed launchers and symlinks that point at the same AppImage path as the desktop `Exec=` line.

## Usage

```bash
# Create or refresh one managed launcher and shell command
./tools/auras/auras.sh --buff archon --appimage "$HOME/packages/Archon/Archon-1.0.0.AppImage"

# Short AppImage flag
./tools/auras/auras.sh --buff CurseForge -a "$HOME/packages/CurseForge/CurseForge.AppImage"

# Relative AppImage paths are resolved from the current directory
./tools/auras/auras.sh --buff archon --appimage ./packages/Archon/Archon-1.0.0.AppImage

# Remove one managed launcher and bin symlink
./tools/auras/auras.sh --debuff archon

# Show help
./tools/auras/auras.sh --help
```

If the desktop launcher cache does not update immediately, refresh it:

```bash
update-desktop-database "$HOME/.local/share/applications"
```

## Shell access

Buff creates `~/.local/bin/<name>` as a symlink to the resolved AppImage. For `archon` to work in zsh or bash, `~/.local/bin` must be on `PATH`. Many distros add it by default. If `command -v archon` is empty, add this to your shell config:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

The `.desktop` file is for application menus and desktop environments. The bin symlink is for terminal use.

## Behavior

- `--buff` requires `NAME` and `--appimage PATH`.
- `--debuff` requires `NAME` only. `--appimage` is rejected with debuff.
- `-b` and `--buff` set the application name. `-d` and `--debuff` remove a managed install.
- `-a` and `--appimage` set the AppImage path. Flags may appear in any order with buff.
- Relative AppImage directories are resolved before writing `Exec=` and the bin symlink.
- The AppImage must exist, be readable, and be executable.
- Existing unmarked `.desktop` files and unmanaged bin paths are not overwritten.
- `--debuff` removes only `.desktop` files with current Auras markers and matching bin symlinks.
- App and desktop names must be a single path segment, with no slashes.
- Auras does not manage `Icon=` entries.

## Requirements

- Bash
- A Linux desktop environment that reads Freedesktop `.desktop` launchers

## Testing

```bash
bats tools/auras/tests/*-tests.sh
```
