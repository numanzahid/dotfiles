#!/usr/bin/env bash
set -euo pipefail

# Copy tmux config into $HOME as real files (not symlinks).
# After this, you can delete the dotfiles clone; tmux will keep working.
#
# Not called by ./install.sh. Tmux-only hosts:
#   ./scripts/install-tmux-config.sh
#   rm -rf ~/dotfiles
#
# Default fetch mode is none. Existing ~/.config/tmux/fetch.conf is kept
# if it is already a regular file.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
TARGET_HOME="${HOME:?}"
INSTALL_TPM=1

usage() {
  cat <<'EOF'
Usage: ./scripts/install-tmux-config.sh [options]

Copy tmux config from this repo into $HOME as real files, then you can
remove the dotfiles folder.

Options:
  --no-tpm   Do not clone tmux plugin manager
  -h, --help Show this help
EOF
}

log() {
  printf '[tmux-config] %s\n' "$*"
}

run() {
  "$@"
}

# shellcheck source=lib/link.sh
source "$DOTFILES_DIR/scripts/lib/link.sh"

copy_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    log "replace symlink with file: $dest"
    run rm -f "$dest"
  else
    df_stash_original_if_needed "$src" "$dest"
  fi
  run cp -f "$src" "$dest"
  log "copied: $dest"
  df_migrate_original_backup "$dest"
  df_track_path "$dest"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-tpm) INSTALL_TPM=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

copy_file "$SOURCE_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf"

mkdir -p "$TARGET_HOME/.config/tmux"
copy_file "$SOURCE_DIR/.config/tmux/fetch-none.conf" "$TARGET_HOME/.config/tmux/fetch-none.conf"
copy_file "$SOURCE_DIR/.config/tmux/fetch-fastfetch.conf" "$TARGET_HOME/.config/tmux/fetch-fastfetch.conf"
copy_file "$SOURCE_DIR/.config/tmux/fetch-pfetch.conf" "$TARGET_HOME/.config/tmux/fetch-pfetch.conf"
copy_file "$SOURCE_DIR/.config/tmux/fastfetch.jsonc" "$TARGET_HOME/.config/tmux/fastfetch.jsonc"
copy_file "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"

fetch_conf="$TARGET_HOME/.config/tmux/fetch.conf"
if [[ -L "$fetch_conf" ]]; then
  log "fetch.conf is a symlink; replacing with a real file"
  rm -f "$fetch_conf"
fi
if [[ ! -e "$fetch_conf" ]]; then
  copy_file "$SOURCE_DIR/.config/tmux/fetch-none.conf" "$fetch_conf"
else
  log "keeping existing fetch mode: $fetch_conf"
fi

if [[ "$INSTALL_TPM" -eq 1 ]]; then
  tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm_dir/.git" ]]; then
    log "tpm already installed: $tpm_dir"
  else
    if ! command -v git >/dev/null 2>&1; then
      echo "ERROR: git is required to install tpm (or pass --no-tpm)" >&2
      exit 1
    fi
    log "cloning tmux plugin manager..."
    mkdir -p "$TARGET_HOME/.tmux/plugins"
    git -c http.version=HTTP/1.1 clone -4 https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi
fi

if ! command -v tmux >/dev/null 2>&1; then
  log "WARN: tmux is not installed. Install it with: sudo apt-get install -y tmux"
fi

cat <<'EOF'

Tmux config is now real files in $HOME. You can delete the dotfiles clone.

  rm -rf ~/dotfiles

If tmux is already running: tmux source-file ~/.tmux.conf
Then prefix + Shift + I once to install TPM plugins.
EOF
