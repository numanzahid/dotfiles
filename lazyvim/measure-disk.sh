#!/usr/bin/env bash
# Measure LazyVim / Neovim disk usage after install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim/measure-disk.sh

Print disk usage of Neovim/LazyVim paths (~/.local/share/nvim, cache,
state, config, ~/.local/bin/tree-sitter). Read-only.

Options:
  -h, --help   Show this help
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  usage >&2
  exit 1
fi

paths=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
  "${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
  "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
  "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
  "${HOME}/.local/bin/tree-sitter"
)

total=0
printf '%-55s %12s\n' "PATH" "SIZE"
printf '%-55s %12s\n' "----" "----"

for path in "${paths[@]}"; do
  if [[ -e "$path" ]]; then
  size="$(disk_usage_bytes "$path")"
  total=$((total + size))
  printf '%-55s %12s\n' "$path" "$(format_bytes "$size")"
  fi
done

printf '%-55s %12s\n' "TOTAL (listed paths)" "$(format_bytes "$total")"
