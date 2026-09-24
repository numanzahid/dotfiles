#!/usr/bin/env bash
# Base OS packages for server (no GitHub CLI tools). Apt or dnf.
set -euo pipefail

SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SERVER_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./server/install-deps.sh

Base OS packages for light hosts / CTs (apt or dnf). Invoked by
./server.sh --deps / --all.

Installs: bash bash-completion ca-certificates curl git gzip htop jq
less tar tmux wget, plus the locale package for your distro. Enables
en_US.UTF-8. Needs sudo.

Slimmer than ./install-deps.sh / ./install-fedora-deps.sh (no ripgrep,
trash-cli, unzip, fontconfig).

Options:
  -h, --help   Show this help
EOF
}

# shellcheck source=../scripts/lib/cli-args.sh
source "$DOTFILES_DIR/scripts/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"
# shellcheck source=../scripts/lib/journal.sh
source "$DOTFILES_DIR/scripts/lib/journal.sh"

if command -v apt-get >/dev/null 2>&1; then
  PKG_MANAGER=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER=dnf
else
  echo "server/install-deps.sh supports apt-based and dnf-based systems only." >&2
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
  tar
  tmux
  wget
)
case "$PKG_MANAGER" in
  apt) PACKAGES+=(locales) ;;
  dnf) PACKAGES+=(glibc-langpack-en) ;;
esac

case "$PKG_MANAGER" in
  apt)
    echo "Updating package lists..."
    df_run_privileged apt-get update
    ;;
  dnf)
    echo "Refreshing dnf metadata..."
    df_run_privileged dnf makecache
    ;;
esac

missing=()
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] && missing+=("$pkg")
done < <(df_collect_missing_packages "${PACKAGES[@]}")

echo "Installing packages..."
case "$PKG_MANAGER" in
  apt) df_run_privileged apt-get install -y "${PACKAGES[@]}" ;;
  dnf) df_run_privileged dnf install -y "${PACKAGES[@]}" ;;
esac
if ((${#missing[@]} > 0)); then
  df_journal_new_packages "${missing[@]}"
fi

setup_utf8_locale_apt() {
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
}

setup_utf8_locale_dnf() {
  # glibc-langpack-en (installed above) provides the compiled en_US.UTF-8
  # locale; localectl (systemd) just needs to be told to use it.
  command -v localectl >/dev/null 2>&1 || return 0
  if locale -a 2>/dev/null | grep -qiE '^en_US\.(utf8|UTF-8)$'; then
    df_run_privileged localectl set-locale LANG=en_US.UTF-8
    df_journal_once locale en_US.UTF-8
  else
    echo "WARN: en_US.UTF-8 not available after installing glibc-langpack-en" >&2
    return 1
  fi
}

setup_utf8_locale() {
  case "$PKG_MANAGER" in
    apt) setup_utf8_locale_apt ;;
    dnf) setup_utf8_locale_dnf ;;
  esac

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

echo "server deps done."
echo "$PKG_MANAGER: ${PACKAGES[*]}"
echo "Optional Proton Pass CLI (PAT/SSH): ./scripts/proton-pass-cli-setup.sh"
echo "Optional Syncthing: ./scripts/syncthing-install-update.sh"
