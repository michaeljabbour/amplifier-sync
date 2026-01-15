# Amplifier Sync

Keep all your amplifier repos up to date with a single command.

## What it does

1. Finds all `amplifier*` repos in your dev directory
2. Stashes local changes (non-destructive)
3. Pulls with rebase
4. Restores stashed changes
5. Runs `amplifier update` with auto-yes

## Install

```bash
git clone https://github.com/michaeljabbour/amplifier-sync.git ~/dev/amplifier-sync
cd ~/dev/amplifier-sync
make install
```

Make sure `~/.local/bin` is in your PATH. Add to `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then configure:

```bash
amp-sync configure
```

## Usage

```bash
# Sync everything (default)
amp-sync

# Or use make
make sync

# Reconfigure
amp-sync configure
```

## Configuration

Config is stored in `~/.config/amplifier-sync/config`:

```bash
AMPLIFIER_DEV_DIR="$HOME/dev"
AMPLIFIER_PATTERN="amplifier*"
```

## Uninstall

```bash
cd ~/dev/amplifier-sync
make uninstall
```
