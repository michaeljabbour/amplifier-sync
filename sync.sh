#!/usr/bin/env bash
# Amplifier Sync - Pull all amplifier repos and update modules
# 100% non-destructive: never force pushes or resets

set -euo pipefail

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/amplifier-sync/config"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# Defaults (can be overridden in config)
AMPLIFIER_DEV_DIR="${AMPLIFIER_DEV_DIR:-$HOME/dev}"
AMPLIFIER_PATTERN="${AMPLIFIER_PATTERN:-amplifier*}"

# Global state for "apply to all" choices
STASH_POLICY=""  # "", "stash-all", "skip-all"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

sync_repos() {
  echo -e "${BLUE}🔄 Syncing amplifier repos in ${AMPLIFIER_DEV_DIR}/${AMPLIFIER_PATTERN}${NC}"
  echo ""

  # Reset global state
  STASH_POLICY=""

  # First pass: collect repos and their status
  local repos_clean=()
  local repos_dirty=()
  local repos_skip=()

  for d in "$AMPLIFIER_DEV_DIR"/$AMPLIFIER_PATTERN/; do
    [ -d "$d/.git" ] || continue
    local name="$(basename "$d")"

    # Check if remote exists and is reachable
    if ! git -C "$d" ls-remote --exit-code origin &>/dev/null; then
      repos_skip+=("$name")
      continue
    fi

    # Check for local changes
    if ! git -C "$d" diff --quiet 2>/dev/null || ! git -C "$d" diff --cached --quiet 2>/dev/null; then
      repos_dirty+=("$name:$d")
    else
      repos_clean+=("$name:$d")
    fi
  done

  # Show summary
  echo -e "${GREEN}Clean repos:${NC} ${#repos_clean[@]}"
  if [ ${#repos_dirty[@]} -gt 0 ]; then
    echo -e "${YELLOW}Repos with local changes:${NC} ${#repos_dirty[@]}"
    for entry in "${repos_dirty[@]}"; do
      local name="${entry%%:*}"
      echo -e "  - $name"
    done
  fi
  if [ ${#repos_skip[@]} -gt 0 ]; then
    echo -e "${DIM}Skipping (no remote):${NC} ${#repos_skip[@]}"
  fi
  echo ""

  # If there are dirty repos, ask what to do
  if [ ${#repos_dirty[@]} -gt 0 ]; then
    echo -e "${BOLD}What to do with repos that have local changes?${NC}"
    echo -e "  [${BOLD}s${NC}] Stash, sync, unstash each"
    echo -e "  [${BOLD}k${NC}] Skip all dirty repos"
    echo -e "  [${BOLD}i${NC}] Ask individually for each"
    echo ""
    read -p "Choice [s/k/i]: " -n 1 choice
    echo ""
    echo ""

    case "$choice" in
      s|S) STASH_POLICY="stash-all" ;;
      k|K) STASH_POLICY="skip-all" ;;
      i|I|"") STASH_POLICY="ask" ;;
      *) STASH_POLICY="skip-all" ;;
    esac
  fi

  # Sync clean repos first
  for entry in "${repos_clean[@]}"; do
    local name="${entry%%:*}"
    local d="${entry#*:}"
    sync_repo "$d" "$name" "clean"
  done

  # Then handle dirty repos
  for entry in "${repos_dirty[@]}"; do
    local name="${entry%%:*}"
    local d="${entry#*:}"
    sync_repo "$d" "$name" "dirty"
  done

  # Show skipped repos
  for name in "${repos_skip[@]}"; do
    echo -e "${DIM}=== $name === (no remote)${NC}"
  done

  echo ""
  echo -e "${BLUE}📦 Running amplifier update...${NC}"
  echo "Y" | amplifier update || amplifier update --yes 2>/dev/null || amplifier update
  echo -e "${GREEN}✅ Done!${NC}"
}

sync_repo() {
  local d="$1"
  local name="$2"
  local status="$3"  # "clean" or "dirty"

  cd "$d"

  # Fetch first (always safe)
  git fetch --quiet origin 2>/dev/null || true

  # Get current branch
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  if [ "$status" = "dirty" ]; then
    # Handle based on policy
    if [ "$STASH_POLICY" = "skip-all" ]; then
      echo -e "${DIM}=== $name === (skipped, has local changes)${NC}"
      return 0
    elif [ "$STASH_POLICY" = "ask" ]; then
      echo ""
      echo -e "${YELLOW}=== $name ===${NC} has local changes"
      read -p "  [s]tash & sync, [k]skip? " -n 1 choice
      echo ""
      if [ "$choice" != "s" ] && [ "$choice" != "S" ]; then
        echo -e "  ${DIM}(skipped)${NC}"
        return 0
      fi
    fi

    # Stash, sync, unstash
    echo -e "${YELLOW}=== $name ===${NC} (stashing)"
    git stash --quiet

    sync_pull "$current_branch"

    if ! git stash pop --quiet 2>/dev/null; then
      echo -e "  ${YELLOW}Note: stash pop had conflicts, changes still in stash${NC}"
    fi
  else
    # Clean repo - just sync
    echo -e "${GREEN}=== $name ===${NC}"
    sync_pull "$current_branch"
  fi
}

sync_pull() {
  local current_branch="$1"

  # Try to pull with rebase
  if git pull --rebase 2>&1 | sed 's/^/  /'; then
    return 0
  else
    # Check if we're on a branch without upstream
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
      echo -e "  ${DIM}(branch '$current_branch' has no upstream, fetched only)${NC}"
    fi
    return 1
  fi
}

configure() {
  mkdir -p "$(dirname "$CONFIG_FILE")"

  echo "Amplifier Sync Configuration"
  echo "============================"
  echo ""

  read -p "Where are your amplifier repos? [$AMPLIFIER_DEV_DIR]: " input_dir
  local dev_dir="${input_dir:-$AMPLIFIER_DEV_DIR}"
  dev_dir="${dev_dir/#\~/$HOME}"

  if [ ! -d "$dev_dir" ]; then
    echo -e "${RED}Error: Directory '$dev_dir' does not exist${NC}"
    exit 1
  fi

  read -p "Repo name pattern? [$AMPLIFIER_PATTERN]: " input_pattern
  local pattern="${input_pattern:-$AMPLIFIER_PATTERN}"

  local count=$(ls -d "$dev_dir"/$pattern/ 2>/dev/null | wc -l | tr -d ' ')
  echo ""
  echo -e "${GREEN}Found $count repos matching '$pattern' in '$dev_dir'${NC}"

  cat > "$CONFIG_FILE" << EOF
# Amplifier Sync Configuration
AMPLIFIER_DEV_DIR="$dev_dir"
AMPLIFIER_PATTERN="$pattern"
EOF

  echo -e "${GREEN}Config saved to $CONFIG_FILE${NC}"
}

show_help() {
  cat << EOF
Amplifier Sync - Keep all your amplifier repos up to date

Usage: amp-sync [command]

Commands:
  sync       Pull all repos and run amplifier update (default)
  configure  Set up your dev directory and repo pattern
  help       Show this help message

Safety: 100% non-destructive
  - Shows summary before syncing
  - Asks before touching repos with local changes
  - Never uses git reset, force push, or anything destructive

Config: $CONFIG_FILE
  AMPLIFIER_DEV_DIR=$AMPLIFIER_DEV_DIR
  AMPLIFIER_PATTERN=$AMPLIFIER_PATTERN
EOF
}

# Main
case "${1:-sync}" in
  sync) sync_repos ;;
  configure|config|setup) configure ;;
  help|--help|-h) show_help ;;
  *) echo "Unknown command: $1"; show_help; exit 1 ;;
esac
