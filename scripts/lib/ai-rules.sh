#!/usr/bin/env bash
# Install dotfiles AI agent rules.
# Cursor .mdc files are the master source. Claude gets one .md per rule.
# Codex gets one AGENTS.md (API limitation). Used by install-ai-rules.sh.
# Requires: SOURCE_DIR, log, run, and link.sh helpers.

df_ai_rules_root() {
  printf '%s/.config/dotfiles/ai-rules' "$SOURCE_DIR"
}

df_ai_rules_cursor_src_dir() {
  printf '%s/cursor' "$(df_ai_rules_root)"
}

df_ai_rules_cursor_dest_dir() {
  local home="${TARGET_HOME:-$HOME}"
  printf '%s/.cursor/rules' "$home"
}

df_ai_rules_claude_rules_dir() {
  local home="${TARGET_HOME:-$HOME}"
  printf '%s/.claude/rules' "$home"
}

df_ai_rules_claude_dest() {
  local home="${TARGET_HOME:-$HOME}"
  printf '%s/.claude/CLAUDE.md' "$home"
}

df_ai_rules_codex_dest() {
  local home="${TARGET_HOME:-$HOME}"
  printf '%s/.codex/AGENTS.md' "$home"
}

df_ai_rules_basename_list() {
  local f names=""
  for f in "$@"; do
    names+="$(basename "$f") "
  done
  printf '%s' "${names% }"
}

df_ai_rules_markdown_name() {
  local mdc="$1"
  printf '%s.md' "$(basename "$mdc" .mdc)"
}

# Strip optional YAML frontmatter from a .mdc file; print body to stdout.
df_ai_rules_mdc_body() {
  awk '
    BEGIN { in_front = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (!seen) {
        seen = 1
        in_front = 1
        next
      }
      if (in_front) {
        in_front = 0
        next
      }
    }
    !in_front { print }
  ' "$1"
}

df_ai_rules_is_dotfiles_managed_link() {
  local path="$1"
  local target root

  [[ -L "$path" ]] || return 1
  target="$(readlink -f "$path" 2>/dev/null || true)"
  root="$(readlink -f "$(df_ai_rules_cursor_src_dir)" 2>/dev/null || true)"
  [[ -n "$target" && -n "$root" ]] || return 1
  case "$target" in
    "$root"/*) return 0 ;;
  esac
  return 1
}

# Repo cursor/*.mdc first, then custom ~/.cursor/rules/*.mdc (non-dotfiles files).
df_ai_rules_collect_mdc_sources() {
  local src_dir dest_dir f base
  local -A repo_names=()

  src_dir="$(df_ai_rules_cursor_src_dir)"
  dest_dir="$(df_ai_rules_cursor_dest_dir)"

  shopt -s nullglob
  local -a repo_files=("$src_dir"/*.mdc)
  shopt -u nullglob

  for f in $(printf '%s\n' "${repo_files[@]}" | LC_ALL=C sort); do
    repo_names["$(basename "$f")"]=1
    printf '%s\n' "$f"
  done

  if [[ ! -d "$dest_dir" ]]; then
    return 0
  fi

  shopt -s nullglob
  local -a dest_files=("$dest_dir"/*.mdc)
  shopt -u nullglob

  for f in $(printf '%s\n' "${dest_files[@]}" | LC_ALL=C sort); do
    df_ai_rules_is_dotfiles_managed_link "$f" && continue
    base="$(basename "$f")"
    [[ -n "${repo_names[$base]:-}" ]] && continue
    printf '%s\n' "$f"
  done
}

df_ai_rules_link_cursor_file() {
  local src="$1"
  local dest="$2"

  if [[ ! -f "$src" ]]; then
    log "skip missing rule source: $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  df_link_path "$src" "$dest"
}

df_ai_rules_ensure_cursor_links() {
  local src_dir dest_dir src dest

  src_dir="$(df_ai_rules_cursor_src_dir)"
  dest_dir="$(df_ai_rules_cursor_dest_dir)"

  if [[ ! -d "$src_dir" ]]; then
    log "skip cursor rules (missing $src_dir)"
    return 0
  fi

  mkdir -p "$dest_dir"

  shopt -s nullglob
  local -a files=("$src_dir"/*.mdc)
  shopt -u nullglob

  if ((${#files[@]} == 0)); then
    log "skip cursor rules (no .mdc files in repo)"
    return 0
  fi

  for src in "${files[@]}"; do
    dest="$dest_dir/$(basename "$src")"
    df_ai_rules_link_cursor_file "$src" "$dest"
  done
}

df_ai_rules_write_generated_copy() {
  local src_mdc="$1"
  local dest="$2"
  local tmp

  if [[ ! -f "$src_mdc" ]]; then
    log "skip missing rule source: $src_mdc"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"
  df_ai_rules_mdc_body "$src_mdc" >"$tmp"

  if [[ ! -s "$tmp" ]]; then
    log "skip empty rule body: $src_mdc"
    rm -f "$tmp"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log "would write: $dest"
    rm -f "$tmp"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    log "replace symlink with file: $dest"
    run rm -f "$dest"
  else
    df_stash_original_if_needed "$src_mdc" "$dest"
  fi
  run cp -f "$tmp" "$dest"
  rm -f "$tmp"
  df_track_path "$dest"
  df_journal_once copy "$dest" "$src_mdc"
  log "wrote: $dest"
}

df_ai_rules_build_codex_file() {
  local dest="$1"
  local tmp first=1 f
  local -a sources=()

  while IFS= read -r f; do
    [[ -n "$f" ]] && sources+=("$f")
  done < <(df_ai_rules_collect_mdc_sources)

  if ((${#sources[@]} == 0)); then
    log "skip codex rules (no .mdc sources)"
    return 1
  fi

  tmp="$(mktemp)"
  for f in "${sources[@]}"; do
    if [[ "$first" -eq 0 ]]; then
      printf '\n' >>"$tmp"
    fi
    df_ai_rules_mdc_body "$f" >>"$tmp"
    first=0
  done

  mv "$tmp" "$dest"
  return 0
}

df_ai_rules_install_codex() {
  local dest tmp

  df_ai_rules_migrate_legacy
  df_ai_rules_ensure_cursor_links
  dest="$(df_ai_rules_codex_dest)"
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"

  if ! df_ai_rules_build_codex_file "$tmp"; then
    rm -f "$tmp"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log "would write codex rules to $dest"
    rm -f "$tmp"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    log "replace symlink with file: $dest"
    run rm -f "$dest"
  else
    df_stash_original_if_needed "$tmp" "$dest"
  fi
  run cp -f "$tmp" "$dest"
  rm -f "$tmp"
  df_track_path "$dest"
  df_journal_once copy "$dest" "generated-from-cursor-mdc"
  log "wrote: $dest"
}

df_ai_rules_install_claude() {
  local rules_dir mdc dest

  df_ai_rules_migrate_legacy
  df_ai_rules_ensure_cursor_links
  df_ai_rules_remove_managed_claude_monolith
  rules_dir="$(df_ai_rules_claude_rules_dir)"
  mkdir -p "$rules_dir"

  while IFS= read -r mdc; do
    [[ -n "$mdc" ]] || continue
    dest="$rules_dir/$(df_ai_rules_markdown_name "$mdc")"
    df_ai_rules_write_generated_copy "$mdc" "$dest"
  done < <(df_ai_rules_collect_mdc_sources)
}

df_ai_rules_install_cursor() {
  df_ai_rules_migrate_legacy
  df_ai_rules_ensure_cursor_links
}

df_ai_rules_install_all() {
  df_ai_rules_install_cursor
  df_ai_rules_install_codex
  df_ai_rules_install_claude
}

df_ai_rules_install_tool() {
  case "$1" in
    cursor) df_ai_rules_install_cursor ;;
    codex) df_ai_rules_install_codex ;;
    claude) df_ai_rules_install_claude ;;
    *)
      log "unknown AI rules tool: $1"
      return 1
      ;;
  esac
}

df_ai_rules_list_repo() {
  local root="$1"
  local src_dir

  if [[ ! -d "$root" ]]; then
    printf '  (missing %s)\n' "$root"
    return 0
  fi

  src_dir="$root/cursor"
  shopt -s nullglob
  local -a files=("$src_dir"/*.mdc)
  shopt -u nullglob

  if ((${#files[@]} == 0)); then
    printf '  cursor  no .mdc master files\n'
  else
    printf '  cursor  master: %s\n' "$(df_ai_rules_basename_list "${files[@]}")"
  fi
  printf '  codex   one file: ~/.codex/AGENTS.md (merged from all .mdc)\n'
  printf '  claude  one file per rule: ~/.claude/rules/*.md\n'
}

df_ai_rules_dest_status() {
  local home="${TARGET_HOME:-$HOME}"
  local dest_dir rules_dir dest f

  dest_dir="$(df_ai_rules_cursor_dest_dir)"
  if [[ -d "$dest_dir" ]]; then
    shopt -s nullglob
    local -a files=("$dest_dir"/*.mdc)
    shopt -u nullglob
    if ((${#files[@]} == 0)); then
      printf '  %-7s empty %s\n' "cursor" "$dest_dir"
    else
      local listed="" kind
      for f in "${files[@]}"; do
        if df_ai_rules_is_dotfiles_managed_link "$f"; then
          kind="link"
        else
          kind="custom"
        fi
        listed+="$(basename "$f")($kind) "
      done
      printf '  %-7s %s\n' "cursor" "${listed% }"
    fi
  else
    printf '  %-7s missing %s\n' "cursor" "$dest_dir"
  fi

  dest="$(df_ai_rules_codex_dest)"
  if [[ -f "$dest" ]]; then
    printf '  %-7s %s\n' "codex" "$dest"
  else
    printf '  %-7s missing %s\n' "codex" "$dest"
  fi

  rules_dir="$(df_ai_rules_claude_rules_dir)"
  if [[ -d "$rules_dir" ]]; then
    shopt -s nullglob
    local -a files=("$rules_dir"/*.md)
    shopt -u nullglob
    if ((${#files[@]} == 0)); then
      printf '  %-7s empty %s\n' "claude" "$rules_dir"
    else
      printf '  %-7s %s\n' "claude" "$(df_ai_rules_basename_list "${files[@]}")"
    fi
  else
    printf '  %-7s missing %s\n' "claude" "$rules_dir"
  fi

  dest="$(df_ai_rules_claude_dest)"
  if [[ -f "$dest" ]]; then
    printf '  %-7s legacy monolith still present: %s\n' "claude" "$dest"
  fi
}

# Legacy installs patched blocks into agent files; strip on migrate/uninstall.
df_ai_rule_strip_block() {
  local dest="$1"
  local marker="$2"
  local start="<!-- dotfiles-${marker} -->"
  local end="<!-- /dotfiles-${marker} -->"
  local tmp

  if [[ ! -f "$dest" || -L "$dest" ]]; then
    return 0
  fi
  if ! grep -Fq "$start" "$dest"; then
    return 0
  fi

  log "strip legacy ${marker} block: $dest"
  if [[ "${APPLY:-1}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$dest" >"$tmp"
  if grep -q '[^[:space:]]' "$tmp"; then
    mv "$tmp" "$dest"
  else
    rm -f "$tmp" "$dest"
    log "removed empty file after strip: $dest"
  fi
}

df_ai_rules_remove_managed_claude_monolith() {
  local dest

  dest="$(df_ai_rules_claude_dest)"
  [[ -f "$dest" || -L "$dest" ]] || return 0
  if ! df_path_is_tracked "$dest"; then
    return 0
  fi

  log "remove dotfiles-managed CLAUDE.md (rules now in ~/.claude/rules/): $dest"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi
  run rm -f "$dest"
}

df_ai_rules_migrate_legacy() {
  local dest_dir dest f base src_dir
  local -A repo_names=()

  for dest in \
    "$(df_ai_rules_codex_dest)" \
    "$(df_ai_rules_claude_dest)"; do
    df_ai_rule_strip_block "$dest" "trash-cli"
    df_ai_rule_strip_block "$dest" "git"
  done

  src_dir="$(df_ai_rules_cursor_src_dir)"
  dest_dir="$(df_ai_rules_cursor_dest_dir)"
  [[ -d "$src_dir" && -d "$dest_dir" ]] || return 0

  shopt -s nullglob
  local -a repo_files=("$src_dir"/*.mdc)
  shopt -u nullglob

  for src in "${repo_files[@]}"; do
    repo_names["$(basename "$src")"]=1
  done

  for f in "${repo_files[@]}"; do
    base="$(basename "$f")"
    dest="$dest_dir/$base"
    [[ -f "$dest" && ! -L "$dest" ]] || continue
    log "replace copied cursor rule with symlink: $dest"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      continue
    fi
    df_stash_original_if_needed "$f" "$dest"
    run rm -f "$dest"
    df_link_path "$f" "$dest"
  done
}

df_strip_ai_rules() {
  local dest
  for dest in \
    "$TARGET_HOME/.codex/AGENTS.md" \
    "$TARGET_HOME/.claude/CLAUDE.md"; do
    df_ai_rule_strip_block "$dest" "trash-cli"
    df_ai_rule_strip_block "$dest" "git"
  done
}
