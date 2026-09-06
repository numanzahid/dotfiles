# Starship prompt. Linked as ~/.config/dotfiles/prompt.sh by ./desktop.sh.
# Install binary with ./scripts/starship-install-update.sh.

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
