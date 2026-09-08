#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fzf from GitHub (junegunn/fzf).
# Re-run anytime to upgrade.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME:?}"

usage() {
  cat <<'EOF'
Usage: ./scripts/fzf-install-update.sh [options]

Install or upgrade fzf from GitHub (git clone + install script).
Writes ~/.fzf.bash. Invoked by ./devbox.sh and ./desktop.sh --fzf.

On Fedora desktop, dnf fzf is used instead (see desktop.sh).

Options:
  --uninstall  Remove ~/.fzf, ~/.fzf.bash, and journaled fzf package
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help
EOF
}

# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"
# shellcheck source=lib/journal.sh
source "$SCRIPT_DIR/lib/journal.sh"

git_github() {
  git -c http.version=HTTP/1.1 "$@"
}

uninstall_fzf() {
  df_inst_remove_fzf
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall fzf uninstall_fzf; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

install_fzf() {
  local fzf_dir="$TARGET_HOME/.fzf"

  if [[ -d "$fzf_dir/.git" ]]; then
    echo "Updating fzf in $fzf_dir"
    git_github -C "$fzf_dir" pull -4 --ff-only
  else
    echo "Installing fzf..."
    mkdir -p "$TARGET_HOME/.fzf"
    git_github clone -4 --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
  fi

  if [[ -L "$TARGET_HOME/.fzf.bash" ]]; then
    echo "Replace fzf bash stub symlink with a real file"
    rm -f "$TARGET_HOME/.fzf.bash"
  fi
  "$fzf_dir/install" --all --no-update-rc
  df_journal_once git-clone "$fzf_dir"
  if [[ -f "$TARGET_HOME/.fzf.bash" ]]; then
    df_journal_once copy "$TARGET_HOME/.fzf.bash"
  fi
}

install_fzf
echo "Done."
echo "fzf path: $(command -v fzf || true)"
fzf --version 2>&1 | head -n 1 || true
