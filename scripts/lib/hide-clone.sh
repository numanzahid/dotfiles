#!/usr/bin/env bash
# If the clone directory is named "dotfiles", rename it to ".dotfiles"
# (same parent) and re-exec the installer from the new path so symlink
# sources are correct in this same run.
#
# No-op when already named .dotfiles, named something else, --dry-run,
# or --help. Does not touch ~/.config/dotfiles.

# shellcheck source=journal.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/journal.sh"

df_reexec_from_hidden_clone() {
  local clone_dir="$1"
  local script_path="$2"
  shift 2
  local parent base dest rel arg real_src real_dst script_dir script_abs

  parent="$(cd "$(dirname "$clone_dir")" && pwd)"
  base="$(basename "$clone_dir")"

  [[ "$base" == ".dotfiles" ]] && return 0
  [[ "$base" == "dotfiles" ]] || return 0

  for arg in "$@"; do
    case "$arg" in
      --dry-run | -h | --help) return 0 ;;
    esac
  done

  dest="$parent/.dotfiles"

  if [[ -e "$dest" || -L "$dest" ]]; then
    real_src="$(readlink -f "$clone_dir" 2>/dev/null || printf '%s' "$clone_dir")"
    real_dst="$(readlink -f "$dest" 2>/dev/null || printf '%s' "$dest")"
    if [[ "$real_src" == "$real_dst" ]]; then
      return 0
    fi
    echo "ERROR: $dest already exists and is not this clone." >&2
    echo "Move or remove it, then re-run." >&2
    exit 1
  fi

  # Resolve to a path inside the clone before mv. `./install.sh` from
  # install-copy/ must re-exec install-copy/install.sh, not root install.sh.
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  script_abs="$script_dir/$(basename "$script_path")"
  rel="${script_abs#"$clone_dir"/}"
  if [[ "$rel" == "$script_abs" || -z "$rel" ]]; then
    echo "ERROR: installer is not inside the clone: $script_abs" >&2
    exit 1
  fi

  printf '[dotfiles] hiding clone: %s -> %s\n' "$clone_dir" "$dest"
  printf '[dotfiles] re-running %s from %s\n' "$rel" "$dest"
  printf '[dotfiles] in this shell: cd %s\n' "$dest"
  df_journal_once hide-clone "$clone_dir" "$dest"
  mv "$clone_dir" "$dest"
  exec bash "$dest/$rel" "$@"
}
