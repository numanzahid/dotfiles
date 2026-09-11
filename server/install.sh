#!/usr/bin/env bash
# Copy configs into $HOME as real files (not symlinks).
# After this, you can delete the dotfiles clone.
#
# Not called by ../devbox.sh.
set -euo pipefail

COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$COPY_DIR"
DOTFILES_DIR="$(cd "$SERVER_DIR/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
INSTALL_SCRIPTS_DIR="$TARGET_HOME/.install-scripts"

# shellcheck source=../scripts/lib/hide-clone.sh
source "$SCRIPTS_DIR/lib/hide-clone.sh"
df_reexec_from_hidden_clone "$DOTFILES_DIR" "${BASH_SOURCE[0]}" "$@"

RUN_CONFIGS=1
RUN_SOFTWARE=1
DRY_RUN=0
INSTALL_FETCH=0

usage() {
  cat <<'EOF'
Usage: ./server.sh [options]

Copy shell/tmux/nvim configs into $HOME as real files, then you can
remove the dotfiles folder.

Full install (default): copy configs, apt packages, and Neovim.

Does not install: fzf, zoxide, lazygit, gh, btop, tldr,
TPM/tmux plugins, or nerd fonts.

Installs: apt deps, neovim, gdu (disk usage). Copies .gitconfig.

Options:
  --configs-only   Copy configs only (no apt packages or Neovim)
  --software-only  Apt packages and Neovim only (no config copy)
  --dry-run        Print actions without changing anything
  -h, --help       Show this help

Environment (used by dotfiles update):
  DOTFILES_RESPECT_COMPONENT_AGE=1   Skip software updated within 30 days

Optional extras:
  dotfiles install fetch
  dotfiles install lazyvim | lazyvim-lite

Copies ~/.install-scripts/{neovim,gdu}-install-update.sh for upgrades
after you delete the clone.
EOF
}

log() {
  printf '[server] %s\n' "$*"
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
# shellcheck source=../scripts/lib/component-state.sh
source "$SCRIPTS_DIR/lib/component-state.sh"
# shellcheck source=../scripts/fastfetch-banner.sh
source "$SCRIPTS_DIR/fastfetch-banner.sh"

# True when dest is a real file/dir that lives in the clone (unsafe to
# overwrite). A symlink at dest is a leftover home link; replace it.
dest_is_clone_file() {
  local dest="$1"
  local dest_real clone_real
  [[ -e "$dest" || -L "$dest" ]] || return 1
  [[ -L "$dest" ]] && return 1
  clone_real="$(readlink -f "$DOTFILES_DIR" 2>/dev/null || true)"
  dest_real="$(readlink -f "$dest" 2>/dev/null || true)"
  [[ -n "$clone_real" && -n "$dest_real" ]] || return 1
  [[ "$dest_real" == "$clone_real" || "$dest_real" == "$clone_real"/* ]]
}

# If dest is a leftover symlink (often into the clone), replace it with a
# real directory so copies do not write through into the repo.
ensure_real_dir() {
  local dest="$1"
  if [[ -L "$dest" ]]; then
    log "replace symlink with directory: $dest"
    run rm -f "$dest"
  fi
  run mkdir -p "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"
  local parent

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  parent="$(dirname "$dest")"
  if [[ -L "$parent" ]]; then
    ensure_real_dir "$parent"
  else
    mkdir -p "$parent"
  fi

  if [[ -L "$dest" ]]; then
    log "replace symlink with file: $dest"
    run rm -f "$dest"
  elif dest_is_clone_file "$dest"; then
    log "ERROR: dest is a real file inside the clone: $dest"
    return 1
  else
    df_stash_original_if_needed "$src" "$dest"
  fi

  run cp -f "$src" "$dest"
  log "copied: $dest"
  df_migrate_original_backup "$dest"
  df_track_path "$dest"
  df_journal_once copy "$dest" "$src"
}

copy_if_missing() {
  local src="$1"
  local dest="$2"
  local parent

  if [[ -e "$dest" ]]; then
    log "exists, not overwriting: $dest"
    df_journal_once skip "$dest"
    return 0
  fi

  parent="$(dirname "$dest")"
  if [[ -L "$parent" ]]; then
    ensure_real_dir "$parent"
  else
    mkdir -p "$parent"
  fi
  log "copy template: $dest"
  run cp "$src" "$dest"
  df_journal_once copy "$dest" "$src"
}
copy_overwrite() {
  local src="$1"
  local dest="$2"
  local parent

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  parent="$(dirname "$dest")"
  if [[ -L "$parent" ]]; then
    ensure_real_dir "$parent"
  else
    mkdir -p "$parent"
  fi

  if [[ -L "$dest" ]]; then
    log "replace symlink with file: $dest"
    run rm -f "$dest"
  elif dest_is_clone_file "$dest"; then
    log "ERROR: dest is a real file inside the clone: $dest"
    return 1
  fi

  run cp -f "$src" "$dest"
  log "copied: $dest"
  df_track_path "$dest"
  df_journal_once copy "$dest" "$src"
}

copy_install_scripts() {
  local dest_nvim="$INSTALL_SCRIPTS_DIR/neovim-install-update.sh"
  local dest_gdu="$INSTALL_SCRIPTS_DIR/gdu-install-update.sh"
  local dest_fetch="$INSTALL_SCRIPTS_DIR/fastfetch-install-update.sh"
  local cli_dir="$INSTALL_SCRIPTS_DIR/dotfiles-cli"
  local lib_file
  local old_share="$TARGET_HOME/.local/share/dotfiles"
  local old_hidden="$TARGET_HOME/.local/bin/neovim-install-update"
  local old_bin="$TARGET_HOME/bin/neovim-install-update"
  # Standalone ~/.install-scripts/neovim-install-update.sh sources these.
  local -a install_lib_files=(
    github-release.sh
    journal.sh
    install-cli.sh
    software-uninstall.sh
    privilege.sh
    component-state.sh
  )

  mkdir -p "$INSTALL_SCRIPTS_DIR/lib" "$cli_dir/lib"
  copy_overwrite "$SCRIPTS_DIR/neovim-install-update.sh" "$dest_nvim"
  copy_overwrite "$SCRIPTS_DIR/gdu-install-update.sh" "$dest_gdu"
  for lib_file in "${install_lib_files[@]}"; do
    copy_overwrite "$SCRIPTS_DIR/lib/$lib_file" "$INSTALL_SCRIPTS_DIR/lib/$lib_file"
  done
  copy_overwrite "$SCRIPTS_DIR/dotfiles" "$cli_dir/dotfiles"
  copy_overwrite "$SCRIPTS_DIR/lib/component-state.sh" "$cli_dir/lib/component-state.sh"
  copy_overwrite "$SCRIPTS_DIR/lib/journal.sh" "$cli_dir/lib/journal.sh"
  copy_overwrite "$SCRIPTS_DIR/lib/platform.sh" "$cli_dir/lib/platform.sh"
  run chmod 755 "$dest_nvim" "$dest_gdu" "$cli_dir/dotfiles"
  if [[ "$INSTALL_FETCH" -eq 1 ]]; then
    copy_overwrite "$SCRIPTS_DIR/fastfetch-install-update.sh" "$dest_fetch"
    copy_overwrite "$SCRIPTS_DIR/lib/pfetch-remove.sh" "$INSTALL_SCRIPTS_DIR/lib/pfetch-remove.sh"
    run chmod 755 "$dest_fetch"
  fi

  # Drop earlier copy locations ($HOME, ~/.local, ~/bin).
  run rm -f \
    "$TARGET_HOME/neovim-install-update.sh" \
    "$TARGET_HOME/neovim-install-update.lib.sh" \
    "$TARGET_HOME/fastfetch-install-update.sh" \
    "$TARGET_HOME/fastfetch-install-update.lib.sh" \
    "$old_hidden" \
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
  df_journal_once copy "$dest/init.lua" "$src/init.lua"
}

copy_kitty_terminfo() {
  local src="$SCRIPTS_DIR/data/terminfo/x/xterm-kitty"
  local dest="$TARGET_HOME/.terminfo/x/xterm-kitty"

  if [[ ! -f "$src" ]]; then
    log "skip missing kitty terminfo: $src"
    return 0
  fi

  copy_file "$src" "$dest"
}

copy_fastfetch_banner() {
  local art src_config
  src_config="$SOURCE_DIR/.config/fastfetch/config.jsonc"
  if [[ ! -f "$src_config" ]]; then
    log "ERROR: missing $src_config"
    log "Restore it: git -C $DOTFILES_DIR checkout -- home/.config/fastfetch/config.jsonc"
    exit 1
  fi

  ensure_real_dir "$TARGET_HOME/.config/tmux"
  ensure_real_dir "$TARGET_HOME/.config/fastfetch"
  df_ff_clean_extra_jsonc "$TARGET_HOME/.config/fastfetch"

  copy_file "$src_config" "$TARGET_HOME/.config/fastfetch/config.jsonc"
  copy_file "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  for art in "$SOURCE_DIR/.config/fastfetch"/art*.txt; do
    [[ -f "$art" ]] || continue
    copy_file "$art" "$TARGET_HOME/.config/fastfetch/$(basename "$art")"
  done
  copy_file \
    "$SOURCE_DIR/.config/fastfetch/custom-fetch-art.example.txt" \
    "$TARGET_HOME/.config/fastfetch/custom-fetch-art.example.txt"
  copy_file \
    "$SOURCE_DIR/.config/fastfetch/custom-fetch-padding.example.jsonc" \
    "$TARGET_HOME/.config/fastfetch/custom-fetch-padding.example.jsonc"
  copy_overwrite "$SCRIPTS_DIR/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
  run chmod 755 "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"
  run bash "$SCRIPTS_DIR/fastfetch-banner.sh" --ensure-local

  DF_FF_ART_DIR="$SOURCE_DIR/.config/fastfetch"
  export DF_FF_ART_DIR
  if [[ -n "$ART" ]] && ! df_ff_art_valid "$ART"; then
    echo "ERROR: --art $ART is not available (use $(df_ff_art_choices_csv))" >&2
    exit 1
  fi
  df_ff_maybe_set_art "$ART"

  local art_file="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/fastfetch-art"
  if [[ ! -e "$art_file" ]]; then
    mkdir -p "$(dirname "$art_file")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would set fastfetch text art: 1 -> $art_file"
    else
      printf '1\n' >"$art_file"
      log "fastfetch text art: 1 -> $art_file"
    fi
  fi
}

install_configs() {
  log "source: $SOURCE_DIR"
  log "target: $TARGET_HOME"

  # Previous copy-install left real files and the updater. Those dests are
  # ours even if the user edited them; do not treat edits as the original.
  if [[ -f "$INSTALL_SCRIPTS_DIR/neovim-install-update.sh" || -f "$TARGET_HOME/neovim-install-update.sh" ]]; then
    local dest
    for dest in \
      "$TARGET_HOME/.bashrc" \
      "$TARGET_HOME/.gitconfig" \
      "$TARGET_HOME/.config/dotfiles/prompt.sh" \
      "$TARGET_HOME/.shell_aliases_interactive.sh" \
      "$TARGET_HOME/.inputrc" \
      "$TARGET_HOME/.profile" \
      "$TARGET_HOME/.tmux.conf" \
      "$TARGET_HOME/.terminfo/x/xterm-kitty" \
      "$TARGET_HOME/.config/nvim" \
      "$TARGET_HOME/.config/fastfetch/config.jsonc"; do
      if [[ -e "$dest" && ! -L "$dest" ]]; then
        df_track_path "$dest"
      fi
    done
  fi

  copy_file "$SOURCE_DIR/.bashrc" "$TARGET_HOME/.bashrc"
  mkdir -p "$TARGET_HOME/.config/dotfiles"
  copy_file "$SOURCE_DIR/.config/dotfiles/prompt-optimized.sh" "$TARGET_HOME/.config/dotfiles/prompt.sh"
  copy_file "$SOURCE_DIR/.config/dotfiles/locale.sh" "$TARGET_HOME/.config/dotfiles/locale.sh"
  copy_file "$SERVER_DIR/shell_aliases_interactive.sh" "$TARGET_HOME/.shell_aliases_interactive.sh"
  copy_file "$SOURCE_DIR/.inputrc" "$TARGET_HOME/.inputrc"
  copy_file "$SOURCE_DIR/.gitconfig" "$TARGET_HOME/.gitconfig"
  copy_file "$SOURCE_DIR/.profile" "$TARGET_HOME/.profile"
  copy_file "$SERVER_DIR/tmux.conf" "$TARGET_HOME/.tmux.conf"
  copy_kitty_terminfo

  copy_nvim_plain
  copy_install_scripts

  mkdir -p "$TARGET_HOME/.ssh"
  run chmod 700 "$TARGET_HOME/.ssh"
  copy_if_missing "$SOURCE_DIR/.ssh/config.example" "$TARGET_HOME/.ssh/config"
  copy_if_missing "$SOURCE_DIR/.ssh/authorized_keys.example" "$TARGET_HOME/.ssh/authorized_keys"
  run chmod 600 "$TARGET_HOME/.ssh/config" 2>/dev/null || true
  run chmod 600 "$TARGET_HOME/.ssh/authorized_keys" 2>/dev/null || true

  install_dotfiles_cli
  df_profile_save server
}

install_dotfiles_cli() {
  local src="$SCRIPTS_DIR/dotfiles"
  local dest="$TARGET_HOME/.local/bin/dotfiles"
  local standalone="$INSTALL_SCRIPTS_DIR/dotfiles-cli/dotfiles"

  mkdir -p "$TARGET_HOME/.local/bin"
  if [[ -d "$DOTFILES_DIR" && -f "$src" ]]; then
    run chmod +x "$src"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      log "dotfiles CLI left untouched: $dest"
    else
      log "dotfiles CLI: $dest -> $src"
      run ln -sfn "$src" "$dest"
      df_track_path "$dest"
      df_journal_once link "$dest" "$src"
    fi
  elif [[ -x "$standalone" ]]; then
    copy_overwrite "$standalone" "$dest"
    run chmod 755 "$dest"
    df_track_path "$dest"
    df_journal_once copy "$dest" "$standalone"
  fi
}

df_skip_software_component() {
  local component="$1"
  if [[ "${DOTFILES_RESPECT_COMPONENT_AGE:-0}" -eq 1 ]] &&
    df_component_is_fresh "$component" "$DOTFILES_UPDATE_SKIP_DAYS"; then
    log "skip $component ($(df_component_age_label "$component"))"
    return 0
  fi
  return 1
}

install_software_server() {
  if ! df_skip_software_component deps; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run bash "$SERVER_DIR/install-deps.sh"
    else
      bash "$SERVER_DIR/install-deps.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch deps ""
  fi

  if ! df_skip_software_component neovim; then
    log "installing neovim via ~/.install-scripts/neovim-install-update.sh"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run bash "$INSTALL_SCRIPTS_DIR/neovim-install-update.sh"
    else
      bash "$INSTALL_SCRIPTS_DIR/neovim-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch neovim "$(df_component_detect_version neovim)"
  fi

  if ! df_skip_software_component gdu; then
    log "installing gdu via ~/.install-scripts/gdu-install-update.sh"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run bash "$INSTALL_SCRIPTS_DIR/gdu-install-update.sh"
    else
      bash "$INSTALL_SCRIPTS_DIR/gdu-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch gdu "$(df_component_detect_version gdu)"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configs-only)
      RUN_CONFIGS=1
      RUN_SOFTWARE=0
      ;;
    --software-only)
      RUN_CONFIGS=0
      RUN_SOFTWARE=1
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

if [[ "$RUN_CONFIGS" -eq 1 ]]; then
  install_configs
  if [[ "$DRY_RUN" -eq 0 ]]; then
    df_component_touch configs "$(df_component_detect_version configs)"
  fi
fi

if [[ "$RUN_SOFTWARE" -eq 1 ]]; then
  install_software_server
fi

if [[ "$RUN_CONFIGS" -eq 1 && "$RUN_SOFTWARE" -eq 1 ]]; then
  cat <<'EOF'

server install finished. Configs are real files in $HOME.
You can delete the dotfiles clone: rm -rf ~/.dotfiles

Optional: dotfiles install fetch
Day to day: dotfiles update

Later neovim upgrades: ~/.install-scripts/neovim-install-update.sh
EOF
fi
