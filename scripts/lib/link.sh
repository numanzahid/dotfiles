#!/usr/bin/env bash
# Shared symlink helpers for install.sh and LazyVim scripts.

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
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]] || df_paths_same "$dest" "$src"; then
      log "already linked: $dest"
      return 0
    fi
    log "replace symlink: $dest -> $src"
    run ln -sfn "$src" "$dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    local backup="${dest}.pre-dotfiles-$(date +%Y%m%d%H%M%S)"
    log "backup existing: $dest -> $backup"
    run mv "$dest" "$backup"
  fi

  log "link: $dest -> $src"
  run ln -sfn "$src" "$dest"
}
