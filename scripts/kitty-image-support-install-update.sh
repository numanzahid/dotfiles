#!/usr/bin/env bash
set -euo pipefail

# Optional: LazyVim snacks image (Kitty graphics) + ImageMagick + tmux passthrough.
# Kitty terminfo for SSH/tmux is separate: ./scripts/kitty-terminfo-install-update.sh
# Kitty binary is separate: ./scripts/kitty-install-update.sh
#
# Re-run: ./scripts/kitty-image-support-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/kitty-image-support-install-update.sh

Optional: enable LazyVim snacks.nvim image previews (Kitty graphics).
Not part of --all. Does not install the Kitty binary.

Installs ImageMagick from official apt/dnf (no COPR), writes
~/.config/dotfiles/image-support.enabled, and copies
~/.config/tmux/image-passthrough.conf (tmux allow-passthrough on).

Then: tmux source-file ~/.tmux.conf, restart nvim, use Kitty (not Alacritty).
SSH still needs xterm-kitty terminfo on the remote
(./scripts/kitty-terminfo-install-update.sh).

Options:
  -h, --help   Show this help

Re-run anytime.
EOF
}

# shellcheck source=lib/cli-args.sh
source "$SCRIPT_DIR/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"

case "$(df_os_family)" in
  fedora | debian) ;;
  *)
    echo "ERROR: kitty image support supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ENABLE_FLAG="${CONFIG_HOME}/dotfiles/image-support.enabled"
TMUX_SNIPPET_SRC="${DOTFILES_DIR}/home/.config/tmux/image-passthrough.conf"
TMUX_SNIPPET_DEST="${CONFIG_HOME}/tmux/image-passthrough.conf"
STAMP="${DATA_HOME}/dotfiles/kitty-image-support.version"

install_imagemagick() {
  df_ensure_sudo
  case "$(df_os_family)" in
    fedora)
      df_run_privileged dnf install -y --setopt=install_weak_deps=False ImageMagick
      ;;
    debian)
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y --no-install-recommends imagemagick
      ;;
  esac
}

if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1; then
  echo "Installing ImageMagick..."
  install_imagemagick
else
  echo "ImageMagick already installed"
fi

mkdir -p "$(dirname "$ENABLE_FLAG")" "$(dirname "$TMUX_SNIPPET_DEST")"
touch "$ENABLE_FLAG"
cp -f "$TMUX_SNIPPET_SRC" "$TMUX_SNIPPET_DEST"
mkdir -p "$(dirname "$STAMP")"
printf 'enabled\n' >"$STAMP"

echo "Done."
echo "Flag: $ENABLE_FLAG"
echo "tmux passthrough: $TMUX_SNIPPET_DEST"
echo ""
echo "Next steps:"
echo "  1. Reload tmux: tmux source-file ~/.tmux.conf"
echo "  2. Restart nvim (LazyVim picks up snacks.image on next start)"
echo "  3. Use Kitty locally (not Alacritty) and run: :checkhealth snacks"
echo ""
echo "SSH from Kitty still needs xterm-kitty terminfo on remote hosts:"
echo "  ./scripts/kitty-terminfo-install-update.sh"
