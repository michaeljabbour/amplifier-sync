#!/usr/bin/env bash
# Amplifier Sync - Pull all amplifier repos and update modules
# 100% non-destructive: never force pushes or resets

set -euo pipefail

# Load config
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/amplifier-sync/config"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi

# Defaults
AMPLIFIER_DEV_DIR="${AMPLIFIER_DEV_DIR:-$HOME/dev}"
AMPLIFIER_PATTERN="${AMPLIFIER_PATTERN:-amplifier*}"

# Global: user's choice to apply to all remaining dirty repos
# Values: "" (ask each), "stash", "skip"
DIRTY_POLICY=""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

sync_repos() {
  echo -e "${BLUE}🔄 Syncing amplifier repos...${NC}"
  echo ""

  DIRTY_POLICY=""

  for d in "$AMPLIFIER_DEV_DIR"/$AMPLIFIER_PATTERN/; do
    [ -d "$d/.git" ] || continue
    sync_repo "$d"
  done

  echo ""
  echo -e "${BLUE}📦 Running amplifier update...${NC}"
  echo "Y" | amplifier update || amplifier update --yes 2>/dev/null || amplifier update
  echo -e "${GREEN}✅ Done!${NC}"
}

sync_repo() {
  local d="$1"
  local name="$(basename "$d")"

  cd "$d"

  # Check remote access
  if ! git ls-remote --exit-code origin &>/dev/null; then
    echo -e "${DIM}$name ${NC}${DIM}(no remote)${NC}"
    return 0
  fi

  # Fetch
  git fetch --quiet origin 2>/dev/null || true

  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # Check for local changes
  local is_dirty=0
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    is_dirty=1
  fi

  if [ "$is_dirty" -eq 1 ]; then
    handle_dirty_repo "$name" "$branch"
  else
    echo -e "${GREEN}$name${NC}"
    do_pull "$branch"
  fi
}

handle_dirty_repo() {
  local name="$1"
  local branch="$2"

  # If user already chose "all", apply that
  if [ "$DIRTY_POLICY" = "skip" ]; then
    echo -e "${DIM}$name (skipped - local changes)${NC}"
    return 0
  elif [ "$DIRTY_POLICY" = "stash" ]; then
    echo -e "${YELLOW}$name${NC} (stashing)"
    do_stash_pull "$branch"
    return 0
  fi

  # Ask user
  echo ""
  echo -e "${YELLOW}${BOLD}$name${NC} has local changes"
  echo -e "  [${BOLD}s${NC}]tash & sync   [${BOLD}S${NC}]tash ALL remaining"
  echo -e "  [${BOLD}k${NC}]ip this       [${BOLD}K${NC}]ip ALL remaining"
  read -p "  Choice: " -n 1 choice
  echo ""

  case "$choice" in
    s)
      echo -e "  ${YELLOW}stashing...${NC}"
      do_stash_pull "$branch"
      ;;
    S)
      DIRTY_POLICY="stash"
      echo -e "  ${YELLOW}stashing (and all remaining)...${NC}"
      do_stash_pull "$branch"
      ;;
    K)
      DIRTY_POLICY="skip"
      echo -e "  ${DIM}skipped (and all remaining)${NC}"
      ;;
    k|*)
      echo -e "  ${DIM}skipped${NC}"
      ;;
  esac
}

do_stash_pull() {
  local branch="$1"
  git stash --quiet
  do_pull "$branch"
  if ! git stash pop --quiet 2>/dev/null; then
    echo -e "  ${YELLOW}stash pop had conflicts - changes still in stash${NC}"
  fi
}

do_pull() {
  local branch="$1"
  if ! git pull --rebase 2>&1 | sed 's/^/  /'; then
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
      echo -e "  ${DIM}(no upstream for '$branch')${NC}"
    fi
  fi
}

configure() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  echo "Amplifier Sync Configuration"
  echo ""

  read -p "Dev directory? [$AMPLIFIER_DEV_DIR]: " input_dir
  local dev_dir="${input_dir:-$AMPLIFIER_DEV_DIR}"
  dev_dir="${dev_dir/#\~/$HOME}"

  [ -d "$dev_dir" ] || { echo "Directory not found"; exit 1; }

  read -p "Pattern? [$AMPLIFIER_PATTERN]: " input_pattern
  local pattern="${input_pattern:-$AMPLIFIER_PATTERN}"

  local count=$(ls -d "$dev_dir"/$pattern/ 2>/dev/null | wc -l | tr -d ' ')
  echo "Found $count repos"

  cat > "$CONFIG_FILE" << EOF
AMPLIFIER_DEV_DIR="$dev_dir"
AMPLIFIER_PATTERN="$pattern"
EOF
  echo "Saved to $CONFIG_FILE"
}

case "${1:-sync}" in
  sync) sync_repos ;;
  configure|config) configure ;;
  help|--help|-h)
    echo "amp-sync [sync|configure|help]"
    echo "  sync      - Pull all repos, run amplifier update"
    echo "  configure - Set dev directory and pattern"
    ;;
  *) echo "Unknown: $1"; exit 1 ;;
esac
