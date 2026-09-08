#!/usr/bin/env bash
set -euo pipefail

# Install tmux plugin manager (tpm) from GitHub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME:?}"

usage() {
  cat <<'EOF'
Usage: ./scripts/tpm-install-update.sh [options]

Clone tmux-plugins/tpm into ~/.tmux/plugins/tpm.
Invoked by ./devbox.sh and ./desktop.sh.

Options:
  --uninstall  Remove ~/.tmux/plugins/tpm
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

uninstall_tpm() {
  df_inst_remove_tpm
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall tpm uninstall_tpm; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
if [[ -d "$tpm_dir/.git" ]]; then
  echo "tpm already installed: $tpm_dir"
else
  echo "Installing tmux plugin manager..."
  mkdir -p "$TARGET_HOME/.tmux/plugins"
  git_github clone -4 https://github.com/tmux-plugins/tpm "$tpm_dir"
fi
df_journal_once git-clone "$tpm_dir"
echo "Done."
echo "tpm path: $tpm_dir"
