#!/usr/bin/env bash
set -euo pipefail

# Install/update tmux plugin manager (tpm) from GitHub, pinned to the latest
# tagged release (auto-resolved each run) rather than tracking master HEAD.
# tpm has no GitHub Releases, only git tags, so this resolves the newest tag
# via the /tags API instead of /releases/latest.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${HOME:?}"
REPO="tmux-plugins/tpm"

usage() {
  cat <<'EOF'
Usage: ./scripts/tpm-install-update.sh [options]

Clone/update tmux-plugins/tpm into ~/.tmux/plugins/tpm, pinned to the latest
release tag (resolved from GitHub each run, not master HEAD).
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
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"

git_github() {
  git -c http.version=HTTP/1.1 "$@"
}

uninstall_tpm() {
  df_inst_remove_tpm
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
DRY_RUN="${DF_INSTALL_DRY_RUN:-0}"
case "$_df_entry" in
  1) df_inst_run_uninstall tpm uninstall_tpm; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

resolve_tpm_tag() {
  local tag
  tag="$(gr_latest_git_tag "$REPO" || true)"
  if [[ -z "$tag" || "$tag" == "null" ]]; then
    echo "WARN: could not resolve latest tpm tag from GitHub; falling back to master" >&2
    tag="master"
  fi
  printf '%s' "$tag"
}

tpm_dir="$TARGET_HOME/.tmux/plugins/tpm"
tag="$(resolve_tpm_tag)"

if [[ -d "$tpm_dir/.git" ]]; then
  current="$(git -C "$tpm_dir" describe --tags --exact-match 2>/dev/null || true)"
  if [[ "$current" == "$tag" ]]; then
    echo "tpm already at latest tag: $tag ($tpm_dir)"
  elif [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ update tpm $tpm_dir -> $tag (currently: ${current:-master HEAD})"
  else
    echo "Updating tpm $tpm_dir -> $tag (currently: ${current:-master HEAD})"
    git_github -C "$tpm_dir" fetch --depth 1 origin "tag" "$tag"
    git_github -C "$tpm_dir" checkout --detach "$tag"
  fi
else
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ git clone --branch $tag --depth 1 https://github.com/${REPO} $tpm_dir"
  else
    echo "Installing tmux plugin manager ($tag)..."
    mkdir -p "$TARGET_HOME/.tmux/plugins"
    git_github clone -4 --branch "$tag" --depth 1 "https://github.com/${REPO}" "$tpm_dir"
  fi
fi

if [[ "${DRY_RUN:-0}" -ne 1 ]]; then
  df_journal_once git-clone "$tpm_dir"
fi
echo "Done."
echo "tpm path: $tpm_dir"
