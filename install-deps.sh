#!/usr/bin/env bash
# Base apt packages for dotfiles (not user CLI tools).
# Neovim, bat, fd, fzf, lazygit, fastfetch, etc. use scripts/ instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPT_DIR/scripts/lib/privilege.sh"
# shellcheck source=scripts/lib/journal.sh
source "$SCRIPT_DIR/scripts/lib/journal.sh"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-deps.sh supports apt-based systems only." >&2
  echo "On Fedora use ./install-fedora.sh --deps" >&2
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
echo "Fzf:       ./install.sh --fzf  (git install, recommended)"
echo "Fastfetch: ./install-fetch.sh"
echo "Neovim:    ./install.sh --neovim  (or --all)"
echo "Btop:      ./install.sh --btop    (or --all)"
echo "Nvm/Node:  ./scripts/nvm-install-update.sh"
echo "AI CLIs:   ./install-ai-cli.sh  (opencode, cursor, claude, codex)"
echo "LazyVim:   ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh"
