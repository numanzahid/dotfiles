#!/usr/bin/env bash
# Shared helpers for desktop.sh and devbox.sh: link/copy/dotfiles-cli
# plumbing, and a single distro-branching install_software_workstation()
# so both profiles work on Fedora and Debian/Ubuntu. The remaining
# per-profile "recipe" bits (install_dotfiles's link order,
# link_prompt_default's default choice, run_github_step's dry-run nuance,
# log's prefix, and desktop.sh's extra starship step) stay in each script:
# each is a real, deliberate difference, not distro duplication.
#
# Requires the caller to already have set: DOTFILES_DIR, SOURCE_DIR,
# SCRIPTS_DIR, TARGET_HOME, DRY_RUN, RUN_SOFTWARE, and to define log() and
# GITHUB_STEP_FAILED before these functions are actually called (not
# before this file is sourced -- bash resolves function bodies at call
# time, so definition order here doesn't matter, call order does).

ICMN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=link.sh
source "$ICMN_LIB_DIR/link.sh"
# shellcheck source=privilege.sh
source "$ICMN_LIB_DIR/privilege.sh"
# shellcheck source=platform.sh
source "$ICMN_LIB_DIR/platform.sh"
# shellcheck source=component-state.sh
source "$ICMN_LIB_DIR/component-state.sh"

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

remove_old_fedora_dropin() {
  local dest="$TARGET_HOME/.bashrc.d/dotfiles.sh"
  if [[ -L "$dest" ]]; then
    log "remove old ~/.bashrc.d/dotfiles.sh (now in linked ~/.bashrc)"
    run rm -f "$dest"
  fi
}

dnf_install() {
  local pkg missing=()
  for pkg in "$@"; do
    if ! df_pkg_is_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  log "dnf install $*"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+ dnf install -y'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  df_run_privileged dnf install -y "$@"
  if ((${#missing[@]} > 0)); then
    df_journal_new_packages "${missing[@]}"
  fi
}

# GitHub-release binary left behind after switching that tool to the Fedora
# dnf package (or vice versa isn't needed: the GitHub scripts install to
# ~/.local/bin, dnf installs to /usr/bin, so only the /usr/local/bin path
# some older GitHub-script versions used needs cleaning up here).
remove_local_bin() {
  local name="$1"
  local dest="/usr/local/bin/${name}"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 0
  fi
  log "remove GitHub leftover ${dest} (using Fedora package)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+ rm -f %q\n' "$dest"
    return 0
  fi
  df_run_privileged rm -f "$dest"
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

# The one shared software-install recipe for both profiles. On Fedora,
# bat/fd/eza/gh/fzf/neovim/btop come from dnf (Fedora ships current
# versions and this keeps them under normal system updates); everywhere
# else they come from the same checksummed GitHub-release scripts. zoxide
# is always GitHub (Fedora's dnf zoxide lags upstream). lazygit, tldr,
# tpm, gdu, and fonts are always GitHub on both -- no distro packages
# ever covered those well, so there's nothing to branch.
install_software_workstation() {
  local os_family
  os_family="$(df_os_family)"

  if ! df_skip_software_component deps; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "install-fedora-deps.sh" bash "$DOTFILES_DIR/install-fedora-deps.sh"
    else
      run_github_step "install-deps.sh" bash "$DOTFILES_DIR/install-deps.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch deps ""
  fi

  if ! df_skip_software_component tools; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "tools" install_tools_fedora
    else
      run_github_step "install-tools.sh" bash "$DOTFILES_DIR/install-tools.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch tools ""
  fi

  if ! df_skip_software_component lazygit; then
    log "installing lazygit via scripts/lazygit-install-update.sh"
    run_github_step "lazygit" bash "$SCRIPTS_DIR/lazygit-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch lazygit "$(df_component_detect_version lazygit)"
  fi

  if ! df_skip_software_component gh; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "gh" dnf_install gh
      remove_local_bin gh
    else
      log "installing gh via scripts/gh-install-update.sh"
      run_github_step "gh" bash "$SCRIPTS_DIR/gh-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch gh "$(df_component_detect_version gh)"
  fi

  if ! df_skip_software_component fzf; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "fzf" dnf_install fzf
      remove_local_bin fzf
    else
      run_github_step "fzf" bash "$SCRIPTS_DIR/fzf-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch fzf "$(df_component_detect_version fzf)"
  fi

  if ! df_skip_software_component tldr; then
    log "installing tldr via scripts/tealdeer-install-update.sh"
    run_github_step "tldr" bash "$SCRIPTS_DIR/tealdeer-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch tldr "$(df_component_detect_version tldr)"
  fi

  if ! df_skip_software_component tpm; then
    run_github_step "tpm" bash "$SCRIPTS_DIR/tpm-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch tpm ""
  fi

  if ! df_skip_software_component neovim; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "neovim" dnf_install neovim
      remove_local_bin nvim
    else
      log "installing neovim via scripts/neovim-install-update.sh"
      run_github_step "neovim" bash "$SCRIPTS_DIR/neovim-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch neovim "$(df_component_detect_version neovim)"
  fi

  if ! df_skip_software_component btop; then
    if [[ "$os_family" == fedora ]]; then
      run_github_step "btop" dnf_install btop
      remove_local_bin btop
    else
      log "installing btop via scripts/btop-install-update.sh"
      run_github_step "btop" bash "$SCRIPTS_DIR/btop-install-update.sh"
    fi
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch btop "$(df_component_detect_version btop)"
  fi

  if ! df_skip_software_component gdu; then
    log "installing gdu via scripts/gdu-install-update.sh"
    run_github_step "gdu" bash "$SCRIPTS_DIR/gdu-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch gdu "$(df_component_detect_version gdu)"
  fi

  if ! df_skip_software_component fonts; then
    log "Nerd fonts: Cascadia Code + JetBrains Mono (user fonts + fc-cache)"
    run_github_step "cascadia-nerd-font" bash "$SCRIPTS_DIR/cascadia-nerd-font-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch fonts ""
  fi

  # Deliberate: without this, the function's own return status is whatever
  # the last "[[ "$DRY_RUN" -eq 0 ]] && df_component_touch ..." evaluated to
  # -- false (1) under --dry-run, since the guard short-circuits. Callers
  # invoke this as a bare statement, so under set -e that nonzero "return"
  # silently aborts the whole script with no error message. Caught by
  # running a full (non---configs-only) --dry-run and actually checking the
  # exit code, which nothing had done before.
  return 0
}

# Fedora's dnf bat/fd/eza plus GitHub zoxide (dnf's zoxide lags upstream).
# Debian/Ubuntu's equivalent is install-tools.sh (all four via GitHub).
install_tools_fedora() {
  local rc=0
  dnf_install bat fd-find eza || rc=1
  remove_local_bin bat
  remove_local_bin fd
  remove_local_bin eza
  log "zoxide from GitHub (Fedora package lags upstream)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would install zoxide from GitHub"
  else
    bash "$SCRIPTS_DIR/zoxide-install-update.sh" || rc=1
  fi
  return "$rc"
}
