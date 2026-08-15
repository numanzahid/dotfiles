#!/usr/bin/env bash
# Shared helpers for the LazyVim-lite installer (reuses lazyvim/lib).
set -euo pipefail

LAZYVIM_LITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAZYVIM_DIR="$LAZYVIM_LITE_DIR/../lazyvim"
export LAZYVIM_INSTALL_CONF="${LAZYVIM_INSTALL_CONF:-$LAZYVIM_LITE_DIR/install.conf}"

# shellcheck source=../../lazyvim/lib/common.sh
source "$LAZYVIM_DIR/lib/common.sh"

log() {
  printf '[lazyvim-lite] %s\n' "$*"
}

warn() {
  printf '[lazyvim-lite] WARN: %s\n' "$*" >&2
}

die() {
  printf '[lazyvim-lite] ERROR: %s\n' "$*" >&2
  exit 1
}
