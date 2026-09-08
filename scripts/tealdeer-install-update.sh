#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade tealdeer (tldr client) from GitHub releases.
# https://github.com/tealdeer-rs/tealdeer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_PATH="/usr/local/bin/tldr"
TLDR_PAGE_SRC="$DOTFILES_DIR/share/tldr/dotfiles.page.md"

usage() {
  cat <<'EOF'
Usage: ./scripts/tealdeer-install-update.sh [options]

Install or upgrade tealdeer from GitHub releases (tldr command).
https://github.com/tealdeer-rs/tealdeer

Installs /usr/local/bin/tldr and refreshes the local tldr-pages cache.
Links share/tldr/dotfiles.page.md into ~/.local/share/tealdeer/pages/.
Needs curl, jq, sudo.

Invoked by ./devbox.sh --tldr / --all and ./desktop.sh --tldr / --all.

Options:
  --uninstall  Remove tldr binary, cache, config, and custom pages
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help

Re-run anytime to upgrade the client or refresh pages.
EOF
}

# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"

uninstall_tldr() {
  df_inst_remove_github_binary tldr "$BIN_PATH"
  df_inst_remove_tealdeer_data
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall tldr uninstall_tldr; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="tealdeer-rs/tealdeer"

gr_require_cmds curl jq

tealdeer_asset_name() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "tealdeer-linux-x86_64-musl" ;;
    aarch64 | arm64) echo "tealdeer-linux-aarch64-musl" ;;
    armv7l) echo "tealdeer-linux-armv7-musleabihf" ;;
    armv6l) echo "tealdeer-linux-arm-musleabihf" ;;
    i686 | i386) echo "tealdeer-linux-i686-musl" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

tealdeer_verify_sha256() {
  local file="$1"
  local hash_url="$2"
  local expected actual

  expected="$(gr_curl -fsSL "$hash_url" | awk '{print $1}')"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "ERROR: could not read SHA256 from $hash_url" >&2
    exit 1
  }
  actual="$(gr_sha256_file "$file" || true)"
  if [[ -z "$actual" ]]; then
    echo "ERROR: cannot compute SHA256 (need sha256sum or shasum)" >&2
    exit 1
  fi
  if [[ "${actual,,}" != "${expected,,}" ]]; then
    echo "ERROR: SHA256 mismatch for $(basename "$file")" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
  echo "SHA256 ok: $(basename "$file")"
}

tealdeer_update_pages() {
  if [[ ! -x "$BIN_PATH" ]]; then
    return 0
  fi
  echo "Updating tldr pages cache..."
  if "$BIN_PATH" --update; then
    :
  else
    echo "WARN: tldr --update failed (offline or GitHub); client is still installed" >&2
  fi
}

tealdeer_install_dotfiles_page() {
  local dest dir

  [[ -f "$TLDR_PAGE_SRC" ]] || {
    echo "WARN: missing dotfiles tldr page: $TLDR_PAGE_SRC" >&2
    return 0
  }

  dest="${XDG_DATA_HOME:-$HOME/.local/share}/tealdeer/pages/dotfiles.page.md"
  dir="$(dirname "$dest")"
  mkdir -p "$dir"
  ln -sfn "$TLDR_PAGE_SRC" "$dest"
  # shellcheck source=lib/journal.sh
  source "$SCRIPT_DIR/lib/journal.sh"
  df_journal_once link "$dest" "$TLDR_PAGE_SRC"
  echo "Dotfiles tldr page: $dest"
}

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest tealdeer release tag" >&2
  exit 1
}

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  tealdeer_update_pages
  tealdeer_install_dotfiles_page
  echo "Done."
  echo "tldr path: $(command -v tldr || true)"
  gr_print_version_line tldr
  exit 0
fi

asset="$(tealdeer_asset_name)"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
hash_url="${url}.sha256"

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT
binary="${tmpdir}/${asset}"

if ! gr_download "$url" "$binary"; then
  gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
  exit 1
fi

if ! gr_file_is_elf "$binary"; then
  echo "ERROR: refusing to install non-ELF $binary as $BIN_PATH" >&2
  exit 1
fi

tealdeer_verify_sha256 "$binary" "$hash_url"

sudo_cmd="$(gr_sudo)"
gr_install_binary "$binary" "$BIN_PATH" "$sudo_cmd"

tealdeer_update_pages
tealdeer_install_dotfiles_page

echo "Done."
echo "tldr path: $(command -v tldr || true)"
gr_print_version_line tldr
