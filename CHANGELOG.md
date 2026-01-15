# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-15

### Added
- Initial release
- `amp-sync` command to sync all amplifier repos
- Interactive prompts for repos with local changes
- `amp-sync configure` to set dev directory and pattern
- Non-destructive git operations (stash/unstash, rebase)
- Automatic `amplifier update` with auto-yes
- Config file support (`~/.config/amplifier-sync/config`)

### Platform Support
- macOS (native bash)
- Linux (native bash)
- Windows (via WSL)
