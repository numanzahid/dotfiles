#!/usr/bin/env bash
# Link dotfiles from this repo into $HOME. Fedora or Debian/Ubuntu.
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

Full workstation install on Debian/Ubuntu or Fedora: link configs,
packages, CLI tools, fonts, tmux TPM, and AI agent rules. Detects the
distro; bat/fd/eza/gh/fzf/neovim/btop come from dnf on Fedora, GitHub
releases everywhere else.

Options:
  --configs-only   Link configs and AI rules only (no software)
  --software-only  Install or upgrade software only (no config links)
  --dry-run        Print actions without changing anything
  --yes, -y        Assume yes to prompts (DF_YES=1); needed for root/no-TTY
                    provisioning (containers, cloud-init, Ansible)
  -h, --help       Show this help

Environment (used by dotfiles update):
  DOTFILES_RESPECT_COMPONENT_AGE=1   Skip software updated within 30 days

Single-tool installs: ./scripts/<tool>-install-update.sh

Optional extras:
  dotfiles install lazyvim | lazyvim-lite | fetch
  dotfiles sync lazyvim | lazyvim-lite
  ./scripts/alacritty-install-update.sh
  ./scripts/kitty-install-update.sh
  ./scripts/localsend-install-update.sh

desktop.sh is equivalent (same distro detection, different default prompt,
plus starship); use whichever name you prefer.
EOF
}

log() {
  printf '[dotfiles] %s\n' "$*"
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

install_software_devbox() {
  install_software_workstation
}

# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"
# shellcheck source=scripts/lib/component-state.sh
source "$SCRIPTS_DIR/lib/component-state.sh"
# shellcheck source=scripts/lib/installer-common.sh
source "$SCRIPTS_DIR/lib/installer-common.sh"

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

install_dotfiles() {
  log "source: $SOURCE_DIR"
  log "target: $TARGET_HOME"

  remove_old_fedora_dropin

  link_path "$SOURCE_DIR/.bashrc" "$TARGET_HOME/.bashrc"
  link_path "$SOURCE_DIR/.shell_aliases_interactive.sh" "$TARGET_HOME/.shell_aliases_interactive.sh"
  link_path "$SOURCE_DIR/.inputrc" "$TARGET_HOME/.inputrc"
  link_path "$SOURCE_DIR/.profile" "$TARGET_HOME/.profile"
  link_path "$SOURCE_DIR/.gitconfig" "$TARGET_HOME/.gitconfig"
  link_path "$SOURCE_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf"
  link_prompt_default
  link_path "$SOURCE_DIR/.config/dotfiles/locale.sh" "$TARGET_HOME/.config/dotfiles/locale.sh"
  link_path "$SOURCE_DIR/.config/dotfiles/proton-pass-env.sh" "$TARGET_HOME/.config/dotfiles/proton-pass-env.sh"

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
    --yes | -y) export DF_YES=1 ;;
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

if [[ "$(df_os_family)" == unknown ]]; then
  echo "This installer supports Debian/Ubuntu and Fedora (got $(df_host_os_id))." >&2
  echo "On a server/VPS/CT, ./server.sh may fit better." >&2
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
  4. Day to day: dotfiles update; dotfiles sync lazyvim after pull (LazyVim hosts)

EOF
fi
