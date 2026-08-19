#!/usr/bin/env bash
# Enable or disable fetch banners in tmux new window/pane bindings.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
FETCH_CONF="$TMUX_CONFIG_DIR/fetch.conf"

usage() {
  cat <<EOF
Usage: $(basename "$0") <mode>

Modes:
  none        Plain panes (default, no fetch banner)
  fastfetch   Show fastfetch on new window/pane (needs fastfetch installed)
  pfetch      Show pfetch on new window/pane (needs pfetch installed)
  status      Show current mode

Examples:
  $(basename "$0") fastfetch
  $(basename "$0") pfetch
  $(basename "$0") none

Edit layouts:
  fastfetch: $TMUX_CONFIG_DIR/fastfetch.jsonc
  pfetch:    ${XDG_CONFIG_HOME:-$HOME/.config}/pfetch/pfetchrc

Re-run after changing mode, or reload tmux: tmux source-file ~/.tmux.conf
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 is not installed." >&2
    echo "Install first:" >&2
    case "$1" in
      fastfetch) echo "  $DOTFILES_DIR/install-fetch.sh fastfetch" >&2 ;;
      pfetch) echo "  $DOTFILES_DIR/install-fetch.sh pfetch" >&2 ;;
    esac
    exit 1
  fi
}

link_fetch_mode() {
  local mode_file="$1"
  local src="$DOTFILES_DIR/home/.config/tmux/$mode_file"

  if [[ ! -f "$src" ]]; then
    echo "ERROR: missing template: $src" >&2
    exit 1
  fi

  mkdir -p "$TMUX_CONFIG_DIR"
  ln -sfn "$src" "$FETCH_CONF"
}

tmux_fetch_current_mode() {
  if [[ ! -e "$FETCH_CONF" ]]; then
    printf '%s\n' "none"
    return 0
  fi

  local target
  target="$(readlink -f "$FETCH_CONF" 2>/dev/null || readlink "$FETCH_CONF" 2>/dev/null || true)"
  case "$(basename "${target:-}")" in
    fetch-fastfetch.conf) printf '%s\n' "fastfetch" ;;
    fetch-pfetch.conf) printf '%s\n' "pfetch" ;;
    *) printf '%s\n' "none" ;;
  esac
}

show_status() {
  printf 'mode: %s\n' "$(tmux_fetch_current_mode)"
}

reload_tmux() {
  if [[ -n "${TMUX:-}" ]]; then
    tmux source-file "$HOME/.tmux.conf"
    if [[ -f "$FETCH_CONF" ]]; then
      tmux source-file "$FETCH_CONF"
    fi
    echo "Reloaded tmux config in current session."
  else
    echo "Open a new tmux session or run: tmux source-file ~/.tmux.conf"
  fi
}

apply_tmux_fetch_mode() {
  local mode="$1"
  local reload="${2:-1}"

  case "$mode" in
    none | off | disable)
      link_fetch_mode "fetch-none.conf"
      echo "Tmux fetch mode: none"
      ;;
    fastfetch)
      require_cmd fastfetch
      link_fetch_mode "fetch-fastfetch.conf"
      echo "Tmux fetch mode: fastfetch"
      echo "Config: $TMUX_CONFIG_DIR/fastfetch.jsonc"
      ;;
    pfetch)
      require_cmd pfetch
      link_fetch_mode "fetch-pfetch.conf"
      echo "Tmux fetch mode: pfetch"
      echo "Config: ${XDG_CONFIG_HOME:-$HOME/.config}/pfetch/pfetchrc"
      ;;
    *)
      echo "Unknown mode: $mode" >&2
      return 1
      ;;
  esac

  if [[ "$reload" -eq 1 ]]; then
    reload_tmux
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
  fi

  case "$1" in
    none | off | disable | fastfetch | pfetch)
      apply_tmux_fetch_mode "$1"
      ;;
    status)
      show_status
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Unknown mode: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
fi
