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
INSTALL_FASTFETCH=0
INSTALL_PFETCH=0
INSTALL_TPM=0
INSTALL_FZF=0
PROMPT_FETCH=0
FETCH_MODE=""
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
  --fastfetch  Install fastfetch and enable tmux fetch banner
  --pfetch     Install pfetch and enable tmux fetch banner
  --fetch MODE Set tmux fetch mode: none, fastfetch, or pfetch (non-interactive)
  --tpm        Clone tmux-plugin-manager if missing
  --fzf        Clone and install junegunn/fzf if missing
  --all        Enable --deps --tools --lazygit --gh --neovim --tpm --fzf
               (prompts for optional tmux fetch banner: none / fastfetch / pfetch)
  --dry-run    Print actions without changing anything
  -h, --help   Show this help

LazyVim extras (optional, not part of --all):
  ./lazyvim/install-lazyvim.sh

Tmux fetch banners (optional, not enabled by default):
  ./scripts/setup-tmux-fetch.sh              # interactive prompt
  ./scripts/setup-tmux-fetch.sh fastfetch
  ./scripts/setup-tmux-fetch.sh none

Default behavior links config files into $HOME.
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

needs_privileged_install() {
  [[ "$INSTALL_DEPS" -eq 1 ||
    "$INSTALL_TOOLS" -eq 1 ||
    "$INSTALL_LAZYGIT" -eq 1 ||
    "$INSTALL_GH" -eq 1 ||
    "$INSTALL_NEOVIM" -eq 1 ||
    "$INSTALL_FASTFETCH" -eq 1 ||
    "$INSTALL_PFETCH" -eq 1 ]]
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

link_path() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    log "already linked: $dest"
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup="${dest}.pre-dotfiles-$(date +%Y%m%d%H%M%S)"
    log "backup existing: $dest -> $backup"
    run mv "$dest" "$backup"
  fi

  log "link: $dest -> $src"
  run ln -sfn "$src" "$dest"
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

link_fetch_conf_default() {
  local dest="$TARGET_HOME/.config/tmux/fetch.conf"
  local src="$SOURCE_DIR/.config/tmux/fetch-none.conf"

  mkdir -p "$TARGET_HOME/.config/tmux"

  if [[ -e "$dest" ]]; then
    log "exists, not overwriting: $dest"
    return 0
  fi

  log "default tmux fetch mode: none -> $dest"
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
  link_path "$SOURCE_DIR/.fzf.bash" "$TARGET_HOME/.fzf.bash"

  link_path "$SOURCE_DIR/.config/nvim" "$TARGET_HOME/.config/nvim"
  link_path "$SOURCE_DIR/.config/fastfetch" "$TARGET_HOME/.config/fastfetch"

  link_path "$SOURCE_DIR/.config/tmux/fastfetch.jsonc" "$TARGET_HOME/.config/tmux/fastfetch.jsonc"
  # Back-compat for old fastfetch --config ~/.config/fastfetch/tmux2.jsonc references.
  link_path "$SOURCE_DIR/.config/tmux/fastfetch.jsonc" "$TARGET_HOME/.config/fastfetch/tmux2.jsonc"
  link_path "$SOURCE_DIR/.config/tmux/tmux-logo.txt" "$TARGET_HOME/.config/tmux/tmux-logo.txt"
  link_path "$SOURCE_DIR/.config/tmux/fetch-none.conf" "$TARGET_HOME/.config/tmux/fetch-none.conf"
  link_path "$SOURCE_DIR/.config/tmux/fetch-fastfetch.conf" "$TARGET_HOME/.config/tmux/fetch-fastfetch.conf"
  link_path "$SOURCE_DIR/.config/tmux/fetch-pfetch.conf" "$TARGET_HOME/.config/tmux/fetch-pfetch.conf"
  link_fetch_conf_default

  mkdir -p "$TARGET_HOME/.config/pfetch"
  link_path "$SOURCE_DIR/.config/pfetch/pfetchrc" "$TARGET_HOME/.config/pfetch/pfetchrc"
  link_path "$SOURCE_DIR/.config/btop" "$TARGET_HOME/.config/btop"
  mkdir -p "$TARGET_HOME/.config/lazygit"
  link_path "$SOURCE_DIR/.config/lazygit/config.yml" "$TARGET_HOME/.config/lazygit/config.yml"
  mkdir -p "$TARGET_HOME/.config/opencode"
  link_path "$SOURCE_DIR/.config/opencode/opencode.jsonc" "$TARGET_HOME/.config/opencode/opencode.jsonc"

  mkdir -p "$TARGET_HOME/.ssh"
  chmod 700 "$TARGET_HOME/.ssh"
  copy_if_missing "$SOURCE_DIR/.ssh/config.example" "$TARGET_HOME/.ssh/config"
  run chmod 600 "$TARGET_HOME/.ssh/config" 2>/dev/null || true

  # Default nvim to minimal (no LazyVim) until lazyvim/install-lazyvim.sh runs.
  # shellcheck disable=SC1091
  source "$DOTFILES_DIR/scripts/nvim-profile.sh"
  ensure_nvim_profile_default
  log "nvim profile: $(get_nvim_profile) (run ./lazyvim/install-lazyvim.sh for LazyVim)"
}

install_tpm() {
  local tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm_dir/.git" ]]; then
    log "tpm already installed: $tpm_dir"
    return 0
  fi

  log "installing tmux plugin manager..."
  run mkdir -p "$TARGET_HOME/.tmux/plugins"
  run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
}

install_fzf() {
  local fzf_dir="$TARGET_HOME/.fzf"

  if [[ -d "$fzf_dir/.git" ]]; then
    log "updating fzf in $fzf_dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run git -C "$fzf_dir" pull --ff-only
    else
      git -C "$fzf_dir" pull --ff-only
    fi
  else
    log "installing fzf..."
    run git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
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
    --fastfetch)
      INSTALL_FASTFETCH=1
      FETCH_MODE="fastfetch"
      ;;
    --pfetch)
      INSTALL_PFETCH=1
      FETCH_MODE="pfetch"
      ;;
    --fetch)
      shift
      FETCH_MODE="${1:?--fetch requires none, fastfetch, or pfetch}"
      case "$FETCH_MODE" in
        none)
          INSTALL_FASTFETCH=0
          INSTALL_PFETCH=0
          ;;
        fastfetch) INSTALL_FASTFETCH=1 ;;
        pfetch) INSTALL_PFETCH=1 ;;
        *)
          echo "Unknown --fetch mode: $FETCH_MODE" >&2
          exit 1
          ;;
      esac
      shift
      ;;
    --tpm) INSTALL_TPM=1 ;;
    --fzf) INSTALL_FZF=1 ;;
    --all)
      INSTALL_DEPS=1
      INSTALL_TOOLS=1
      INSTALL_LAZYGIT=1
      INSTALL_GH=1
      INSTALL_NEOVIM=1
      INSTALL_TPM=1
      INSTALL_FZF=1
      PROMPT_FETCH=1
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

if needs_privileged_install; then
  ensure_sudo_for_install
fi

install_dotfiles

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run "$DOTFILES_DIR/install-deps.sh"
  else
    bash "$DOTFILES_DIR/install-deps.sh"
  fi
fi

if [[ "$INSTALL_TOOLS" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run "$DOTFILES_DIR/install-tools.sh"
  else
    bash "$DOTFILES_DIR/install-tools.sh"
  fi
fi

if [[ "$INSTALL_LAZYGIT" -eq 1 ]]; then
  log "installing lazygit via scripts/lazygit-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/lazygit-install-update.sh"
  else
    bash "$SCRIPTS_DIR/lazygit-install-update.sh"
  fi
fi

if [[ "$INSTALL_GH" -eq 1 ]]; then
  log "installing gh via scripts/gh-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/gh-install-update.sh"
  else
    bash "$SCRIPTS_DIR/gh-install-update.sh"
  fi
fi

if [[ "$INSTALL_FZF" -eq 1 ]]; then
  install_fzf
fi

if [[ "$INSTALL_TPM" -eq 1 ]]; then
  install_tpm
fi

if [[ "$INSTALL_NEOVIM" -eq 1 ]]; then
  log "installing neovim via scripts/neovim-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/neovim-install-update.sh"
  else
    bash "$SCRIPTS_DIR/neovim-install-update.sh"
  fi
fi

if [[ "$INSTALL_FASTFETCH" -eq 1 ]]; then
  log "installing fastfetch via scripts/fastfetch-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/fastfetch-install-update.sh"
    run bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" fastfetch
  else
    bash "$SCRIPTS_DIR/fastfetch-install-update.sh"
    bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" fastfetch
  fi
fi

if [[ "$INSTALL_PFETCH" -eq 1 ]]; then
  log "installing pfetch via scripts/pfetch-install-update.sh"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/pfetch-install-update.sh"
    run bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" pfetch
  else
    bash "$SCRIPTS_DIR/pfetch-install-update.sh"
    bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" pfetch
  fi
fi

if [[ "$PROMPT_FETCH" -eq 1 && -z "$FETCH_MODE" ]]; then
  log "optional tmux fetch banner"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/setup-tmux-fetch.sh" --dry-run
  else
    bash "$SCRIPTS_DIR/setup-tmux-fetch.sh"
  fi
elif [[ -n "$FETCH_MODE" && "$FETCH_MODE" == "none" && "$PROMPT_FETCH" -eq 0 ]]; then
  log "tmux fetch banner: none"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" none
  else
    bash "$SCRIPTS_DIR/enable-tmux-fetch.sh" none
  fi
fi

cat <<'EOF'

Next steps:
  1. Copy SSH private keys into ~/.ssh/ manually (never commit keys).
  2. Open tmux and press prefix + Shift + I to install tmux plugins.
  3. Optional LazyVim setup (enables LazyVim profile + plugins):
       ./lazyvim/install-lazyvim.sh
     Without it, nvim uses a minimal config with no plugin downloads.
  4. Tmux fetch banner: chosen during install, or run:
       ./scripts/setup-tmux-fetch.sh
  5. Optional: nvm/Node via ./scripts/nvm-install-update.sh

EOF
