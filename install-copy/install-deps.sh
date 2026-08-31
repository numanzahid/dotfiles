#!/usr/bin/env bash
# Apt packages for install-copy (no GitHub CLI tools).
set -euo pipefail

COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$COPY_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-copy/install-deps.sh supports apt-based systems only." >&2
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
  htop
  jq
  less
  locales
  tar
  tmux
  wget
)

echo "Updating package lists..."
df_run_privileged apt-get update

echo "Installing packages..."
df_run_privileged apt-get install -y "${PACKAGES[@]}"

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
  echo "UTF-8 locale is generated. This SSH/tmux session may still have LANG=C."
  echo "  New glyphs: exec bash -l"
  echo "  Already in tmux: open a new pane, or tmux kill-server && tmux"
  echo "A CT reboot is not required."
fi

echo "install-copy deps done."
echo "apt: ${PACKAGES[*]}"
