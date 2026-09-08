#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade GitHub CLI (gh) from official GitHub releases.
# https://github.com/cli/cli
#
# Re-run anytime to upgrade.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/gh-install-update.sh [options]

Install or upgrade GitHub CLI (gh) from official GitHub .deb releases.
https://github.com/cli/cli

Removes the cli.github.com apt repo if present (not needed for this installer).
Debian/Ubuntu only (uses apt-get to install the .deb). Needs curl, jq, sudo.
Invoked by ./devbox.sh --gh / --all.
On Fedora, ./desktop.sh --gh uses the dnf package instead.
Not part of copy-install.

Options:
  --uninstall  Remove gh package, binary, and cli.github.com apt repo files
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help

Re-run anytime to upgrade.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"

uninstall_gh() {
  df_inst_remove_gh
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall gh uninstall_gh; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="cli/cli"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

for cmd in curl jq; do
  if ! need_cmd "$cmd"; then
    echo "ERROR: need $cmd" >&2
    exit 1
  fi
done

if ! need_cmd apt-get; then
  echo "ERROR: need apt-get to install the .deb package" >&2
  exit 1
fi

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo" >&2
    exit 1
  fi
fi

remove_gh_apt_repo() {
  local sudo_cmd="$SUDO"
  local f

  if grep -rq 'cli\.github\.com' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    echo "Removing GitHub CLI apt repo (dotfiles installs gh from GitHub .deb releases)"
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      echo "  remove: $f"
      $sudo_cmd rm -f "$f"
    done < <(grep -rl 'cli\.github\.com' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
  fi

  if [[ -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; then
    echo "  remove: /etc/apt/keyrings/githubcli-archive-keyring.gpg"
    $sudo_cmd rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg
  fi

  shopt -s nullglob
  local -a stale=(/var/lib/apt/lists/*cli.github.com*)
  shopt -u nullglob
  if ((${#stale[@]} > 0)); then
    echo "  remove stale apt list cache for cli.github.com"
    $sudo_cmd rm -f "${stale[@]}"
  fi
}

remove_gh_apt_repo

latest_tag() {
  gr_latest_tag "$REPO"
}

deb_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

GH_BIN="$(command -v gh || true)"
GH_BIN="${GH_BIN:-/usr/bin/gh}"

tag="$(latest_tag || true)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  gr_exit_if_keeping "$GH_BIN" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest gh release tag" >&2
  exit 1
fi

if gr_bin_has_tag "$GH_BIN" "$tag"; then
  echo "Already current: $GH_BIN ($tag)"
  echo "Done."
  echo "gh path: $(command -v gh || true)"
  gh --version 2>&1 | head -n 1 || true
  exit 0
fi

version="${tag#v}"
arch="$(deb_arch)"
asset="gh_${version}_linux_${arch}.deb"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

deb="${tmpdir}/${asset}"

if ! gr_download "$url" "$deb"; then
  gr_exit_if_keeping "$GH_BIN" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
  exit 1
fi

was_installed=0
if declare -F df_pkg_is_installed >/dev/null 2>&1 && df_pkg_is_installed gh; then
  was_installed=1
elif command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' gh 2>/dev/null | grep -q "install ok installed"; then
  was_installed=1
fi

echo "Installing: $asset"
$SUDO apt-get install -y "$deb"
if [[ "$was_installed" -eq 0 ]] && declare -F df_journal_once >/dev/null 2>&1; then
  df_journal_once package-new gh
fi

echo "Done."
echo "gh path: $(command -v gh || true)"
gh --version 2>&1 | head -n 1 || true
