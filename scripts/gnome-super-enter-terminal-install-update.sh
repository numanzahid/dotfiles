#!/usr/bin/env bash
set -euo pipefail

# Optional: GNOME Super+Enter opens the default terminal.
# No-op when GNOME is not present. Not part of --all.
# Also runs from Alacritty/Kitty installers after they set the default terminal.
#
# Re-run: ./scripts/gnome-super-enter-terminal-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/gnome-super-enter-terminal-install-update.sh

Optional: GNOME Super+Enter opens the default terminal.
No-op when GNOME is not present. Not part of --all. No sudo.

Installs ~/.local/bin/dotfiles-default-terminal and a GNOME custom
keybinding. Uses the last Alacritty/Kitty default, else gnome-terminal.
Also runs from those terminal installers after they set the default.

Does not wipe other custom keybindings.

Options:
  -h, --help   Show this help

Re-run anytime.
EOF
}

# shellcheck source=lib/cli-args.sh
source "$SCRIPT_DIR/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck source=lib/gui-terminal.sh
source "$SCRIPT_DIR/lib/gui-terminal.sh"

STAMP="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/gnome-super-enter-terminal.version"

if ! df_gnome_desktop_available; then
  echo "GNOME not present; skip Super+Enter terminal shortcut"
  exit 0
fi

df_gnome_bind_super_enter_terminal

mkdir -p "$(dirname "$STAMP")"
printf 'super-return\n' >"$STAMP"

echo "Done."
echo "Shortcut: Super+Enter -> ${HOME}/.local/bin/dotfiles-default-terminal"
echo "Uses the last Alacritty/Kitty default, or GNOME/gnome-terminal fallback."
