#!/usr/bin/env bash
# Neovim config profile: minimal (default), lazyvim, or lazyvim-lite.
set -euo pipefail

nvim_profile_file() {
  printf '%s/dotfiles/nvim-profile' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

get_nvim_profile() {
  local file
  file="$(nvim_profile_file)"
  if [[ -f "$file" ]]; then
    tr -d '[:space:]' <"$file"
  else
    echo "minimal"
  fi
}

set_nvim_profile() {
  local profile="$1"
  local file
  file="$(nvim_profile_file)"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$profile" >"$file"
}

ensure_nvim_profile_default() {
  local file
  file="$(nvim_profile_file)"
  if [[ ! -f "$file" ]]; then
    set_nvim_profile "minimal"
  fi
}
