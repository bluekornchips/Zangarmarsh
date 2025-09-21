## Issue Link

- Issue Link: N/A (Internal enhancement)

## Description

Implement advanced ZSH command parsing system for Dalaran spellbook with comprehensive test coverage.

- Add `arcane-linguist.sh` for ultra-simple ZSH history parsing (stdin/stdout)
- Refactor `dalaran.sh` to integrate arcane linguist for complex command handling
- Restructure test directory with proper organization (`tests/` subdirectory)
- Add comprehensive test coverage including live testing with actual history files
- Enhance command silencing functionality with complex spell support
- Improve error handling and variable scope management
- Breaking changes: Test files moved to `tools/dalaran/tests/` directory

## Verification Steps

- [ ] Run `bats tools/dalaran/tests/arcane-linguist-tests.sh` - all 8 tests pass
- [ ] Run `bats tools/dalaran/tests/dalaran-tests.sh` - all 67 tests pass
- [ ] Verify live testing processes actual ZSH history successfully
- [ ] Confirm arcane linguist handles timestamped and plain command formats
- [ ] Test dalaran workflow creates archives and spellbooks from real command data
- [ ] Validate complex command silencing works with pipes, quotes, and special characters