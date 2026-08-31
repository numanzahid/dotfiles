#!/usr/bin/env bash
set -euo pipefail

# Copy tmux config into $HOME as real files (not symlinks).
# After this, you can delete the dotfiles clone; tmux will keep working.
#
# Not called by ./install.sh. Tmux-only hosts:
#   ./scripts/install-tmux-config.sh
#   rm -rf ~/.dotfiles

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

mkdir -p "$TARGET_HOME/.config/tmux" "$TARGET_HOME/.config/fastfetch"
copy_file "$SOURCE_DIR/.config/fastfetch/config.jsonc" "$TARGET_HOME/.config/fastfetch/config.jsonc"
copy_file "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
for art in "$SOURCE_DIR/.config/fastfetch"/art*.txt; do
  [[ -f "$art" ]] || continue
  copy_file "$art" "$TARGET_HOME/.config/fastfetch/$(basename "$art")"
done
copy_file "$DOTFILES_DIR/scripts/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
chmod 755 "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
bash "$DOTFILES_DIR/scripts/fastfetch-banner.sh" --ensure-local

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

  rm -rf ~/.dotfiles

If tmux is already running: tmux source-file ~/.tmux.conf
Then prefix + Shift + I once to install TPM plugins.
EOF
