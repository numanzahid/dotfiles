#!/usr/bin/env bash
# Dispatch dotfiles uninstall <software> to each install script's --uninstall.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

# shellcheck source=lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"

df_sw_log() {
  printf '[uninstall] %s\n' "$*"
}

df_sw_die() {
  printf '[uninstall] ERROR: %s\n' "$*" >&2
  exit 1
}

df_sw_usage() {
  cat <<EOF
Usage: $(basename "$0") <software> [options]
       dotfiles uninstall <software> [options]

Each install script owns its uninstall logic (--uninstall).

Software:
$(df_sw_list | sed 's/^/  /')

Special:
  lazyvim     dotfiles uninstall lazyvim

Options:
  --yes, -y   Skip confirmation
  --dry-run   Show actions only
  --list      List uninstallable software
  -h, --help  Show this help
EOF
}

df_sw_list() {
  printf '%s\n' \
    lazygit gh fzf tldr tpm neovim btop gdu starship fonts fetch \
    tools deps bat fd zoxide eza
}

df_sw_script_for() {
  local name="$1"
  case "$name" in
    lazygit) printf '%s/lazygit-install-update.sh\n' "$SCRIPTS_DIR" ;;
    gh) printf '%s/gh-install-update.sh\n' "$SCRIPTS_DIR" ;;
    fzf) printf '%s/fzf-install-update.sh\n' "$SCRIPTS_DIR" ;;
    tldr) printf '%s/tealdeer-install-update.sh\n' "$SCRIPTS_DIR" ;;
    tpm) printf '%s/tpm-install-update.sh\n' "$SCRIPTS_DIR" ;;
    neovim) printf '%s/neovim-install-update.sh\n' "$SCRIPTS_DIR" ;;
    btop) printf '%s/btop-install-update.sh\n' "$SCRIPTS_DIR" ;;
    gdu) printf '%s/gdu-install-update.sh\n' "$SCRIPTS_DIR" ;;
    starship) printf '%s/starship-install-update.sh\n' "$SCRIPTS_DIR" ;;
    fonts) printf '%s/cascadia-nerd-font-install-update.sh\n' "$SCRIPTS_DIR" ;;
    fetch) printf '%s/install-fetch.sh\n' "$DOTFILES_DIR" ;;
    tools) printf '%s/install-tools.sh\n' "$DOTFILES_DIR" ;;
    deps)
      if [[ "$(df_host_os_id)" == fedora ]]; then
        printf '%s/install-fedora-deps.sh\n' "$DOTFILES_DIR"
      else
        printf '%s/install-deps.sh\n' "$DOTFILES_DIR"
      fi
      ;;
    bat) printf '%s/bat-install-update.sh\n' "$SCRIPTS_DIR" ;;
    fd) printf '%s/fd-install-update.sh\n' "$SCRIPTS_DIR" ;;
    zoxide) printf '%s/zoxide-install-update.sh\n' "$SCRIPTS_DIR" ;;
    eza) printf '%s/eza-install-update.sh\n' "$SCRIPTS_DIR" ;;
    *) return 1 ;;
  esac
}

df_sw_main() {
  local name="" script assume_yes=0 dry=0
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes | -y) assume_yes=1 ;;
      --dry-run) dry=1 ;;
      --list)
        df_sw_list
        exit 0
        ;;
      -h | --help)
        df_sw_usage
        exit 0
        ;;
      -*)
        df_sw_die "unknown option: $1"
        ;;
      *)
        [[ -z "$name" ]] || df_sw_die "unexpected extra argument: $1"
        name="$1"
        ;;
    esac
    shift
  done

  [[ -n "$name" ]] || {
    df_sw_usage
    exit 1
  }

  [[ "$assume_yes" -eq 1 ]] && args+=(--yes)
  [[ "$dry" -eq 1 ]] && args+=(--dry-run)

  script="$(df_sw_script_for "$name" || true)"
  [[ -n "$script" && -f "$script" ]] || df_sw_die "unknown software: $name (try: dotfiles uninstall --list)"

  df_sw_log "running: $script --uninstall"
  bash "$script" --uninstall "${args[@]}"
}

df_sw_main "$@"
