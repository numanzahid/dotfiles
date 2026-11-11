#!/usr/bin/env bash
set -euo pipefail

# Install xterm-ghostty terminfo for SSH/tmux (no Ghostty binary required).
# Compiled from the ncurses terminfo database (scripts/data/terminfo/x/xterm-ghostty).
#
# Invoked by: ./devbox.sh, ./desktop.sh
# Re-run:     ./scripts/ghostty-terminfo-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF2'
Usage: ./scripts/ghostty-terminfo-install-update.sh

Install xterm-ghostty terminfo into ~/.terminfo (and a cache copy).
No Ghostty binary required. Needed so SSH/tmux from Ghostty can start
(otherwise: "missing or unsuitable terminal: xterm-ghostty").

Source: the blob bundled in scripts/data/terminfo/x/xterm-ghostty.

Invoked by ./devbox.sh and ./desktop.sh (config install) and copied onto
light hosts by ./server.sh. The shell also installs it on first login over
SSH from Ghostty (see home/.bashrc). Fedora and Debian/Ubuntu only.

Options:
  -h, --help   Show this help

Re-run: ./scripts/ghostty-terminfo-install-update.sh
EOF2
}

# shellcheck source=lib/cli-args.sh
source "$SCRIPT_DIR/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/journal.sh
source "$SCRIPT_DIR/lib/journal.sh"

case "$(df_os_family)" in
  fedora | debian) ;;
  *)
    echo "ERROR: ghostty terminfo install supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BUNDLED="${SCRIPT_DIR}/data/terminfo/x/xterm-ghostty"
CACHE_TERMINFO="${DATA_HOME}/dotfiles/terminfo/x/xterm-ghostty"
USER_TERMINFO="${HOME}/.terminfo/x/xterm-ghostty"
STAMP="${DATA_HOME}/dotfiles/ghostty-terminfo.version"

if [[ ! -f "$BUNDLED" ]]; then
  echo "ERROR: no xterm-ghostty terminfo source found ($BUNDLED)" >&2
  exit 1
fi

src_hash="$(cksum "$BUNDLED" | awk '{print $1 "-" $2}')"
if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$src_hash" ]] &&
  [[ -f "$USER_TERMINFO" ]] && infocmp xterm-ghostty >/dev/null 2>&1; then
  echo "Already current: xterm-ghostty terminfo"
  exit 0
fi

mkdir -p "$(dirname "$USER_TERMINFO")" "$(dirname "$CACHE_TERMINFO")"
# Compiled terminfo blob; ncurses reads ~/.terminfo without tic.
cp -f "$BUNDLED" "$USER_TERMINFO"
cp -f "$BUNDLED" "$CACHE_TERMINFO"
df_journal_once copy "$USER_TERMINFO" "$BUNDLED"
df_journal_once copy "$CACHE_TERMINFO" "$BUNDLED"
mkdir -p "$(dirname "$STAMP")"
printf '%s\n' "$src_hash" >"$STAMP"
df_journal_once copy "$STAMP" "ghostty-terminfo"

echo "Done."
echo "xterm-ghostty terminfo: $USER_TERMINFO"
if infocmp xterm-ghostty >/dev/null 2>&1; then
  echo "infocmp xterm-ghostty: ok"
else
  echo "WARN: infocmp xterm-ghostty still failing; open a new shell" >&2
fi
