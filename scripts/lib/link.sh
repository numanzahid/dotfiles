#!/usr/bin/env bash
# Shared symlink/copy helpers for install.sh, install-copy, and LazyVim scripts.

# One original backup per path: dest.pre-dotfiles (no timestamp).
# Paths we have installed are tracked in ~/.local/share/dotfiles/managed-paths
# so later edits are still treated as ours (overwrite, do not re-backup).
# Re-runs overwrite managed files. Timestamped leftovers are dropped.

df_managed_paths_file() {
  printf '%s/dotfiles/managed-paths' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

df_path_is_tracked() {
  local dest="$1"
  local file
  file="$(df_managed_paths_file)"
  [[ -f "$file" ]] || return 1
  grep -Fxq -- "$dest" "$file"
}

df_track_path() {
  local dest="$1"
  local file dir
  file="$(df_managed_paths_file)"
  dir="$(dirname "$file")"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi
  if df_path_is_tracked "$dest"; then
    return 0
  fi
  mkdir -p "$dir"
  printf '%s\n' "$dest" >> "$file"
}

df_original_backup_path() {
  printf '%s.pre-dotfiles' "$1"
}

df_list_timestamped_backups() {
  local dest="$1"
  local nullglob_on=0
  local -a found=()

  if shopt -q nullglob; then
    nullglob_on=1
  fi
  shopt -s nullglob
  found=("${dest}".pre-dotfiles-*)
  if [[ "$nullglob_on" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if ((${#found[@]} > 0)); then
    printf '%s\n' "${found[@]}"
  fi
}

# Keep dest.pre-dotfiles as the original. Promote the oldest timestamped
# backup if that file is missing, then delete dest.pre-dotfiles-*.
df_migrate_original_backup() {
  local dest="$1"
  local backup
  local f oldest=""
  local -a stamped=()

  backup="$(df_original_backup_path "$dest")"

  while IFS= read -r f; do
    [[ -n "$f" ]] && stamped+=("$f")
  done < <(df_list_timestamped_backups "$dest" | sort)

  if [[ -e "$backup" || -L "$backup" ]]; then
    if ((${#stamped[@]} > 0)); then
      for f in "${stamped[@]}"; do
        log "removed extra backup: $f"
        run rm -rf "$f"
      done
    fi
    return 0
  fi

  if ((${#stamped[@]} == 0)); then
    return 0
  fi

  oldest="${stamped[0]}"
  log "keeping original backup: $oldest -> $backup"
  run mv "$oldest" "$backup"
  for f in "${stamped[@]}"; do
    if [[ "$f" == "$oldest" ]]; then
      continue
    fi
    if [[ -e "$f" || -L "$f" ]]; then
      log "removed extra backup: $f"
      run rm -rf "$f"
    fi
  done
}

# Back-compat name used by install-copy.
df_prune_pre_dotfiles_backups() {
  df_migrate_original_backup "$1"
}

df_same_file() {
  local left="$1"
  local right="$2"
  [[ -f "$left" && -f "$right" ]] && cmp -s "$left" "$right"
}

# True when dest is already a copy of src (file, or nvim dir via init.lua).
df_is_managed_copy() {
  local src="$1"
  local dest="$2"

  if df_same_file "$src" "$dest"; then
    return 0
  fi
  if [[ -d "$src" && -d "$dest" ]] && df_same_file "$src/init.lua" "$dest/init.lua"; then
    return 0
  fi
  return 1
}

# Save dest once as dest.pre-dotfiles if it is a foreign original.
# Tracked paths and exact copies are ours, including user-edited copies.
df_stash_original_if_needed() {
  local src="${1:-}"
  local dest="$2"
  local backup

  backup="$(df_original_backup_path "$dest")"
  df_migrate_original_backup "$dest"

  if [[ -L "$dest" ]]; then
    return 0
  fi
  if [[ ! -e "$dest" ]]; then
    return 0
  fi
  if df_path_is_tracked "$dest"; then
    return 0
  fi
  if [[ -e "$backup" || -L "$backup" ]]; then
    df_track_path "$dest"
    return 0
  fi
  if [[ -n "$src" ]] && df_is_managed_copy "$src" "$dest"; then
    df_track_path "$dest"
    return 0
  fi

  log "backup original: $dest -> $backup"
  run mv "$dest" "$backup"
}

df_path_real() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    readlink -f "$path"
  else
    printf '%s\n' "$path"
  fi
}

df_paths_same() {
  local left="$1"
  local right="$2"
  [[ "$(df_path_real "$left")" == "$(df_path_real "$right")" ]]
}

df_link_path() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi

  if [[ "$dest" == "$src" ]] || df_paths_same "$dest" "$src"; then
    log "already linked: $dest"
    df_migrate_original_backup "$dest"
    df_track_path "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]] || df_paths_same "$dest" "$src"; then
      log "already linked: $dest"
      df_migrate_original_backup "$dest"
      df_track_path "$dest"
      return 0
    fi
    log "replace symlink: $dest -> $src"
    run ln -sfn "$src" "$dest"
    df_migrate_original_backup "$dest"
    df_track_path "$dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    df_stash_original_if_needed "$src" "$dest"
    if [[ -e "$dest" || -L "$dest" ]]; then
      run rm -rf "$dest"
    fi
  fi

  log "link: $dest -> $src"
  run ln -sfn "$src" "$dest"
  df_migrate_original_backup "$dest"
  df_track_path "$dest"
}
