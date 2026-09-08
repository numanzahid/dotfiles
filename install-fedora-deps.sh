#!/usr/bin/env bash
# Base dnf packages for Fedora.
# CLI tools that may come from GitHub are chosen by ./desktop.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install-fedora-deps.sh [options]

Base dnf packages for Fedora workstation installs.
Invoked by ./desktop.sh --deps / --all.

Installs: bash bash-completion ca-certificates curl git gzip jq less
ripgrep tar tmux trash-cli wget unzip fontconfig.
Needs sudo. Official Fedora repos only (no COPR).

CLI tools that may come from GitHub are chosen by ./desktop.sh
(zoxide, lazygit, starship, fonts, fastfetch).

On Debian/Ubuntu use ./install-deps.sh.

Options:
  --uninstall  Remove dnf packages dotfiles recorded as package-new
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
# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
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

if [[ "$(df_host_os_id)" != "fedora" ]]; then
  echo "install-fedora-deps.sh is for Fedora. On Debian/Ubuntu use ./install-deps.sh" >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "install-fedora-deps.sh needs dnf." >&2
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
  ripgrep
  tar
  tmux
  trash-cli
  wget
  unzip
  fontconfig
)

echo "Refreshing Fedora metadata..."
df_run_privileged dnf makecache

missing=()
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] && missing+=("$pkg")
done < <(df_collect_missing_packages "${PACKAGES[@]}")

echo "Installing Fedora packages..."
df_run_privileged dnf install -y "${PACKAGES[@]}"
if ((${#missing[@]} > 0)); then
  df_journal_new_packages "${missing[@]}"
fi

echo "Done. Tool binaries: ./desktop.sh --tools --neovim --btop --fzf --gh --lazygit --starship"
echo "dnf: bat fd-find eza btop fzf gh neovim. GitHub: zoxide lazygit starship."
echo "Fastfetch: ./install-fetch.sh"
echo "Nvm/Node:      ./scripts/nvm-install-update.sh"

echo "LazyVim:       ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh"
