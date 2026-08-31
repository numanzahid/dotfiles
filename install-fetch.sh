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

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/fastfetch-banner.sh
source "$SCRIPTS_DIR/fastfetch-banner.sh"

usage() {
  cat <<'EOF'
Usage: ./install-fetch.sh [options]

Install fastfetch and the compact boxed banner (`banner.jsonc`).
Plain `fastfetch` uses the built-in default. Extra layouts are more
jsonc files under ~/.config/fastfetch/, not other fetch tools.

Text art files are ~/.config/fastfetch/artN.txt (1 is default).
Add art4.txt, art5.txt, ... and they show up automatically. 0 is none.
Custom art (not in git): ~/.config/custom-fetch-art.txt  (--art c)
Created from art1 if missing, never overwritten.
Local padding (not in git): ~/.config/custom-fetch-padding.jsonc
Created with banner defaults if missing, never overwritten. Edit right
to change the gap between art and the box.

Options:
  --art N     Set text art (0=none, 1=default, artN.txt, or c=custom)
  --status    Show current text art (with preview)
  --dry-run   Print actions without changing anything
  -h, --help  Show this help

Examples:
  ./install-fetch.sh
  ./install-fetch.sh --art 1
  ./install-fetch.sh --art c
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
  local current choice csv
  current="$(df_ff_art_current)"
  csv="$(df_ff_art_choices_csv)"

  echo >&2
  echo "Fastfetch text art (tmux / new terminal banner):" >&2
  echo "  current: $current" >&2
  df_ff_art_show_all >&2
  read -r -p "Choose [$csv] (default: $current): " choice

  choice="${choice:-$current}"
  if df_ff_art_valid "$choice"; then
    printf '%s\n' "$choice"
    return 0
  fi
  echo "Invalid choice: $choice" >&2
  exit 1
}

maybe_set_art() {
  local choice="$1"

  if [[ -n "$choice" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would set text art: $choice"
      return 0
    fi
    df_ff_art_set "$choice"
    log "text art: $choice"
    return 0
  fi

  if [[ -t 0 ]]; then
    choice="$(prompt_art)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would set text art: $choice"
      return 0
    fi
    df_ff_art_set "$choice"
    log "text art: $choice"
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
        echo "ERROR: --art needs 0, N, or c (custom)" >&2
        exit 1
      fi
      ART="$2"
      shift
      ;;
    none | off | disable | pfetch | both | fastfetch | status)
      echo "Banner is always fastfetch. Use: ./install-fetch.sh   or   ./install-fetch.sh --art N" >&2
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

# List/preview the files in this clone (same names after link).
DF_FF_ART_DIR="$SOURCE_DIR/.config/fastfetch"
export DF_FF_ART_DIR

if [[ "$STATUS" -eq 1 ]]; then
  printf 'art: %s\n' "$(df_ff_art_current)"
  df_ff_art_preview "$(df_ff_art_current)"
  exit 0
fi

if [[ -n "$ART" ]] && ! df_ff_art_valid "$ART"; then
  echo "ERROR: --art $ART is not available (use $(df_ff_art_choices_csv))" >&2
  exit 1
fi

link_fetch_configs
install_fastfetch_bin
df_ff_art_ensure_custom
df_ff_padding_ensure
maybe_set_art "$ART"
log "banner: ~/.config/fastfetch/banner.jsonc"
