#!/usr/bin/env bash
# Compatibility wrapper. Profile logic lives in lazyvim/lib/nvim-profile.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lazyvim/lib/nvim-profile.sh
source "$SCRIPT_DIR/../lazyvim/lib/nvim-profile.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    minimal | lazyvim)
      set_nvim_profile "$1"
      echo "nvim profile: $1"
      ;;
    status)
      echo "nvim profile: $(get_nvim_profile)"
      ;;
    *)
      echo "Usage: $(basename "$0") {minimal|lazyvim|status}" >&2
      exit 1
      ;;
  esac
fi
