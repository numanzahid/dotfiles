#!/usr/bin/env bash
# Shared symlink helpers for install.sh and LazyVim scripts.

# Keep at most two .pre-dotfiles-* backups for a linked or copied path.
df_prune_pre_dotfiles_backups() {
  local dest="$1"
  local keep=2
  local f extra i
  local nullglob_on=0
  local -a backups=()
  local -a ordered=()

  # shopt -p returns 1 when the option is off, which aborts under set -e.
  if shopt -q nullglob; then
    nullglob_on=1
  fi
  shopt -s nullglob
  backups=("${dest}".pre-dotfiles-*)
  if [[ "$nullglob_on" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if ((${#backups[@]} <= keep)); then
    return 0
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] && ordered+=("$f")
  done < <(printf '%s\n' "${backups[@]}" | sort)

  extra=$((${#ordered[@]} - keep))
  i=0
  while ((i < extra)); do
    log "removed old backup: ${ordered[i]}"
    run rm -rf "${ordered[i]}"
    i=$((i + 1))
  done
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
    df_prune_pre_dotfiles_backups "$dest"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]] || df_paths_same "$dest" "$src"; then
      log "already linked: $dest"
      df_prune_pre_dotfiles_backups "$dest"
      return 0
    fi
    log "replace symlink: $dest -> $src"
    run ln -sfn "$src" "$dest"
    df_prune_pre_dotfiles_backups "$dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    local backup="${dest}.pre-dotfiles-$(date +%Y%m%d%H%M%S)"
    log "backup existing: $dest -> $backup"
    run mv "$dest" "$backup"
  fi

  log "link: $dest -> $src"
  run ln -sfn "$src" "$dest"
  df_prune_pre_dotfiles_backups "$dest"
}
