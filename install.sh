#!/usr/bin/env bash
# Link dotfiles from this repo into $HOME.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
df_prepend_local_bin

INSTALL_DEPS=0
INSTALL_TOOLS=0
INSTALL_LAZYGIT=0
INSTALL_GH=0
INSTALL_NEOVIM=0
INSTALL_BTOP=0
INSTALL_TPM=0
INSTALL_FZF=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --deps       Run install-deps.sh (base apt packages)
  --tools      Install bat, fd, zoxide, eza from upstream releases
  --lazygit    Run scripts/lazygit-install-update.sh (GitHub release)
  --gh         Run scripts/gh-install-update.sh (GitHub release)
  --neovim     Run scripts/neovim-install-update.sh (GitHub release, not apt)
  --btop       Run scripts/btop-install-update.sh (GitHub release, not apt)
  --tpm        Clone tmux-plugin-manager if missing
  --fzf        Clone and install junegunn/fzf if missing
  --all        Enable --deps --tools --lazygit --gh --neovim --btop --tpm --fzf
  --dry-run    Print actions without changing anything
  -h, --help   Show this help

LazyVim extras (optional, not part of --all):
  ./lazyvim/install-lazyvim.sh          # full IDE profile (Mason, LSP, Node)
  ./lazyvim-lite/install-lazyvim-lite.sh # editor-only profile (no Mason/LSP/Node)

Tmux fetch banner (optional, not part of --all):
  ./install-fetch.sh                    # install fastfetch + compact banner
  ./install-fetch.sh --art 1

AI coding CLIs (optional, not part of --all):
  ./install-ai-cli.sh                   # prompt: opencode / cursor / claude / codex
  ./install-ai-cli.sh all
  ./install-ai-cli.sh claude opencode

Default behavior links config files into $HOME.
Neovim editor rules: home/.config/nvim-plain (plain nvim, no plugins).
LazyVim nvim config is not linked here.
OpenCode config is linked only by ./install-ai-cli.sh.

Fedora: use ./install-fedora.sh instead (shared bashrc; starship prompt).
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
  [[ "$INSTALL_DEPS" -eq 1 ||
    "$INSTALL_TOOLS" -eq 1 ||
    "$INSTALL_LAZYGIT" -eq 1 ||
    "$INSTALL_GH" -eq 1 ||
    "$INSTALL_NEOVIM" -eq 1 ||
    "$INSTALL_BTOP" -eq 1 ]]
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
# shellcheck source=scripts/lib/ai-trash-rules.sh
source "$SCRIPTS_DIR/lib/ai-trash-rules.sh"

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
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  log "copy template: $dest"
  run cp "$src" "$dest"
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
  local src="$SOURCE_DIR/.config/dotfiles/prompt-custom.sh"

  mkdir -p "$TARGET_HOME/.config/dotfiles"

  if [[ -e "$dest" || -L "$dest" ]]; then
    log "prompt left untouched: $dest"
    return 0
  fi

  log "default prompt: custom -> $dest"
  run ln -sfn "$src" "$dest"
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

  link_plain_nvim
  link_path "$SOURCE_DIR/.config/fastfetch" "$TARGET_HOME/.config/fastfetch"

  link_path "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  link_path "$DOTFILES_DIR/scripts/fastfetch-banner.sh" "$TARGET_HOME/.config/tmux/fastfetch-banner.sh"

  link_btop_conf
  mkdir -p "$TARGET_HOME/.config/lazygit"
  link_path "$SOURCE_DIR/.config/lazygit/config.yml" "$TARGET_HOME/.config/lazygit/config.yml"
  link_path "$SOURCE_DIR/.config/starship.toml" "$TARGET_HOME/.config/starship.toml"

  mkdir -p "$TARGET_HOME/.ssh"
  chmod 700 "$TARGET_HOME/.ssh"
  copy_if_missing "$SOURCE_DIR/.ssh/config.example" "$TARGET_HOME/.ssh/config"
  copy_if_missing "$SOURCE_DIR/.ssh/authorized_keys.example" "$TARGET_HOME/.ssh/authorized_keys"
  run chmod 600 "$TARGET_HOME/.ssh/config" 2>/dev/null || true
  run chmod 600 "$TARGET_HOME/.ssh/authorized_keys" 2>/dev/null || true

  df_copy_ai_trash_rules
}

install_tpm() {
  local tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm_dir/.git" ]]; then
    log "tpm already installed: $tpm_dir"
    return 0
  fi

  log "installing tmux plugin manager..."
  run mkdir -p "$TARGET_HOME/.tmux/plugins"
  run git_github clone -4 https://github.com/tmux-plugins/tpm "$tpm_dir"
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
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deps) INSTALL_DEPS=1 ;;
    --tools) INSTALL_TOOLS=1 ;;
    --lazygit) INSTALL_LAZYGIT=1 ;;
    --gh) INSTALL_GH=1 ;;
    --neovim) INSTALL_NEOVIM=1 ;;
    --btop) INSTALL_BTOP=1 ;;
    --tpm) INSTALL_TPM=1 ;;
    --fzf) INSTALL_FZF=1 ;;
    --all)
      INSTALL_DEPS=1
      INSTALL_TOOLS=1
      INSTALL_LAZYGIT=1
      INSTALL_GH=1
      INSTALL_NEOVIM=1
      INSTALL_BTOP=1
      INSTALL_TPM=1
      INSTALL_FZF=1
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
  echo "On Fedora use ./install-fedora.sh (this installer is Debian/Ubuntu)." >&2
  exit 1
fi

if needs_privileged_install; then
  ensure_sudo_for_install
fi

install_dotfiles

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  run_github_step "install-deps.sh" bash "$DOTFILES_DIR/install-deps.sh"
fi

if [[ "$INSTALL_TOOLS" -eq 1 ]]; then
  run_github_step "install-tools.sh" bash "$DOTFILES_DIR/install-tools.sh"
fi

if [[ "$INSTALL_LAZYGIT" -eq 1 ]]; then
  log "installing lazygit via scripts/lazygit-install-update.sh"
  run_github_step "lazygit" bash "$SCRIPTS_DIR/lazygit-install-update.sh"
fi

if [[ "$INSTALL_GH" -eq 1 ]]; then
  log "installing gh via scripts/gh-install-update.sh"
  run_github_step "gh" bash "$SCRIPTS_DIR/gh-install-update.sh"
fi

if [[ "$INSTALL_FZF" -eq 1 ]]; then
  run_github_step "fzf" install_fzf
fi

if [[ "$INSTALL_TPM" -eq 1 ]]; then
  run_github_step "tpm" install_tpm
fi

if [[ "$INSTALL_NEOVIM" -eq 1 ]]; then
  log "installing neovim via scripts/neovim-install-update.sh"
  run_github_step "neovim" bash "$SCRIPTS_DIR/neovim-install-update.sh"
fi

if [[ "$INSTALL_BTOP" -eq 1 ]]; then
  log "installing btop via scripts/btop-install-update.sh"
  run_github_step "btop" bash "$SCRIPTS_DIR/btop-install-update.sh"
fi

if [[ "$GITHUB_STEP_FAILED" -eq 1 ]]; then
  log "one or more GitHub installs failed; re-run ./install.sh --all"
  exit 1
fi

cat <<'EOF'

Next steps:
  1. Copy SSH private keys into ~/.ssh/ manually (never commit keys).
  2. Open tmux and press prefix + Shift + I to install tmux plugins.
  3. Optional LazyVim (not part of --all; these scripts own nvim LazyVim config):
       ./lazyvim-lite/install-lazyvim-lite.sh
       ./lazyvim/install-lazyvim.sh
     Without them, nvim uses the plain editor config from this install.
  4. Optional fetch banner (not part of --all):
       ./install-fetch.sh
       ./install-fetch.sh --art 1
  5. Optional AI CLIs (not part of --all):
       ./install-ai-cli.sh                # prompt: opencode / cursor / claude / codex
       ./install-ai-cli.sh all
  6. Optional: nvm/Node via ./scripts/nvm-install-update.sh

EOF
