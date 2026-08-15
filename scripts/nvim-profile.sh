#!/usr/bin/env bash
# Set Neovim profile: lazyvim, lazyvim-lite, or none (plain nvim).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lazyvim/lib/nvim-profile.sh
source "$SCRIPT_DIR/../lazyvim/lib/nvim-profile.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    none | off)
      clear_nvim_profile
      echo "nvim profile: none (plain nvim)"
      ;;
    lazyvim | lazyvim-lite)
      set_nvim_profile "$1"
      echo "nvim profile: $1"
      ;;
    status)
      echo "nvim profile: $(get_nvim_profile)"
      ;;
    *)
      echo "Usage: $(basename "$0") {none|lazyvim|lazyvim-lite|status}" >&2
      echo "  none         plain nvim (removes profile file)" >&2
      echo "  lazyvim      full LazyVim IDE profile" >&2
      echo "  lazyvim-lite editor-only LazyVim (no Mason/LSP/Node)" >&2
      exit 1
      ;;
  esac
fi
