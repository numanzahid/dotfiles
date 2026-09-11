#!/usr/bin/env bash
# Original-file backups for link/copy install. Lives outside the clone when dest
# resolves inside ~/.dotfiles so git status stays clean on devbox/desktop.

df_backups_dir() {
  printf '%s/dotfiles/backups' "${XDG_DATA_HOME:-${TARGET_HOME:-$HOME}/.local/share}"
}

df_dotfiles_clone_dir() {
  local d
  d="$(readlink -f "${DOTFILES_DIR:-${TARGET_HOME:-$HOME}/.dotfiles}" 2>/dev/null || true)"
  if [[ -n "$d" && -d "$d" ]]; then
    printf '%s' "$d"
  fi
}

df_path_inside_dotfiles_clone() {
  local path="$1" clone real
  [[ -n "$path" ]] || return 1
  clone="$(df_dotfiles_clone_dir)"
  [[ -n "$clone" ]] || return 1
  real="$(readlink -f "$path" 2>/dev/null || true)"
  [[ -n "$real" ]] || return 1
  [[ "$real" == "$clone" || "$real" == "$clone"/* ]]
}

df_legacy_original_backup_path() {
  printf '%s.pre-dotfiles' "$1"
}

df_external_backup_path() {
  local dest="$1"
  local home="${TARGET_HOME:-$HOME}"
  local clone real rel

  real="$(readlink -f "$dest" 2>/dev/null || true)"
  [[ -n "$real" ]] || real="$dest"
  clone="$(df_dotfiles_clone_dir)"

  if [[ -n "$clone" && "$real" == "$clone/home/"* ]]; then
    rel="${real#"$clone/home/"}"
    printf '%s/%s.pre-dotfiles' "$(df_backups_dir)" "$rel"
    return 0
  fi

  if [[ "$real" == "$home"/* ]]; then
    rel="${real#"$home"/}"
  elif [[ "$real" == "$home" ]]; then
    rel="_HOME_"
  else
    rel="_abs_$(printf '%s' "${real#/}" | tr '/' '_')"
  fi
  printf '%s/%s.pre-dotfiles' "$(df_backups_dir)" "$rel"
}

df_original_backup_path() {
  local dest="$1"
  if df_path_inside_dotfiles_clone "$dest"; then
    df_external_backup_path "$dest"
  else
    df_legacy_original_backup_path "$dest"
  fi
}

df_backup_exists_for_dest() {
  local dest="$1" b
  b="$(df_original_backup_path "$dest")"
  [[ -e "$b" || -L "$b" ]] && return 0
  b="$(df_legacy_original_backup_path "$dest")"
  [[ -e "$b" || -L "$b" ]]
}

df_resolve_original_backup() {
  local dest="$1" b
  b="$(df_original_backup_path "$dest")"
  if [[ -e "$b" || -L "$b" ]]; then
    printf '%s' "$b"
    return 0
  fi
  b="$(df_legacy_original_backup_path "$dest")"
  if [[ -e "$b" || -L "$b" ]]; then
    printf '%s' "$b"
    return 0
  fi
  printf '%s' "$(df_original_backup_path "$dest")"
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

# Keep one original backup per dest. Promote the oldest timestamped backup if needed.
df_migrate_original_backup() {
  local dest="$1"
  local backup legacy f oldest=""
  local -a stamped=()

  legacy="$(df_legacy_original_backup_path "$dest")"
  backup="$(df_original_backup_path "$dest")"

  if [[ "$backup" != "$legacy" ]] && { [[ -e "$legacy" ]] || [[ -L "$legacy" ]]; }; then
    mkdir -p "$(dirname "$backup")"
    log "relocate backup out of clone: $legacy -> $backup"
    run mv "$legacy" "$backup"
  fi

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
  mkdir -p "$(dirname "$backup")"
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

# Back-compat name used by server.
df_prune_pre_dotfiles_backups() {
  df_migrate_original_backup "$1"
}

# Move legacy *.pre-dotfiles files that landed inside the clone (old installs).
df_relocate_stray_clone_backups() {
  local clone="${1-}"
  local f rel target

  clone="${clone:-$(df_dotfiles_clone_dir)}"
  [[ -n "$clone" && -d "$clone" ]] || return 0

  while IFS= read -r -d '' f; do
    if [[ "$f" == "$clone/home/"* ]]; then
      rel="${f#"$clone/home/"}"
      target="$(df_backups_dir)/$rel"
    elif [[ "$f" == "$clone/"* ]]; then
      rel="${f#"$clone/"}"
      target="$(df_backups_dir)/_from-clone/$rel"
    else
      continue
    fi
    if [[ -e "$target" || -L "$target" ]]; then
      log "removed duplicate clone backup: $f"
      run rm -f "$f"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    log "relocate stray clone backup: $f -> $target"
    run mv "$f" "$target"
  done < <(find "$clone" \( -name '*.pre-dotfiles' -o -name '*.pre-dotfiles-*' \) -print0 2>/dev/null)
}
