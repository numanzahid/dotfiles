#!/usr/bin/env bash
# Shared symlink/copy helpers for devbox.sh, server/, and LazyVim scripts.

# One original backup per path. Inside the clone, backups go to
# ~/.local/share/dotfiles/backups/ (see backup.sh). Else dest.pre-dotfiles.
# Paths we have installed are tracked in ~/.local/share/dotfiles/managed-paths
# so later edits are still treated as ours (overwrite, do not re-backup).
# Re-runs overwrite managed files. Timestamped leftovers are dropped.
# Actions are also appended to ~/.local/share/dotfiles/install-journal.tsv.

# shellcheck source=journal.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/journal.sh"
# shellcheck source=backup.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup.sh"

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

# Save dest once as a pre-dotfiles backup if it is a foreign original.
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
  if df_backup_exists_for_dest "$dest"; then
    df_track_path "$dest"
    return 0
  fi
  if [[ -n "$src" ]] && df_is_managed_copy "$src" "$dest"; then
    df_track_path "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$backup")"
  log "backup original: $dest -> $backup"
  run mv "$dest" "$backup"
  df_journal_once backup "$dest" "$backup"
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
    df_journal_once link "$dest" "$src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]] || df_paths_same "$dest" "$src"; then
      log "already linked: $dest"
      df_migrate_original_backup "$dest"
      df_track_path "$dest"
      df_journal_once link "$dest" "$src"
      return 0
    fi
    log "replace symlink: $dest -> $src"
    run ln -sfn "$src" "$dest"
    df_migrate_original_backup "$dest"
    df_track_path "$dest"
    df_journal_once link "$dest" "$src"
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
  df_journal_once link "$dest" "$src"
}
