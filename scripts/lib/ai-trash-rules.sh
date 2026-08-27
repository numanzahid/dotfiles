#!/usr/bin/env bash
# Copy trash-cli agent instructions as real files (not symlinks).
# Used by install.sh and install-ai-cli.sh.
# Requires: SOURCE_DIR, log, run, and link.sh helpers.

df_ai_trash_rule_src() {
  printf '%s/.config/dotfiles/use-trash-cli.md' "$SOURCE_DIR"
}

df_ai_trash_cursor_src() {
  printf '%s/.cursor/rules/use-trash-cli.mdc' "$SOURCE_DIR"
}

df_ai_trash_block() {
  local body="$1"
  printf '%s\n' "<!-- dotfiles-trash-cli -->"
  cat "$body"
  printf '\n%s\n' "<!-- /dotfiles-trash-cli -->"
}

df_ai_trash_materialize() {
  local dest="$1"
  local tmp

  if [[ ! -L "$dest" ]]; then
    return 0
  fi
  tmp="$(mktemp)"
  cat "$dest" > "$tmp"
  run rm -f "$dest"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    rm -f "$tmp"
    return 0
  fi
  mv "$tmp" "$dest"
}

df_ai_trash_upsert() {
  local dest="$1"
  local body="$2"
  local tmp_block tmp_out
  local start="<!-- dotfiles-trash-cli -->"
  local end="<!-- /dotfiles-trash-cli -->"

  mkdir -p "$(dirname "$dest")"
  df_ai_trash_materialize "$dest"

  tmp_block="$(mktemp)"
  tmp_out="$(mktemp)"
  df_ai_trash_block "$body" > "$tmp_block"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log "would update trash-cli rule in $dest"
    rm -f "$tmp_block" "$tmp_out"
    return 0
  fi

  if [[ -f "$dest" ]] && grep -Fq "$start" "$dest"; then
    awk -v start="$start" -v end="$end" '
      $0 == start { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$dest" > "$tmp_out"
    printf '\n' >> "$tmp_out"
    cat "$tmp_block" >> "$tmp_out"
    mv "$tmp_out" "$dest"
  elif [[ -f "$dest" ]]; then
    printf '\n' >> "$dest"
    cat "$tmp_block" >> "$dest"
    rm -f "$tmp_out"
  else
    cat "$tmp_block" > "$dest"
    rm -f "$tmp_out"
  fi
  rm -f "$tmp_block"
  log "copied: $dest"
}

df_copy_ai_trash_rules() {
  local home="${TARGET_HOME:-$HOME}"
  local md src_mdc dest_mdc

  md="$(df_ai_trash_rule_src)"
  src_mdc="$(df_ai_trash_cursor_src)"
  dest_mdc="$home/.cursor/rules/use-trash-cli.mdc"

  if [[ ! -f "$md" || ! -f "$src_mdc" ]]; then
    log "skip AI trash-cli rules (missing source files)"
    return 0
  fi

  mkdir -p "$(dirname "$dest_mdc")"
  if [[ -L "$dest_mdc" ]]; then
    log "replace symlink with file: $dest_mdc"
    run rm -f "$dest_mdc"
  else
    df_stash_original_if_needed "$src_mdc" "$dest_mdc"
  fi
  run cp -f "$src_mdc" "$dest_mdc"
  df_track_path "$dest_mdc"
  log "copied: $dest_mdc"

  df_ai_trash_upsert "$home/.codex/AGENTS.md" "$md"
  df_ai_trash_upsert "$home/.claude/CLAUDE.md" "$md"
}
