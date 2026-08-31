#!/usr/bin/env bash
# If the clone directory is named "dotfiles", rename it to ".dotfiles"
# (same parent) and re-exec the installer from the new path so symlink
# sources are correct in this same run.
#
# No-op when already named .dotfiles, named something else, --dry-run,
# or --help. Does not touch ~/.config/dotfiles.

df_reexec_from_hidden_clone() {
  local clone_dir="$1"
  local script_path="$2"
  shift 2
  local parent base dest rel arg real_src real_dst

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

  if [[ "$script_path" == /* ]]; then
    rel="${script_path#"$clone_dir"/}"
    if [[ "$rel" == "$script_path" ]]; then
      rel="$(basename "$script_path")"
    fi
  else
    rel="${script_path#./}"
  fi

  printf '[dotfiles] hiding clone: %s -> %s\n' "$clone_dir" "$dest"
  printf '[dotfiles] re-running from the new path. In this shell: cd %s\n' "$dest"
  mv "$clone_dir" "$dest"
  exec bash "$dest/$rel" "$@"
}
