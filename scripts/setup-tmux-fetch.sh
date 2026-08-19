#!/usr/bin/env bash
# Compatibility wrapper. Fetch banners are installed by ./install-fetch.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$DOTFILES_DIR/install-fetch.sh" "$@"
