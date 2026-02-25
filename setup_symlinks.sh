#!/usr/bin/env bash
#
# setup_symlinks.sh
#
# Creates a symlink from this repo's data/ to the Box-synced chehalis/data folder.
# Run once after cloning (or whenever the symlink needs to be recreated).
#
# Usage:
#   bash setup_symlinks.sh
#   bash setup_symlinks.sh /path/to/box/chehalis/data   # override auto-detection
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Detect or accept the Box chehalis/data root --------------------------------

if [[ -n "${1:-}" ]]; then
    BOX_DATA="$1"
else
    # Try common Box mount names on macOS
    BOX_BASE="$HOME/Library/CloudStorage"
    if [[ -d "$BOX_BASE/Box-Box/chehalis/data" ]]; then
        BOX_DATA="$BOX_BASE/Box-Box/chehalis/data"
    elif [[ -d "$BOX_BASE/Box/chehalis/data" ]]; then
        BOX_DATA="$BOX_BASE/Box/chehalis/data"
    elif [[ -d "$HOME/Box/chehalis/data" ]]; then
        BOX_DATA="$HOME/Box/chehalis/data"
    else
        echo "ERROR: Could not find chehalis/data in Box."
        echo "Searched:"
        echo "  $BOX_BASE/Box-Box/chehalis/data"
        echo "  $BOX_BASE/Box/chehalis/data"
        echo "  $HOME/Box/chehalis/data"
        echo ""
        echo "Re-run with an explicit path:"
        echo "  bash setup_symlinks.sh /path/to/box/chehalis/data"
        exit 1
    fi
fi

echo "Using Box chehalis/data at: $BOX_DATA"

# --- Create symlink -----------------------------------------------------------

LINK_PATH="$REPO_DIR/data"

# Remove existing symlink or empty directory; warn if something else is in the way
if [[ -L "$LINK_PATH" ]]; then
    rm "$LINK_PATH"
elif [[ -d "$LINK_PATH" && -z "$(ls -A "$LINK_PATH")" ]]; then
    rmdir "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
    echo "WARNING: $LINK_PATH exists and is not an empty directory or symlink — skipping."
    exit 1
fi

if [[ -d "$BOX_DATA" ]]; then
    ln -s "$BOX_DATA" "$LINK_PATH"
    echo "  OK  $LINK_PATH -> $BOX_DATA"
else
    echo "  MISSING  $BOX_DATA  (symlink not created)"
    exit 1
fi

echo ""
echo "Done. Symlink created."
