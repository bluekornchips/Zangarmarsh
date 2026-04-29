# Auras

Creates, refreshes, and removes user `.desktop` launcher entries for explicit AppImage files.

## What It Does

Auras writes one launcher at a time. You provide the full path to an AppImage and the launcher name:

```text
~/.local/share/applications/<name>.desktop
```

The name is used for both the desktop file stem and the desktop entry `Name=` value. Auras does not scan package directories and does not pick the newest AppImage.

## Managed Entry Safety

Auras writes these markers into every launcher it creates:

```text
X-Auras-Managed=true
X-Auras-Version=1
```

If a target `.desktop` file already exists, Auras overwrites it only when both current markers are present. This avoids clobbering launchers installed by a package manager or another tool.

`--debuff` follows the same rule. It removes only current Auras-managed launchers.

## Usage

```bash
# Create or refresh one managed launcher
./tools/auras/auras.sh --buff "$HOME/packages/Archon/Archon-1.0.0.AppImage" Archon

# Short form
./tools/auras/auras.sh -b "$HOME/packages/CurseForge/CurseForge.AppImage" CurseForge

# Remove one managed launcher
./tools/auras/auras.sh --debuff Archon

# Show help
./tools/auras/auras.sh --help
```

If the desktop launcher cache does not update immediately, refresh it:

```bash
update-desktop-database "$HOME/.local/share/applications"
```

## Behavior

- `--buff` requires an absolute `*.AppImage` or `*.appimage` path and a single-segment name.
- The AppImage must exist, be readable, and be executable.
- Existing unmarked `.desktop` files are not overwritten.
- `--debuff` removes only `.desktop` files with current Auras markers.
- App and desktop names must be a single path segment, with no slashes.
- Auras does not manage `Icon=` entries.

## Requirements

- Bash
- A Linux desktop environment that reads Freedesktop `.desktop` launchers

## Testing

```bash
bats tools/auras/tests/aura-tests.sh
```
