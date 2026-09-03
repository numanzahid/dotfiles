#!/usr/bin/env bash
set -euo pipefail

# Install xterm-kitty terminfo for SSH/tmux (no Kitty binary required).
# Bundled from Kitty releases; refreshed when ./scripts/kitty-install-update.sh runs.
#
# Invoked by: ./install.sh --all, ./install-fedora.sh --all
# Re-run:     ./scripts/kitty-terminfo-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"

case "$(df_os_family)" in
  fedora | debian) ;;
  *)
    echo "ERROR: kitty terminfo install supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BUNDLED="${SCRIPT_DIR}/data/terminfo/x/xterm-kitty"
KITTY_TERMINFO="${HOME}/.local/kitty.app/lib/kitty/terminfo/x/xterm-kitty"
CACHE_TERMINFO="${DATA_HOME}/dotfiles/terminfo/x/xterm-kitty"
USER_TERMINFO="${HOME}/.terminfo/x/xterm-kitty"
STAMP="${DATA_HOME}/dotfiles/kitty-terminfo.version"

pick_source() {
  if [[ -f "$KITTY_TERMINFO" ]]; then
    printf '%s\n' "$KITTY_TERMINFO"
    return 0
  fi
  if [[ -f "$BUNDLED" ]]; then
    printf '%s\n' "$BUNDLED"
    return 0
  fi
  return 1
}

install_terminfo() {
  local src="$1"
  mkdir -p "$(dirname "$USER_TERMINFO")" "$(dirname "$CACHE_TERMINFO")"
  # Compiled terminfo blob; ncurses reads ~/.terminfo without tic or fc-cache.
  cp -f "$src" "$USER_TERMINFO"
  cp -f "$src" "$CACHE_TERMINFO"
}

src="$(pick_source || true)"
if [[ -z "$src" ]]; then
  echo "ERROR: no xterm-kitty terminfo source found" >&2
  exit 1
fi

src_hash="$(cksum "$src" | awk '{print $1 "-" $2}')"
if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$src_hash" ]] &&
  [[ -f "$USER_TERMINFO" ]] && infocmp xterm-kitty >/dev/null 2>&1; then
  echo "Already current: xterm-kitty terminfo"
  exit 0
fi

install_terminfo "$src"
mkdir -p "$(dirname "$STAMP")"
printf '%s\n' "$src_hash" >"$STAMP"

echo "Done."
echo "xterm-kitty terminfo: $USER_TERMINFO"
if infocmp xterm-kitty >/dev/null 2>&1; then
  echo "infocmp xterm-kitty: ok"
else
  echo "WARN: infocmp xterm-kitty still failing; open a new shell" >&2
fi
