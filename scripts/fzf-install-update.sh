#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fzf from GitHub release binaries (junegunn/fzf).
# Re-run anytime to upgrade.
#
# Uses the same checksummed-download path as the other GitHub-release tools
# (see scripts/lib/github-release.sh) instead of cloning the repo and running
# its install script: no unpinned git HEAD, no unreviewed shell script
# executed as the invoking user.
#
# Shell integration (key bindings + completion) comes from `fzf --bash`,
# wired in home/.shell_aliases_interactive.sh — no ~/.fzf.bash file needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME:?}"
BIN_PATH="${TARGET_HOME}/.local/bin/fzf"
REPO="junegunn/fzf"

usage() {
  cat <<'EOF'
Usage: ./scripts/fzf-install-update.sh [options]

Install or upgrade fzf from official GitHub release binaries into
~/.local/bin. Shell integration is provided by `fzf --bash` (see
home/.shell_aliases_interactive.sh), no ~/.fzf.bash file is written.

On Fedora desktop, dnf fzf is used instead (see desktop.sh).

Options:
  --uninstall  Remove ~/.local/bin/fzf, legacy ~/.fzf*, and journaled fzf package
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help
EOF
}

# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"

df_prepend_local_bin

uninstall_fzf() {
  df_inst_remove_fzf
  # Legacy layout from the old git-clone installer, if still present.
  if [[ -d "$TARGET_HOME/.fzf" ]]; then
    rm -rf "$TARGET_HOME/.fzf"
  fi
  if [[ -f "$TARGET_HOME/.fzf.bash" && ! -L "$TARGET_HOME/.fzf.bash" ]]; then
    rm -f "$TARGET_HOME/.fzf.bash"
  fi
  if [[ -f "$BIN_PATH" ]]; then
    rm -f "$BIN_PATH"
  fi
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
DRY_RUN="${DF_INSTALL_DRY_RUN:-0}"
export DRY_RUN
case "$_df_entry" in
  1) df_inst_run_uninstall fzf uninstall_fzf; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

gr_require_cmds curl jq tar

fzf_asset() {
  local tag="$1"
  local ver="${tag#v}"
  local arch raw
  raw="$(gr_arch_raw)" || exit 1
  case "$raw" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    armv7) arch="armv7" ;;
    armv6) arch="armv6" ;;
    *)
      echo "ERROR: unsupported architecture for fzf: $(uname -m)" >&2
      exit 1
      ;;
  esac
  printf 'fzf-%s-linux_%s.tar.gz' "$ver" "$arch"
}

install_fzf() {
  local tag asset url tarball extract_dir binary tmpdir

  tag="$(gr_latest_tag "$REPO" || true)"
  [[ -n "$tag" && "$tag" != "null" ]] || {
    gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
    echo "ERROR: could not resolve latest fzf release tag" >&2
    exit 1
  }

  if gr_bin_has_tag "$BIN_PATH" "$tag"; then
    echo "Already current: $BIN_PATH ($tag)"
    gr_print_version_line fzf
    return 0
  fi

  asset="$(fzf_asset "$tag")"
  url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" EXIT
  tarball="${tmpdir}/${asset}"
  extract_dir="${tmpdir}/extract"

  if ! gr_download "$url" "$tarball"; then
    gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
    echo "ERROR: download failed: $url" >&2
    exit 1
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir"

  binary="$(gr_find_binary "$extract_dir" fzf || true)"
  if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
    echo "ERROR: fzf binary not found in archive" >&2
    exit 1
  fi
  if ! gr_file_is_elf "$binary"; then
    echo "ERROR: refusing to install non-ELF $binary as $BIN_PATH" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$BIN_PATH")"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ install -m 755 $binary $BIN_PATH"
  else
    install -m 755 "$binary" "$BIN_PATH"
    if declare -F df_journal_once >/dev/null 2>&1; then
      df_journal_once binary "$BIN_PATH"
    fi
  fi

  # Legacy layout from the old git-clone installer: drop it so
  # ~/.shell_aliases_interactive.sh falls through to `fzf --bash`.
  if [[ -d "$TARGET_HOME/.fzf" ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      echo "+ rm -rf $TARGET_HOME/.fzf"
    else
      rm -rf "$TARGET_HOME/.fzf"
    fi
  fi
  if [[ -f "$TARGET_HOME/.fzf.bash" && ! -L "$TARGET_HOME/.fzf.bash" ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      echo "+ rm -f $TARGET_HOME/.fzf.bash"
    else
      rm -f "$TARGET_HOME/.fzf.bash"
    fi
  fi
}

install_fzf
echo "Done."
echo "fzf path: $(command -v fzf || true)"
gr_print_version_line fzf
