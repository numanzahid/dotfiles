#!/usr/bin/env bash
# Install fastfetch and the boxed config (~/.config/fastfetch/config.jsonc).
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
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPTS_DIR/lib/privilege.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/pfetch-remove.sh
source "$SCRIPTS_DIR/lib/pfetch-remove.sh"
# shellcheck source=scripts/fastfetch-banner.sh
source "$SCRIPTS_DIR/fastfetch-banner.sh"

usage() {
  cat <<'EOF'
Usage: ./install-fetch.sh [options]

Install fastfetch and the boxed layout (~/.config/fastfetch/config.jsonc).
Plain `fastfetch`, tmux, and `fetch` all use that one config.
Art is chosen here (or --art) and applied via --logo.
Removes leftover pfetch from the old GitHub install if it is still on
this machine (/usr/local/bin/pfetch, /opt/pfetch, config/updater files).

Text art files are ~/.config/fastfetch/artN.txt (1 is default).
Add art4.txt, art5.txt, ... and they show up automatically. 0 is none.
Repo templates (edit these):
  home/.config/fastfetch/custom-fetch-art.example.txt
  home/.config/fastfetch/custom-fetch-padding.example.jsonc
Live copies (not in git), seeded once, never overwritten:
  ~/.config/custom-fetch-art.txt  (--art c)
  ~/.config/custom-fetch-padding.jsonc

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

df_remove_legacy_pfetch
link_fetch_configs
install_fastfetch_bin
df_ff_art_ensure_custom
df_ff_padding_ensure
df_ff_maybe_set_art "$ART"
log "config: ~/.config/fastfetch/config.jsonc"
