#!/usr/bin/env bash
# Optional tmux/shell fetch banners (fastfetch and/or pfetch).
# Not part of ./install.sh --all. Re-running install.sh never changes fetch mode.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0
MODE=""
ART=""

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/enable-tmux-fetch.sh
source "$SCRIPTS_DIR/enable-tmux-fetch.sh"

usage() {
  cat <<'EOF'
Usage: ./install-fetch.sh [mode] [options]

Install fetch banner tools and/or select the active tmux/shell banner.

Modes:
  none        Disable banner (does not uninstall binaries)
  fastfetch   Install fastfetch and enable it
  pfetch      Install pfetch and enable it
  both        Install both tools; keep the current banner if one is set
  status      Show current banner mode

If mode is omitted and stdin is a TTY, an interactive prompt is shown.
If mode is omitted and stdin is not a TTY, the current setup is left unchanged.

Options:
  --art 0|1|2 Text art for the tmux/new-terminal banner
              0=none  1=current tmux logo  2=custom logo.txt
  --dry-run   Print actions without changing anything
  -h, --help  Show this help

Examples:
  ./install-fetch.sh
  ./install-fetch.sh fastfetch
  ./install-fetch.sh fastfetch --art 1
  ./install-fetch.sh both
  ./install-fetch.sh none
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
  mkdir -p "$TARGET_HOME/.config/pfetch"
  mkdir -p "$TARGET_HOME/.config/fastfetch"

  link_path "$SOURCE_DIR/.config/fastfetch" "$TARGET_HOME/.config/fastfetch"
  link_path "$SOURCE_DIR/.config/tmux/fastfetch.jsonc" "$TARGET_HOME/.config/tmux/fastfetch.jsonc"
  link_path "$SOURCE_DIR/.config/tmux/fastfetch.jsonc" "$TARGET_HOME/.config/fastfetch/tmux2.jsonc"
  link_path "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  link_path "$SCRIPTS_DIR/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
  link_path "$SOURCE_DIR/.config/tmux/fetch-none.conf" "$TARGET_HOME/.config/tmux/fetch-none.conf"
  link_path "$SOURCE_DIR/.config/tmux/fetch-fastfetch.conf" "$TARGET_HOME/.config/tmux/fetch-fastfetch.conf"
  link_path "$SOURCE_DIR/.config/tmux/fetch-pfetch.conf" "$TARGET_HOME/.config/tmux/fetch-pfetch.conf"
  link_path "$SOURCE_DIR/.config/pfetch/pfetchrc" "$TARGET_HOME/.config/pfetch/pfetchrc"

  local dest="$TARGET_HOME/.config/tmux/fetch.conf"
  if [[ -e "$dest" || -L "$dest" ]]; then
    log "keeping existing fetch mode: $(tmux_fetch_current_mode)"
    return 0
  fi

  log "default tmux fetch mode: none -> $dest"
  run ln -sfn "$SOURCE_DIR/.config/tmux/fetch-none.conf" "$dest"
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

install_pfetch_bin() {
  log "installing pfetch"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/pfetch-install-update.sh"
  else
    bash "$SCRIPTS_DIR/pfetch-install-update.sh"
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
  echo "Plain 'fastfetch' uses the built-in default config and distro logo." >&2
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

enable_mode() {
  local mode="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" "$mode"
    return 0
  fi
  apply_tmux_fetch_mode "$mode"
}

prompt_mode() {
  local current choice
  current="$(tmux_fetch_current_mode)"

  echo >&2
  echo "Tmux fetch banner (optional):" >&2
  echo "  current: $current" >&2
  echo "  1) none       Disable banner" >&2
  echo "  2) fastfetch  Install and enable fastfetch" >&2
  echo "  3) pfetch     Install and enable pfetch" >&2
  echo "  4) both       Install both; keep current banner if set" >&2
  echo >&2
  read -r -p "Choose [1-4] (default: keep $current): " choice

  case "${choice:-}" in
    "") printf '%s\n' "keep" ;;
    1 | none) printf '%s\n' "none" ;;
    2 | fastfetch) printf '%s\n' "fastfetch" ;;
    3 | pfetch) printf '%s\n' "pfetch" ;;
    4 | both) printf '%s\n' "both" ;;
    *)
      echo "Invalid choice: $choice" >&2
      exit 1
      ;;
  esac
}

prompt_active_after_both() {
  local current choice
  current="$(tmux_fetch_current_mode)"

  if [[ "$current" == "fastfetch" || "$current" == "pfetch" ]]; then
    printf '%s\n' "$current"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    printf '%s\n' "none"
    return 0
  fi

  echo >&2
  echo "Both tools installed. Active banner:" >&2
  echo "  1) none" >&2
  echo "  2) fastfetch" >&2
  echo "  3) pfetch" >&2
  echo >&2
  read -r -p "Choose [1-3] (default 1): " choice
  case "${choice:-1}" in
    1 | none | "") printf '%s\n' "none" ;;
    2 | fastfetch) printf '%s\n' "fastfetch" ;;
    3 | pfetch) printf '%s\n' "pfetch" ;;
    *)
      echo "Invalid choice: $choice" >&2
      exit 1
      ;;
  esac
}

apply_fetch_mode() {
  local mode="$1"
  local current
  current="$(tmux_fetch_current_mode)"

  case "$mode" in
    keep | status)
      log "fetch banner unchanged: $current"
      if [[ "$mode" == "status" ]]; then
        printf 'mode: %s\n' "$current"
        printf 'art:  %s\n' "$(fastfetch_art_current)"
      fi
      ;;
    none | off | disable)
      enable_mode none
      ;;
    fastfetch)
      install_fastfetch_bin
      maybe_set_art "$ART"
      enable_mode fastfetch
      ;;
    pfetch)
      install_pfetch_bin
      enable_mode pfetch
      ;;
    both)
      install_fastfetch_bin
      install_pfetch_bin
      local active
      active="$(prompt_active_after_both)"
      if [[ "$active" == "fastfetch" ]]; then
        maybe_set_art "$ART"
      fi
      enable_mode "$active"
      ;;
    *)
      echo "Unknown mode: $mode" >&2
      usage >&2
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
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
    none | off | disable | fastfetch | pfetch | both | status)
      MODE="$1"
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$MODE" ]]; then
  if [[ -t 0 ]]; then
    MODE="$(prompt_mode)"
  else
    MODE="keep"
  fi
fi

if [[ "$MODE" != "status" ]]; then
  link_fetch_configs
fi
apply_fetch_mode "$MODE"
