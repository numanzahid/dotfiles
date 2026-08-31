#!/usr/bin/env bash
# Install fastfetch and the compact tmux/shell banner.
# Not part of ./install.sh --all.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0
ART=""
STATUS=0
FASTFETCH_ART_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/fastfetch-art"

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"

usage() {
  cat <<'EOF'
Usage: ./install-fetch.sh [options]

Install fastfetch and the compact boxed banner (`banner.jsonc`).
Plain `fastfetch` uses the built-in default. Extra layouts are more
jsonc files under ~/.config/fastfetch/, not other fetch tools.

Options:
  --art 0|1|2 Text art for the banner
              0=none  1=current tmux logo  2=custom logo.txt
  --status    Show current text art
  --dry-run   Print actions without changing anything
  -h, --help  Show this help

Examples:
  ./install-fetch.sh
  ./install-fetch.sh --art 1
EOF
}

log() {
  printf '[fetch] %s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

link_path() {
  df_link_path "$@"
}

fastfetch_art_current() {
  if [[ -f "$FASTFETCH_ART_FILE" ]]; then
    tr -d '[:space:]' <"$FASTFETCH_ART_FILE"
    return 0
  fi
  printf '1'
}

set_fastfetch_art() {
  local choice="$1"
  case "$choice" in
    0 | 1 | 2) ;;
    none) choice="0" ;;
    tmux | current) choice="1" ;;
    custom | logo) choice="2" ;;
    *)
      echo "Unknown text art: $choice (use 0, 1, or 2)" >&2
      return 1
      ;;
  esac
  mkdir -p "$(dirname "$FASTFETCH_ART_FILE")"
  printf '%s\n' "$choice" >"$FASTFETCH_ART_FILE"
  log "text art: $choice"
}

link_fetch_configs() {
  mkdir -p "$TARGET_HOME/.config/tmux"
  mkdir -p "$TARGET_HOME/.config/fastfetch"

  link_path "$SOURCE_DIR/.config/fastfetch" "$TARGET_HOME/.config/fastfetch"
  link_path "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  link_path "$SCRIPTS_DIR/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
}

install_fastfetch_bin() {
  log "installing fastfetch"
  if [[ "$(df_host_os_id)" == "fedora" ]]; then
    # shellcheck source=scripts/lib/privilege.sh
    source "$SCRIPTS_DIR/lib/privilege.sh"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '+ dnf install -y fastfetch\n'
      return 0
    fi
    df_ensure_sudo
    df_run_privileged dnf install -y fastfetch
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/fastfetch-install-update.sh"
  else
    bash "$SCRIPTS_DIR/fastfetch-install-update.sh"
  fi
}

prompt_art() {
  local current choice
  current="$(fastfetch_art_current)"

  echo >&2
  echo "Fastfetch text art (tmux / new terminal banner):" >&2
  echo "  current: $current" >&2
  echo "  0) none" >&2
  echo "  1) current tmux logo" >&2
  echo "  2) custom (~/.config/fastfetch/logo.txt)" >&2
  echo >&2
  read -r -p "Choose [0-2] (default: $current): " choice

  case "${choice:-$current}" in
    0 | 1 | 2) printf '%s\n' "${choice:-$current}" ;;
    "") printf '%s\n' "$current" ;;
    *)
      echo "Invalid choice: $choice" >&2
      exit 1
      ;;
  esac
}

maybe_set_art() {
  local choice="$1"

  if [[ -n "$choice" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would set text art: $choice"
      return 0
    fi
    set_fastfetch_art "$choice"
    return 0
  fi

  if [[ -t 0 ]]; then
    choice="$(prompt_art)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would set text art: $choice"
      return 0
    fi
    set_fastfetch_art "$choice"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --status) STATUS=1 ;;
    --art)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --art needs 0, 1, or 2" >&2
        exit 1
      fi
      ART="$2"
      case "$ART" in
        0 | 1 | 2) ;;
        *)
          echo "ERROR: --art must be 0, 1, or 2" >&2
          exit 1
          ;;
      esac
      shift
      ;;
    none | off | disable | pfetch | both | fastfetch | status)
      echo "Banner is always fastfetch. Use: ./install-fetch.sh   or   ./install-fetch.sh --art 0|1|2" >&2
      exit 1
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$STATUS" -eq 1 ]]; then
  printf 'art: %s\n' "$(fastfetch_art_current)"
  exit 0
fi

link_fetch_configs
install_fastfetch_bin
maybe_set_art "$ART"
log "banner: ~/.config/fastfetch/banner.jsonc"
