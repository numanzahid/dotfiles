#!/usr/bin/env bash
set -euo pipefail

# Nerd Fonts into user fonts (latest GitHub release).
#   CascadiaCode.zip  -> CaskaydiaCove
#   JetBrainsMono.zip -> JetBrainsMono
# Re-run to upgrade. Same pattern as the other *-install-update.sh scripts.
#
# Invoked by: ./install.sh --all and ./install-fedora.sh --all
# Re-run:     ./scripts/cascadia-nerd-font-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"

case "$(df_host_os_id)" in
  fedora | ubuntu | debian | linuxmint | pop) ;;
  *)
    echo "ERROR: nerd font install supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

REPO="ryanoasis/nerd-fonts"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
FONT_ROOT="$DATA_HOME/fonts"
STAMP="$DATA_HOME/dotfiles/cascadia-nerd-font.version"

# asset zip -> install directory under FONT_ROOT
FONT_ASSETS=(
  "CascadiaCode.zip:dotfiles-caskaydia-cove"
  "JetBrainsMono.zip:dotfiles-jetbrains-mono"
)

font_dir_has_files() {
  local dir="$1" f
  shopt -s nullglob
  for f in "$dir"/*.ttf "$dir"/*.otf; do
    [[ -f "$f" ]] || continue
    shopt -u nullglob
    return 0
  done
  shopt -u nullglob
  return 1
}

all_font_dirs_present() {
  local spec asset dest
  for spec in "${FONT_ASSETS[@]}"; do
    dest="$FONT_ROOT/${spec#*:}"
    font_dir_has_files "$dest" || return 1
  done
  return 0
}

any_font_dir_present() {
  local spec dest
  for spec in "${FONT_ASSETS[@]}"; do
    dest="$FONT_ROOT/${spec#*:}"
    if font_dir_has_files "$dest"; then
      return 0
    fi
  done
  return 1
}

keep_existing() {
  local why="$1"
  if any_font_dir_present; then
    echo "WARN: ${why}; keeping existing nerd fonts under $FONT_ROOT" >&2
    if command -v fc-cache >/dev/null 2>&1; then
      fc-cache -f "$FONT_ROOT"
    fi
    echo "Done."
    return 0
  fi
  return 1
}

install_one_zip() {
  local tag="$1"
  local asset="$2"
  local dest_dir="$3"
  local url zipfile extract_dir new_dir copied=0 f

  url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
  zipfile="${tmpdir}/${asset}"
  extract_dir="${tmpdir}/extract-${asset}"
  new_dir="${tmpdir}/fonts-${asset}"
  mkdir -p "$extract_dir" "$new_dir"

  if ! gr_download "$url" "$zipfile"; then
    echo "ERROR: download failed: $url" >&2
    return 1
  fi
  unzip -q -o "$zipfile" -d "$extract_dir"

  while IFS= read -r -d '' f; do
    cp -f "$f" "$new_dir/"
    copied=$((copied + 1))
  done < <(find "$extract_dir" -type f \( -name '*.ttf' -o -name '*.otf' \) -print0)

  if [[ "$copied" -lt 1 ]]; then
    echo "ERROR: no .ttf/.otf files in $asset" >&2
    return 1
  fi

  mkdir -p "$dest_dir"
  find "$dest_dir" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -delete 2>/dev/null || true
  cp -f "$new_dir"/*.ttf "$dest_dir/" 2>/dev/null || true
  cp -f "$new_dir"/*.otf "$dest_dir/" 2>/dev/null || true

  if declare -F gr_track_path >/dev/null 2>&1; then
    gr_track_path "$dest_dir"
  fi
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once copy "$dest_dir" "$url"
  fi

  echo "$asset: $copied files -> $dest_dir"
}

gr_require_cmds curl jq unzip fc-cache

tag="$(gr_latest_tag "$REPO" || true)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  keep_existing "could not resolve latest ${REPO} tag" || {
    echo "ERROR: could not resolve latest nerd-fonts release tag" >&2
    exit 1
  }
  exit 0
fi

if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$tag" ]] && all_font_dirs_present; then
  echo "Already current: Nerd Fonts $tag (Cascadia Code + JetBrains Mono)"
  fc-cache -f "$FONT_ROOT"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

failed=0
for spec in "${FONT_ASSETS[@]}"; do
  asset="${spec%%:*}"
  dest="$FONT_ROOT/${spec#*:}"
  if ! install_one_zip "$tag" "$asset" "$dest"; then
    if font_dir_has_files "$dest"; then
      echo "WARN: keeping existing $dest" >&2
    else
      failed=1
    fi
  fi
done

if [[ "$failed" -eq 1 ]] && ! any_font_dir_present; then
  echo "ERROR: no nerd fonts installed" >&2
  exit 1
fi

if all_font_dirs_present; then
  mkdir -p "$(dirname "$STAMP")"
  printf '%s\n' "$tag" >"$STAMP"
  if declare -F gr_track_path >/dev/null 2>&1; then
    gr_track_path "$STAMP"
  fi
fi

fc-cache -f "$FONT_ROOT"

echo "Done."
echo "Nerd Fonts $tag under $FONT_ROOT"
echo "fc-cache refreshed: $FONT_ROOT"
