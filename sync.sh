#!/usr/bin/env bash
# Amplifier Sync - Pull all amplifier repos and update modules
# https://github.com/michaeljabbour/amplifier-sync

set -euo pipefail

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/amplifier-sync/config"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# Defaults (can be overridden in config)
AMPLIFIER_DEV_DIR="${AMPLIFIER_DEV_DIR:-$HOME/dev}"
AMPLIFIER_PATTERN="${AMPLIFIER_PATTERN:-amplifier*}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

sync_repos() {
  echo -e "${BLUE}🔄 Syncing all amplifier repos in ${AMPLIFIER_DEV_DIR}/${AMPLIFIER_PATTERN}${NC}"
  echo ""

  local success=0
  local failed=0
  local skipped=0

  for d in "$AMPLIFIER_DEV_DIR"/$AMPLIFIER_PATTERN/; do
    [ -d "$d/.git" ] || continue

    (
      cd "$d"
      name="$(basename "$d")"

      # Check for local changes
      local has_changes=0
      if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_changes=1
      fi

      if [ "$has_changes" -eq 1 ]; then
        echo -e "${YELLOW}=== $name ===${NC} (stashing changes)"
        git stash -q 2>/dev/null || true
      else
        echo -e "${GREEN}=== $name ===${NC}"
      fi

      # Pull with rebase
      if git pull --rebase 2>&1 | sed 's/^/  /'; then
        : # success
      else
        echo -e "  ${RED}Failed to pull${NC}"
      fi

      # Restore stashed changes
      if [ "$has_changes" -eq 1 ]; then
        git stash pop -q 2>/dev/null || echo -e "  ${YELLOW}Note: stash pop had conflicts${NC}"
      fi
    ) || true
  done

  echo ""
  echo -e "${BLUE}📦 Running amplifier update...${NC}"
  yes Y | amplifier update 2>/dev/null || amplifier update
  echo -e "${GREEN}✅ Done!${NC}"
}

configure() {
  mkdir -p "$(dirname "$CONFIG_FILE")"

  echo "Amplifier Sync Configuration"
  echo "============================"
  echo ""

  # Ask for dev directory
  read -p "Where are your amplifier repos? [$AMPLIFIER_DEV_DIR]: " input_dir
  local dev_dir="${input_dir:-$AMPLIFIER_DEV_DIR}"

  # Expand ~ if present
  dev_dir="${dev_dir/#\~/$HOME}"

  # Validate directory exists
  if [ ! -d "$dev_dir" ]; then
    echo -e "${RED}Error: Directory '$dev_dir' does not exist${NC}"
    exit 1
  fi

  # Ask for pattern
  read -p "Repo name pattern? [$AMPLIFIER_PATTERN]: " input_pattern
  local pattern="${input_pattern:-$AMPLIFIER_PATTERN}"

  # Count matching repos
  local count=$(ls -d "$dev_dir"/$pattern/ 2>/dev/null | wc -l | tr -d ' ')
  echo ""
  echo -e "${GREEN}Found $count repos matching '$pattern' in '$dev_dir'${NC}"

  # Save config
  cat > "$CONFIG_FILE" << EOF
# Amplifier Sync Configuration
AMPLIFIER_DEV_DIR="$dev_dir"
AMPLIFIER_PATTERN="$pattern"
EOF

  echo ""
  echo -e "${GREEN}Config saved to $CONFIG_FILE${NC}"
}

show_help() {
  echo "Amplifier Sync - Keep all your amplifier repos up to date"
  echo ""
  echo "Usage: amp-sync [command]"
  echo ""
  echo "Commands:"
  echo "  sync       Pull all repos and run amplifier update (default)"
  echo "  configure  Set up your dev directory and repo pattern"
  echo "  help       Show this help message"
  echo ""
  echo "Config: $CONFIG_FILE"
  echo "Current settings:"
  echo "  AMPLIFIER_DEV_DIR=$AMPLIFIER_DEV_DIR"
  echo "  AMPLIFIER_PATTERN=$AMPLIFIER_PATTERN"
}

# Main
case "${1:-sync}" in
  sync)
    sync_repos
    ;;
  configure|config|setup)
    configure
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    show_help
    exit 1
    ;;
esac
