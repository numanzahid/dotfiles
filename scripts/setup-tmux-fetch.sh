#!/usr/bin/env bash
# Install an optional tmux fetch banner tool and enable it in tmux.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

usage() {
  cat <<EOF
Usage: $(basename "$0") [mode]

Modes:
  none        No fetch banner (default)
  fastfetch   Install fastfetch and enable tmux bindings
  pfetch      Install pfetch and enable tmux bindings

If mode is omitted and stdin is a TTY, an interactive prompt is shown.
Non-interactive default: none

Environment:
  TMUX_FETCH_MODE=none|fastfetch|pfetch   Skip prompt, use this mode

Examples:
  $(basename "$0")
  $(basename "$0") fastfetch
  TMUX_FETCH_MODE=pfetch $(basename "$0")
EOF
}

resolve_mode() {
  if [[ -n "${TMUX_FETCH_MODE:-}" ]]; then
    printf '%s\n' "$TMUX_FETCH_MODE"
    return 0
  fi

  if [[ $# -ge 1 && -n "${1:-}" ]]; then
    printf '%s\n' "$1"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    printf '%s\n' "none"
    return 0
  fi

  local choice
  echo >&2
  echo "Tmux fetch banner (optional):" >&2
  echo "  1) none       Plain panes (default)" >&2
  echo "  2) fastfetch  Rich system info banner" >&2
  echo "  3) pfetch     Minimal ASCII banner" >&2
  echo >&2
  read -r -p "Choose [1-3] (default 1): " choice

  case "${choice:-1}" in
    2 | fastfetch) printf '%s\n' "fastfetch" ;;
    3 | pfetch) printf '%s\n' "pfetch" ;;
    1 | none | "") printf '%s\n' "none" ;;
    *)
      echo "Invalid choice: $choice" >&2
      exit 1
      ;;
  esac
}

apply_mode() {
  local mode="$1"
  local dry_run="${2:-0}"

  case "$mode" in
    none | off | disable)
      if [[ "$dry_run" -eq 1 ]]; then
        echo "+ bash $SCRIPTS_DIR/enable-tmux-fetch.sh none"
      else
        bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" none
      fi
      ;;
    fastfetch)
      if [[ "$dry_run" -eq 1 ]]; then
        echo "+ bash $SCRIPTS_DIR/fastfetch-install-update.sh"
        echo "+ bash $SCRIPTS_DIR/enable-tmux-fetch.sh fastfetch"
      else
        bash "$SCRIPTS_DIR/fastfetch-install-update.sh"
        bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" fastfetch
      fi
      ;;
    pfetch)
      if [[ "$dry_run" -eq 1 ]]; then
        echo "+ bash $SCRIPTS_DIR/pfetch-install-update.sh"
        echo "+ bash $SCRIPTS_DIR/enable-tmux-fetch.sh pfetch"
      else
        bash "$SCRIPTS_DIR/pfetch-install-update.sh"
        bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" pfetch
      fi
      ;;
    *)
      echo "Unknown mode: $mode" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main() {
  local mode dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      none | fastfetch | pfetch | off | disable)
        mode="$1"
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  mode="${mode:-$(resolve_mode)}"
  apply_mode "$mode" "$dry_run"
}

main "$@"
