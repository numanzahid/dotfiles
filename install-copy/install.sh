#!/usr/bin/env bash
# Copy configs into $HOME as real files (not symlinks).
# After this, you can delete the dotfiles clone.
#
# Not called by ../install.sh.
set -euo pipefail

COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$COPY_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"

INSTALL_DEPS=0
INSTALL_NEOVIM=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install-copy/install.sh [options]

Copy shell/tmux/nvim configs into $HOME as real files, then you can
remove the dotfiles folder.

Does not install or copy: gitconfig, fzf, zoxide, lazygit, lazydocker,
fetch banners, TPM/tmux plugins.

Always copies the Neovim updater into $HOME (overwrite, no backups)
so you can upgrade nvim after deleting this clone:
  ~/neovim-install-update.sh

Options:
  --deps       Run install-copy/install-deps.sh (apt packages + locale)
  --neovim     Install latest Neovim (same GitHub build as ./install.sh)
  --all        Copy configs, --deps, and --neovim
  --dry-run    Print actions without changing anything
  -h, --help   Show this help
EOF
}

log() {
  printf '[install-copy] %s\n' "$*"
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

# shellcheck source=../scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"

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

copy_if_missing() {
  local src="$1"
  local dest="$2"

  if [[ -e "$dest" ]]; then
    log "exists, not overwriting: $dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  log "copy template: $dest"
  run cp "$src" "$dest"
}

# Overwrite a helper script. No .pre-dotfiles backups.
copy_overwrite() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  run cp -f "$src" "$dest"
  log "copied: $dest"
}

copy_neovim_updater() {
  local dest_script="$TARGET_HOME/neovim-install-update.sh"
  local dest_lib="$TARGET_HOME/neovim-install-update.lib.sh"
  local old_share="$TARGET_HOME/.local/share/dotfiles"
  local old_hidden="$TARGET_HOME/.local/bin/neovim-install-update"
  local old_bin="$TARGET_HOME/bin/neovim-install-update"

  copy_overwrite "$SCRIPTS_DIR/neovim-install-update.sh" "$dest_script"
  copy_overwrite "$SCRIPTS_DIR/lib/github-release.sh" "$dest_lib"
  run chmod 755 "$dest_script"

  # Drop earlier copy locations (~/.local and ~/bin).
  run rm -f "$old_hidden" \
    "$old_share/neovim-install-update.sh" \
    "$old_share/lib/github-release.sh" \
    "$old_bin" \
    "$TARGET_HOME/bin/lib/github-release.sh"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    rmdir "$old_share/lib" 2>/dev/null || true
    rmdir "$old_share" 2>/dev/null || true
    rmdir "$TARGET_HOME/bin/lib" 2>/dev/null || true
    rmdir "$TARGET_HOME/bin" 2>/dev/null || true
  fi
}

copy_nvim_plain() {
  local src="$SOURCE_DIR/.config/nvim-plain"
  local dest="$TARGET_HOME/.config/nvim"
  local lazyvim_src="$SOURCE_DIR/.config/nvim"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest" 2>/dev/null || true)" == "$(readlink -f "$lazyvim_src" 2>/dev/null || true)" ]]; then
      log "nvim: LazyVim config left untouched"
      return 0
    fi
  fi

  if [[ -L "$dest" ]]; then
    log "replace nvim symlink with directory: $dest"
    run rm -f "$dest"
  elif [[ -d "$dest" ]]; then
    df_stash_original_if_needed "$src" "$dest"
  fi

  run mkdir -p "$dest"
  run cp -f "$src/init.lua" "$dest/init.lua"
  log "copied: $dest/init.lua (plain nvim)"
  df_migrate_original_backup "$dest"
  df_track_path "$dest"
}

install_configs() {
  log "source: $SOURCE_DIR"
  log "target: $TARGET_HOME"

  # Previous copy-install left real files and the updater. Those dests are
  # ours even if the user edited them; do not treat edits as the original.
  if [[ -f "$TARGET_HOME/neovim-install-update.sh" ]]; then
    local dest
    for dest in \
      "$TARGET_HOME/.bashrc" \
      "$TARGET_HOME/.shell_aliases_interactive.sh" \
      "$TARGET_HOME/.inputrc" \
      "$TARGET_HOME/.profile" \
      "$TARGET_HOME/.tmux.conf" \
      "$TARGET_HOME/.config/nvim"; do
      if [[ -e "$dest" && ! -L "$dest" ]]; then
        df_track_path "$dest"
      fi
    done
  fi

  copy_file "$SOURCE_DIR/.bashrc" "$TARGET_HOME/.bashrc"
  copy_file "$COPY_DIR/shell_aliases_interactive.sh" "$TARGET_HOME/.shell_aliases_interactive.sh"
  copy_file "$SOURCE_DIR/.inputrc" "$TARGET_HOME/.inputrc"
  copy_file "$SOURCE_DIR/.profile" "$TARGET_HOME/.profile"
  copy_file "$COPY_DIR/tmux.conf" "$TARGET_HOME/.tmux.conf"

  copy_nvim_plain
  copy_neovim_updater

  mkdir -p "$TARGET_HOME/.ssh"
  run chmod 700 "$TARGET_HOME/.ssh"
  copy_if_missing "$SOURCE_DIR/.ssh/config.example" "$TARGET_HOME/.ssh/config"
  copy_if_missing "$SOURCE_DIR/.ssh/authorized_keys.example" "$TARGET_HOME/.ssh/authorized_keys"
  run chmod 600 "$TARGET_HOME/.ssh/config" 2>/dev/null || true
  run chmod 600 "$TARGET_HOME/.ssh/authorized_keys" 2>/dev/null || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deps) INSTALL_DEPS=1 ;;
    --neovim) INSTALL_NEOVIM=1 ;;
    --all)
      INSTALL_DEPS=1
      INSTALL_NEOVIM=1
      ;;
    --dry-run) DRY_RUN=1 ;;
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

install_configs

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$COPY_DIR/install-deps.sh"
  else
    bash "$COPY_DIR/install-deps.sh"
  fi
fi

if [[ "$INSTALL_NEOVIM" -eq 1 ]]; then
  log "installing neovim via ~/neovim-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$TARGET_HOME/neovim-install-update.sh"
  else
    bash "$TARGET_HOME/neovim-install-update.sh"
  fi
fi

cat <<'EOF'

install-copy finished. Configs are real files in $HOME.
You can delete the dotfiles clone:

  rm -rf ~/dotfiles

Not included: gitconfig, fzf, zoxide, lazygit, lazydocker, fetch, TPM.

Copied configs:
  ~/.bashrc
  ~/.shell_aliases_interactive.sh
  ~/.inputrc
  ~/.profile
  ~/.tmux.conf  (no TPM / no fetch)
  ~/.config/nvim/init.lua  (plain nvim, if LazyVim was not already there)
  ~/.ssh/config  (only if missing)
  ~/.ssh/authorized_keys  (only if missing)
  ~/neovim-install-update.sh

Apt deps (--deps / --all):
  bash bash-completion ca-certificates curl gzip htop less locales tar tmux wget

Neovim (--neovim / --all):
  same GitHub build as ./install.sh --neovim  (/usr/local/bin/nvim)
  later: neovim-install-update

If tmux is already running: tmux source-file ~/.tmux.conf
EOF
