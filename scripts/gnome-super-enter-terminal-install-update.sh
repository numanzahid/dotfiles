#!/usr/bin/env bash
set -euo pipefail

# Optional: GNOME Super+Enter opens the default terminal.
# No-op when GNOME is not present. Not part of --all.
# Also runs from Alacritty/Kitty installers after they set the default terminal.
#
# Re-run: ./scripts/gnome-super-enter-terminal-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
