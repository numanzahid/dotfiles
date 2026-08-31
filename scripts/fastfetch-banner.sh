#!/usr/bin/env bash
# Compact boxed fastfetch layout: ~/.config/fastfetch/banner.jsonc
# Text art: ~/.local/share/dotfiles/fastfetch-art  (0=none, 1=tmux logo, 2=custom)
# Plain `fastfetch` uses the built-in default (no config.jsonc).
set -euo pipefail

command -v fastfetch >/dev/null 2>&1 || exit 0

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/banner.jsonc"
ART_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/fastfetch-art"
LOGO_TMUX="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux-logo.txt"
LOGO_CUSTOM="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/logo.txt"

choice="1"
if [[ -f "$ART_FILE" ]]; then
  choice="$(tr -d '[:space:]' <"$ART_FILE")"
fi

args=(--config "$CONFIG")
case "$choice" in
  0)
    args+=(--logo none)
    ;;
  2)
    if [[ -f "$LOGO_CUSTOM" ]]; then
      args+=(--logo "$LOGO_CUSTOM")
    else
      args+=(--logo "$LOGO_TMUX")
    fi
    ;;
  *)
    args+=(--logo "$LOGO_TMUX")
    ;;
esac

exec fastfetch "${args[@]}"
