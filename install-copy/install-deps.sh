#!/usr/bin/env bash
# Apt packages for install-copy (no GitHub CLI tools).
set -euo pipefail

COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$COPY_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install-copy/install-deps.sh

Apt packages for light hosts / CTs. Invoked by
./install-copy/install.sh --deps / --all.

Installs: bash bash-completion ca-certificates curl git gzip htop jq
less locales tar tmux wget. Enables en_US.UTF-8. Needs sudo.

Slimmer than ./install-deps.sh (no ripgrep, trash-cli, unzip, fontconfig).
Apt-based systems only.

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

echo "install-copy deps done."
echo "apt: ${PACKAGES[*]}"
