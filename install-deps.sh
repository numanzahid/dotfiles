#!/usr/bin/env bash
# Base apt packages for dotfiles (not user CLI tools).
# Neovim, bat, fd, fzf, lazygit, fastfetch, etc. use scripts/ instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install-deps.sh [options]

Base apt packages for Debian/Ubuntu workstation installs (not Fedora).
Invoked by ./devbox.sh (full install).

Installs: bash bash-completion ca-certificates curl git gzip jq less
locales ripgrep tar tmux trash-cli wget unzip fontconfig.
Enables en_US.UTF-8. Needs sudo.

Does not install Neovim, bat, fd, fzf, lazygit, or fastfetch
(those have their own scripts).

On Fedora use ./desktop.sh --deps.

Options:
  --uninstall  Remove apt packages dotfiles recorded as package-new
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help
EOF
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

# shellcheck source=scripts/lib/install-cli.sh
source "$SCRIPTS_DIR/lib/install-cli.sh"
# shellcheck source=scripts/lib/software-uninstall.sh
source "$SCRIPTS_DIR/lib/software-uninstall.sh"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPTS_DIR/lib/privilege.sh"
# shellcheck source=scripts/lib/journal.sh
source "$SCRIPTS_DIR/lib/journal.sh"

uninstall_deps() {
  df_inst_remove_deps_packages
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall deps uninstall_deps; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-deps.sh supports apt-based systems only." >&2
  echo "On Fedora use ./desktop.sh --deps" >&2
  exit 1
fi

df_ensure_sudo

PACKAGES=(
  bash
  bash-completion
  ca-certificates
  curl
  git
  gzip
  jq
  less
  locales
  ripgrep
  tar
  tmux
  trash-cli
  wget
  unzip
  fontconfig
)

echo "Updating package lists..."
df_run_privileged apt-get update

missing=()
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] && missing+=("$pkg")
done < <(df_collect_missing_packages "${PACKAGES[@]}")

echo "Installing packages..."
df_run_privileged apt-get install -y "${PACKAGES[@]}"
if ((${#missing[@]} > 0)); then
  df_journal_new_packages "${missing[@]}"
fi

setup_utf8_locale() {
  if [[ ! -f /etc/locale.gen ]]; then
    return 0
  fi

  if grep -qE '^[[:space:]]*#?[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
    df_run_privileged sed -i 's/^[[:space:]]*#\([[:space:]]*en_US\.UTF-8[[:space:]]\+UTF-8\)/\1/' /etc/locale.gen
  else
    echo "en_US.UTF-8 UTF-8" | df_run_privileged tee -a /etc/locale.gen >/dev/null
  fi

  df_run_privileged locale-gen en_US.UTF-8
  df_run_privileged update-locale LANG=en_US.UTF-8 LC_ALL=
  df_journal_once locale en_US.UTF-8

  if locale -a 2>/dev/null | grep -qE 'en_US\.(utf8|UTF-8)'; then
    export LANG=en_US.UTF-8
    unset LC_ALL || true
  fi
  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-environment -g LANG en_US.UTF-8 2>/dev/null || true
    tmux set-environment -gu LC_ALL 2>/dev/null || true
  fi
}

echo "Configuring UTF-8 locale..."
set +e
setup_utf8_locale
locale_rc=$?
set -e
if [[ "$locale_rc" -ne 0 ]]; then
  echo "WARN: UTF-8 locale setup failed; continuing (set LANG manually if needed)" >&2
else
  echo "UTF-8 locale is generated. This SSH session still has the old pty encoding."
  echo "  Close the SSH client and ssh in again (exec bash / tmux kill is not enough)."
  echo "A CT reboot is not required."
fi

echo "Done. CLI tools (bat, fd, zoxide, eza): ./install-tools.sh"
echo "Lazygit:   ./scripts/lazygit-install-update.sh"
echo "Gh:        ./scripts/gh-install-update.sh"
echo "Fzf:       ./devbox.sh --fzf  (git install, recommended)"
echo "Tldr:      ./devbox.sh --tldr  (tealdeer from GitHub)"
echo "Fastfetch: ./install-fetch.sh"
echo "Neovim:    ./scripts/neovim-install-update.sh  (or re-run ./devbox.sh)"
echo "Btop:      ./scripts/btop-install-update.sh    (or re-run ./devbox.sh)"
echo "Nvm/Node:  ./scripts/nvm-install-update.sh"

echo "LazyVim:   ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh"
