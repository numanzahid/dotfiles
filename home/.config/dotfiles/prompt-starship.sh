# Starship prompt. Linked as ~/.config/dotfiles/prompt.sh by ./install-fedora.sh.
# Install binary with ./scripts/starship-install-update.sh (GitHub, not COPR).

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
