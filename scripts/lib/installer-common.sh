#!/usr/bin/env bash
# Shared helpers for desktop.sh and devbox.sh (link/copy/dotfiles-cli
# plumbing that is genuinely identical between the two profiles). The
# per-profile "recipe" functions (install_dotfiles, install_software_*,
# link_prompt_default, run_github_step, log) stay in each script: they
# differ in real, deliberate ways (default prompt, package manager, a
# dry-run execution nuance in run_github_step) and unifying them would
# either lose that nuance or need a parameter for every difference.
#
# Requires the caller to already have set: DOTFILES_DIR, SOURCE_DIR,
# SCRIPTS_DIR, TARGET_HOME, DRY_RUN, and to define log() and
# GITHUB_STEP_FAILED before these functions are actually called (not
# before this file is sourced -- bash resolves function bodies at call
# time, so definition order here doesn't matter, call order does).

ICMN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=link.sh
source "$ICMN_LIB_DIR/link.sh"
# shellcheck source=privilege.sh
source "$ICMN_LIB_DIR/privilege.sh"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

git_github() {
  git -c http.version=HTTP/1.1 "$@"
}

needs_privileged_install() {
  [[ "$RUN_SOFTWARE" -eq 1 ]]
}

ensure_sudo_for_install() {
  if df_need_cmd sudo; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if df_is_root; then
      log "sudo missing; would prompt to install"
    else
      log "sudo missing; install would fail for non-root user"
    fi
    return 0
  fi

  df_ensure_sudo
}

link_path() {
  df_link_path "$@"
}

link_plain_nvim() {
  local src="$SOURCE_DIR/.config/nvim-plain"
  local dest="$TARGET_HOME/.config/nvim"
  local lazyvim_src="$SOURCE_DIR/.config/nvim"

  if [[ -e "$dest" || -L "$dest" ]] && df_paths_same "$dest" "$lazyvim_src"; then
    log "nvim: LazyVim config left untouched (managed by lazyvim scripts)"
    return 0
  fi

  link_path "$src" "$dest"
  log "nvim: plain editor config"
}

copy_if_missing() {
  local src="$1"
  local dest="$2"

  if [[ -e "$dest" ]]; then
    log "exists, not overwriting: $dest"
    df_journal_once skip "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  log "copy template: $dest"
  run cp "$src" "$dest"
  df_journal_once copy "$dest" "$src"
}

link_btop_conf() {
  local dest_dir="$TARGET_HOME/.config/btop"
  local src="$SOURCE_DIR/.config/btop/btop.conf"
  local dest="$dest_dir/btop.conf"

  # Older installs linked the whole ~/.config/btop directory.
  if [[ -L "$dest_dir" ]]; then
    log "replace btop config dir symlink with a directory"
    run rm -f "$dest_dir"
  fi

  mkdir -p "$dest_dir"
  link_path "$src" "$dest"
}

install_dotfiles_cli() {
  local src="$DOTFILES_DIR/scripts/dotfiles"
  local dest="$TARGET_HOME/.local/bin/dotfiles"

  mkdir -p "$TARGET_HOME/.local/bin"
  run chmod +x "$src"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    log "dotfiles CLI left untouched: $dest"
    return 0
  fi
  log "dotfiles CLI: $dest"
  run ln -sfn "$src" "$dest"
  df_track_path "$dest"
  df_journal_once link "$dest" "$src"
}
