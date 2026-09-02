#!/usr/bin/env bash
# Link shared configs on Fedora. Keep the clone.
# Official dnf repos or GitHub only.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPTS_DIR/lib/privilege.sh"
# shellcheck source=scripts/lib/hide-clone.sh
source "$SCRIPTS_DIR/lib/hide-clone.sh"
df_reexec_from_hidden_clone "$DOTFILES_DIR" "${BASH_SOURCE[0]}" "$@"
df_prepend_local_bin

INSTALL_DEPS=0
INSTALL_TOOLS=0
INSTALL_LAZYGIT=0
INSTALL_GH=0
INSTALL_NEOVIM=0
INSTALL_BTOP=0
INSTALL_TPM=0
INSTALL_FZF=0
INSTALL_STARSHIP=0
INSTALL_FONTS=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install-fedora.sh [options]

Links the shared ~/.bashrc (Fedora /etc/bashrc, PATH, and ~/.bashrc.d
are included there). Prompt is ~/.config/dotfiles/prompt.sh
(starship by default on Fedora).

Official dnf or GitHub only.
Edit the dnf vs GitHub lists in this script if a package falls behind.

dnf:     bat, fd-find, eza, btop, fzf, gh, neovim
GitHub:  zoxide, lazygit, starship, Nerd Fonts (Cascadia Code + JetBrains Mono)
         (fastfetch via ./install-fetch.sh)

Options:
  --deps       Run install-fedora-deps.sh (base dnf packages)
  --tools      bat, fd, eza from dnf; zoxide from GitHub
  --lazygit    GitHub release (not in Fedora repos)
  --gh         Fedora package
  --neovim     Fedora package
  --btop       Fedora package
  --tpm        Clone tmux-plugin-manager if missing
  --fzf        Fedora package
  --starship   GitHub release; default prompt is starship
  --all        Enable all of the above (also Cascadia Code + JetBrains Mono nerd fonts)
  --dry-run    Print actions without changing anything
  -h, --help   Show this help

LazyVim extras (optional, not part of --all):
  ./lazyvim/install-lazyvim.sh
  ./lazyvim-lite/install-lazyvim-lite.sh

Tmux fetch banner (optional, not part of --all):
  ./install-fetch.sh

AI coding CLIs (optional, not part of --all):
  ./install-ai-cli.sh
EOF
}

log() {
  printf '[fedora] %s\n' "$*"
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
  if [[ "$DRY_RUN" -eq 1 && "${1:-}" == "bash" ]]; then
    run "$@"
    return 0
  fi
  if "$@"; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
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
    "$INSTALL_BTOP" -eq 1 ||
    "$INSTALL_FZF" -eq 1 ||
    "$INSTALL_STARSHIP" -eq 1 ]]
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
    df_journal_once skip "$dest"
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

  if [[ -L "$dest_dir" ]]; then
    log "replace btop config dir symlink with a directory"
    run rm -f "$dest_dir"
  fi

  mkdir -p "$dest_dir"
  link_path "$src" "$dest"
}

link_prompt_default() {
  local dest="$TARGET_HOME/.config/dotfiles/prompt.sh"
  local src="$SOURCE_DIR/.config/dotfiles/prompt-starship.sh"
  local target base newsrc

  mkdir -p "$TARGET_HOME/.config/dotfiles"

  if [[ -L "$dest" ]]; then
    target="$(readlink "$dest")"
    base="$(basename "$target")"
    if [[ "$base" == prompt-custom.sh || "$base" == prompt-starship.sh ]]; then
      newsrc="$SOURCE_DIR/.config/dotfiles/$base"
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

  log "default prompt: starship -> $dest"
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

install_dotfiles() {
  log "source: $SOURCE_DIR"
  log "target: $TARGET_HOME"

  remove_old_fedora_dropin

  link_path "$SOURCE_DIR/.bashrc" "$TARGET_HOME/.bashrc"
  link_path "$SOURCE_DIR/.shell_aliases_interactive.sh" "$TARGET_HOME/.shell_aliases_interactive.sh"
  link_path "$SOURCE_DIR/.inputrc" "$TARGET_HOME/.inputrc"
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

  df_copy_ai_trash_rules

  if [[ -x "$DOTFILES_DIR/scripts/kitty-terminfo-install-update.sh" ]]; then
    log "kitty terminfo (xterm-kitty for SSH/tmux from Kitty)"
    bash "$DOTFILES_DIR/scripts/kitty-terminfo-install-update.sh"
  fi
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

install_tools() {
  local rc=0
  dnf_install bat fd-find eza || rc=1
  remove_local_bin bat
  remove_local_bin fd
  remove_local_bin eza
  log "zoxide from GitHub (Fedora package is 0.9; upstream is 0.10)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would install zoxide from GitHub"
  else
    bash "$SCRIPTS_DIR/zoxide-install-update.sh" || rc=1
  fi
  return "$rc"
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
    --starship) INSTALL_STARSHIP=1 ;;
    --all)
      INSTALL_DEPS=1
      INSTALL_TOOLS=1
      INSTALL_LAZYGIT=1
      INSTALL_GH=1
      INSTALL_NEOVIM=1
      INSTALL_BTOP=1
      INSTALL_TPM=1
      INSTALL_FZF=1
      INSTALL_STARSHIP=1
      INSTALL_FONTS=1
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

if [[ "$(df_host_os_id)" != "fedora" ]]; then
  echo "On Debian/Ubuntu use ./install.sh (or ./install-copy/install.sh)." >&2
  echo "This installer is Fedora-only." >&2
  exit 1
fi

if needs_privileged_install; then
  ensure_sudo_for_install
fi

install_dotfiles

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  run_github_step "install-fedora-deps.sh" bash "$DOTFILES_DIR/install-fedora-deps.sh"
fi

if [[ "$INSTALL_TOOLS" -eq 1 ]]; then
  run_github_step "tools" install_tools
fi

if [[ "$INSTALL_LAZYGIT" -eq 1 ]]; then
  log "lazygit from GitHub (not in Fedora repos)"
  run_github_step "lazygit" bash "$SCRIPTS_DIR/lazygit-install-update.sh"
fi

if [[ "$INSTALL_GH" -eq 1 ]]; then
  run_github_step "gh" dnf_install gh
  remove_local_bin gh
fi

if [[ "$INSTALL_FZF" -eq 1 ]]; then
  run_github_step "fzf" dnf_install fzf
  remove_local_bin fzf
fi

if [[ "$INSTALL_TPM" -eq 1 ]]; then
  run_github_step "tpm" install_tpm
fi

if [[ "$INSTALL_NEOVIM" -eq 1 ]]; then
  run_github_step "neovim" dnf_install neovim
  remove_local_bin nvim
fi

if [[ "$INSTALL_BTOP" -eq 1 ]]; then
  run_github_step "btop" dnf_install btop
  remove_local_bin btop
fi

if [[ "$INSTALL_STARSHIP" -eq 1 ]]; then
  log "starship from GitHub"
  run_github_step "starship" bash "$SCRIPTS_DIR/starship-install-update.sh"
fi

if [[ "$INSTALL_FONTS" -eq 1 ]]; then
  log "Nerd fonts: Cascadia Code + JetBrains Mono (user fonts + fc-cache)"
  run_github_step "cascadia-nerd-font" bash "$SCRIPTS_DIR/cascadia-nerd-font-install-update.sh"
fi

if [[ "$GITHUB_STEP_FAILED" -eq 1 ]]; then
  log "one or more installs failed; re-run ./install-fedora.sh --all"
  exit 1
fi

cat <<'EOF'

Next steps:
  1. Prompt is ~/.config/dotfiles/prompt.sh (starship on Fedora).
     Custom prompt: ln -sfn ~/.dotfiles/home/.config/dotfiles/prompt-custom.sh ~/.config/dotfiles/prompt.sh
  2. Copy SSH private keys into ~/.ssh/ manually (never commit keys).
  3. Open tmux and press prefix + Shift + I to install tmux plugins.
  4. Optional LazyVim (not part of --all):
       ./lazyvim-lite/install-lazyvim-lite.sh
       ./lazyvim/install-lazyvim.sh
  5. Optional fetch banner (not part of --all):
       ./install-fetch.sh
  6. Optional AI CLIs (not part of --all):
       ./install-ai-cli.sh
  7. Optional: nvm/Node via ./scripts/nvm-install-update.sh
  8. Optional Kitty image previews in LazyVim (local Kitty only):
       ./scripts/kitty-image-support-install-update.sh

EOF
