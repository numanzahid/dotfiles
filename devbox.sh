#!/usr/bin/env bash
# Link dotfiles from this repo into $HOME.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/hide-clone.sh
source "$SCRIPTS_DIR/lib/hide-clone.sh"
df_reexec_from_hidden_clone "$DOTFILES_DIR" "${BASH_SOURCE[0]}" "$@"
df_prepend_local_bin

RUN_CONFIGS=1
RUN_SOFTWARE=1
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./devbox.sh [options]

Full Debian/Ubuntu workstation install: link configs, packages, CLI tools,
fonts, tmux TPM, and AI agent rules.

Options:
  --configs-only   Link configs and AI rules only (no software)
  --software-only  Install or upgrade software only (no config links)
  --dry-run        Print actions without changing anything
  -h, --help       Show this help

Environment (used by dotfiles update):
  DOTFILES_RESPECT_COMPONENT_AGE=1   Skip software updated within 30 days

Single-tool installs: ./scripts/<tool>-install-update.sh

Optional extras:
  dotfiles install lazyvim | lazyvim-lite | fetch
  ./scripts/alacritty-install-update.sh
  ./scripts/kitty-install-update.sh

Fedora: use ./desktop.sh instead.
EOF
}

log() {
  printf '[dotfiles] %s\n' "$*"
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

GITHUB_STEP_FAILED=0

run_github_step() {
  local label="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run "$@"
    return 0
  fi
  if "$@"; then
    return 0
  fi
  log "WARN: $label failed (often GitHub); continuing"
  GITHUB_STEP_FAILED=1
  return 0
}

git_github() {
  git -c http.version=HTTP/1.1 "$@"
}

needs_privileged_install() {
  [[ "$RUN_SOFTWARE" -eq 1 ]]
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

install_software_devbox() {
  if ! df_skip_software_component deps; then
    run_github_step "install-deps.sh" bash "$DOTFILES_DIR/install-deps.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch deps ""
  fi

  if ! df_skip_software_component tools; then
    run_github_step "install-tools.sh" bash "$DOTFILES_DIR/install-tools.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch tools ""
  fi

  if ! df_skip_software_component lazygit; then
    log "installing lazygit via scripts/lazygit-install-update.sh"
    run_github_step "lazygit" bash "$SCRIPTS_DIR/lazygit-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch lazygit "$(df_component_detect_version lazygit)"
  fi

  if ! df_skip_software_component gh; then
    log "installing gh via scripts/gh-install-update.sh"
    run_github_step "gh" bash "$SCRIPTS_DIR/gh-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch gh "$(df_component_detect_version gh)"
  fi

  if ! df_skip_software_component fzf; then
    run_github_step "fzf" bash "$SCRIPTS_DIR/fzf-install-update.sh"
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
    log "installing neovim via scripts/neovim-install-update.sh"
    run_github_step "neovim" bash "$SCRIPTS_DIR/neovim-install-update.sh"
    [[ "$DRY_RUN" -eq 0 ]] && df_component_touch neovim "$(df_component_detect_version neovim)"
  fi

  if ! df_skip_software_component btop; then
    log "installing btop via scripts/btop-install-update.sh"
    run_github_step "btop" bash "$SCRIPTS_DIR/btop-install-update.sh"
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
}

ensure_sudo_for_install() {
  # shellcheck source=scripts/lib/privilege.sh
  source "$SCRIPTS_DIR/lib/privilege.sh"

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

# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"
# shellcheck source=scripts/lib/component-state.sh
source "$SCRIPTS_DIR/lib/component-state.sh"

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

link_prompt_default() {
  local dest="$TARGET_HOME/.config/dotfiles/prompt.sh"
  local src="$SOURCE_DIR/.config/dotfiles/prompt-optimized.sh"
  local target base newsrc

  mkdir -p "$TARGET_HOME/.config/dotfiles"

  # Symlink: retarget after clone hide (~/dotfiles -> ~/.dotfiles).
  # Real file: leave it (machine-local prompt).
  if [[ -L "$dest" ]]; then
    target="$(readlink "$dest")"
    base="$(basename "$target")"
    if [[ "$base" == prompt-optimized.sh || "$base" == prompt-custom.sh || "$base" == prompt-starship.sh ]]; then
      if [[ "$base" == prompt-starship.sh ]]; then
        newsrc="$SOURCE_DIR/.config/dotfiles/prompt-starship.sh"
      else
        newsrc="$src"
      fi
      [[ -e "$newsrc" ]] || newsrc="$src"
    else
      newsrc="$src"
    fi
    if [[ -e "$dest" ]] && df_paths_same "$dest" "$newsrc"; then
      log "prompt already linked: $dest"
      df_track_path "$dest"
      df_journal_once link "$dest" "$newsrc"
      return 0
    fi
    log "retarget prompt: $dest -> $newsrc"
    run ln -sfn "$newsrc" "$dest"
    df_track_path "$dest"
    df_journal_once link "$dest" "$newsrc"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    log "prompt left untouched: $dest"
    df_journal_once skip "$dest"
    return 0
  fi

  log "default prompt: optimized -> $dest"
  run ln -sfn "$src" "$dest"
  df_track_path "$dest"
  df_journal_once link "$dest" "$src"
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

install_dotfiles() {
  log "source: $SOURCE_DIR"
  log "target: $TARGET_HOME"

  link_path "$SOURCE_DIR/.bashrc" "$TARGET_HOME/.bashrc"
  link_path "$SOURCE_DIR/.shell_aliases_interactive.sh" "$TARGET_HOME/.shell_aliases_interactive.sh"
  link_path "$SOURCE_DIR/.inputrc" "$TARGET_HOME/.inputrc"
  link_path "$SOURCE_DIR/.profile" "$TARGET_HOME/.profile"
  link_path "$SOURCE_DIR/.gitconfig" "$TARGET_HOME/.gitconfig"
  link_path "$SOURCE_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf"
  link_prompt_default
  link_path "$SOURCE_DIR/.config/dotfiles/locale.sh" "$TARGET_HOME/.config/dotfiles/locale.sh"

  link_plain_nvim
  link_path "$SOURCE_DIR/.config/fastfetch" "$TARGET_HOME/.config/fastfetch"

  link_path "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  link_path "$DOTFILES_DIR/scripts/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"

  link_btop_conf
  mkdir -p "$TARGET_HOME/.config/lazygit"
  link_path "$SOURCE_DIR/.config/lazygit/config.yml" "$TARGET_HOME/.config/lazygit/config.yml"
  link_path "$SOURCE_DIR/.config/starship.toml" "$TARGET_HOME/.config/starship.toml"
  link_path "$SOURCE_DIR/.config/alacritty" "$TARGET_HOME/.config/alacritty"
  link_path "$SOURCE_DIR/.config/kitty" "$TARGET_HOME/.config/kitty"

  mkdir -p "$TARGET_HOME/.ssh"
  chmod 700 "$TARGET_HOME/.ssh"
  copy_if_missing "$SOURCE_DIR/.ssh/config.example" "$TARGET_HOME/.ssh/config"
  copy_if_missing "$SOURCE_DIR/.ssh/authorized_keys.example" "$TARGET_HOME/.ssh/authorized_keys"
  run chmod 600 "$TARGET_HOME/.ssh/config" 2>/dev/null || true
  run chmod 600 "$TARGET_HOME/.ssh/authorized_keys" 2>/dev/null || true

  log "AI agent rules (cursor, codex, claude)"
  df_ai_rules_install_all

  if [[ -x "$DOTFILES_DIR/scripts/kitty-terminfo-install-update.sh" ]]; then
    log "kitty terminfo (xterm-kitty for SSH/tmux from Kitty)"
    bash "$DOTFILES_DIR/scripts/kitty-terminfo-install-update.sh"
  fi

  df_relocate_stray_clone_backups
  install_dotfiles_cli
  df_profile_save devbox
}

install_tpm() {
  local tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm_dir/.git" ]]; then
    log "tpm already installed: $tpm_dir"
    df_journal_once git-clone "$tpm_dir"
    return 0
  fi

  log "installing tmux plugin manager..."
  run mkdir -p "$TARGET_HOME/.tmux/plugins"
  run git_github clone -4 https://github.com/tmux-plugins/tpm "$tpm_dir"
  df_journal_once git-clone "$tpm_dir"
}

install_fzf() {
  local fzf_dir="$TARGET_HOME/.fzf"

  if [[ -d "$fzf_dir/.git" ]]; then
    log "updating fzf in $fzf_dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run git_github -C "$fzf_dir" pull -4 --ff-only
    else
      git_github -C "$fzf_dir" pull -4 --ff-only
    fi
  else
    log "installing fzf..."
    run git_github clone -4 --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    # fzf writes ~/.fzf.bash. If that path is still a symlink into this
    # repo, the installer would dirty home/.fzf.bash (machine-specific PATH).
    if [[ -L "$TARGET_HOME/.fzf.bash" ]]; then
      log "replace fzf bash stub symlink with a real file"
      run rm -f "$TARGET_HOME/.fzf.bash"
    fi
    "$fzf_dir/install" --all --no-update-rc
    df_journal_once git-clone "$fzf_dir"
    if [[ -f "$TARGET_HOME/.fzf.bash" ]]; then
      df_journal_once copy "$TARGET_HOME/.fzf.bash"
    fi
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

if [[ "$(df_host_os_id)" == "fedora" ]]; then
  echo "On Fedora use ./desktop.sh (this installer is Debian/Ubuntu)." >&2
  exit 1
fi

if needs_privileged_install; then
  ensure_sudo_for_install
fi

if [[ "$RUN_CONFIGS" -eq 1 ]]; then
  install_dotfiles
  if [[ "$DRY_RUN" -eq 0 ]]; then
    df_component_touch configs "$(df_component_detect_version configs)"
  fi
fi

if [[ "$RUN_SOFTWARE" -eq 1 ]]; then
  install_software_devbox
fi

if [[ "$GITHUB_STEP_FAILED" -eq 1 ]]; then
  log "one or more GitHub installs failed; re-run ./devbox.sh"
  exit 1
fi

if [[ "$RUN_CONFIGS" -eq 1 && "$RUN_SOFTWARE" -eq 1 ]]; then
  cat <<'EOF'

Next steps:
  1. Copy SSH private keys into ~/.ssh/ manually (never commit keys).
  2. Open tmux and press prefix + Shift + I to install tmux plugins.
  3. Optional: dotfiles install lazyvim | lazyvim-lite | fetch
  4. Day to day: dotfiles update

EOF
fi
