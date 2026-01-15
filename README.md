# amplifier-sync

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/michaeljabbour/amplifier-sync/actions/workflows/lint.yml/badge.svg)](https://github.com/michaeljabbour/amplifier-sync/actions/workflows/lint.yml)

Keep all your amplifier repos synced with a single command. Pulls with rebase, asks before touching repos with local changes, and runs `amplifier update` at the end.

## Prerequisites

- **git** - Required
- **bash** 3.2+ - Included on macOS and Linux
- **amplifier CLI** - Optional, for running `amplifier update`

## Platform Support

| OS | Support |
|----|---------|
| macOS | ✓ Native |
| Linux | ✓ Native |
| Windows | ✓ Via WSL |

## Install

```bash
git clone https://github.com/michaeljabbour/amplifier-sync.git ~/dev/amplifier-sync
cd ~/dev/amplifier-sync
make install
```

Ensure `~/.local/bin` is in your PATH. Add to `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then configure:

```bash
amp-sync configure
```

### Windows (WSL)

1. Install WSL: `wsl --install`
2. Open WSL terminal
3. Follow the Linux install instructions above

## Usage

```bash
# Sync all repos (default)
amp-sync

# Configure dev directory and pattern
amp-sync configure

# Show version
amp-sync --version

# Show help
amp-sync help
```

### Interactive Prompts

When a repo has local changes, you'll be asked:

```
amplifier-desktop has local changes
  [s]tash & sync   [S]tash ALL remaining
  [k]ip this       [K]ip ALL remaining
  Choice: _
```

- **s** - Stash, sync, unstash this repo
- **S** - Apply stash to this and all remaining dirty repos
- **k** - Skip this repo
- **K** - Skip this and all remaining dirty repos

## Configuration

Config file: `~/.config/amplifier-sync/config`

```bash
AMPLIFIER_DEV_DIR="$HOME/dev"
AMPLIFIER_PATTERN="amplifier*"
```

## Safety

This tool is 100% non-destructive:

- Asks before stashing local changes
- Uses `git pull --rebase` (no merge commits)
- Never uses `git reset --hard`, force push, or anything that loses work
- Skips repos with no remote access
- Warns if `amplifier` CLI is not installed (doesn't fail)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `git: command not found` | Install git |
| `amplifier: command not found` | Install amplifier CLI, or ignore (sync still works) |
| `no remote access` | Check GitHub authentication and network |
| `no upstream for 'branch'` | Branch has no tracking remote, fetched only |

## Uninstall

```bash
cd ~/dev/amplifier-sync
make uninstall
```

## License

MIT
