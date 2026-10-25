#!/usr/bin/env bash
# Generate this repo's Claude Code rules (.claude/rules/*.md) from the Cursor
# rules (.cursor/rules/*.mdc), which are the masters. Both are committed so
# either tool works in a fresh clone. Touches only the repo, never $HOME.
# Not an installer: for the machine-wide rules see ai-rules-install.sh.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
SRC_DIR="$DOTFILES_DIR/.cursor/rules"
DEST_DIR="$DOTFILES_DIR/.claude/rules"
MARKER='<!-- Generated from .cursor/rules/'
DRY_RUN=0
CHECK=0

# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/ai-repo-rules-sync.sh [options]

Convert the repo's Cursor rules (.cursor/rules/*.mdc) into Claude Code project
rules (.claude/rules/*.md). Edit the .mdc, then run this; do not edit the .md.

Conversion:
  globs: "{a,b}"      -> paths: list (Claude loads the rule when it reads or
                         edits a matching file)
  alwaysApply: true   -> no paths (loaded every session)
  no globs            -> no paths (loaded every session)
  description         -> dropped (Claude rules have no such field)
Generated files start with a "Generated from ..." comment; .md files in
.claude/rules/ without it are left alone. Generated files whose .mdc is gone
are removed.

Options:
  --check     Change nothing; exit 1 if .claude/rules is out of date (CI)
  --dry-run   Print what would change
  -h, --help  Show this help
EOF
}

log() {
  printf '[repo-rules] %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --check) CHECK=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# Render the .md for one .mdc to stdout.
render_rule() {
  local mdc="$1"
  local globs always pattern
  local -a patterns=()

  globs="$(df_ai_rules_mdc_field "$mdc" globs)"
  always="$(df_ai_rules_mdc_field "$mdc" alwaysApply)"

  if [[ "$always" != "true" && -n "$globs" ]]; then
    while IFS= read -r pattern; do
      [[ -n "$pattern" ]] && patterns+=("$pattern")
    done < <(df_ai_rules_globs_to_paths "$globs")
  fi

  if ((${#patterns[@]} > 0)); then
    printf -- '---\npaths:\n'
    for pattern in "${patterns[@]}"; do
      printf '  - "%s"\n' "$pattern"
    done
    printf -- '---\n'
  fi
  printf '%s%s -->\n' "$MARKER" "$(basename "$mdc") by scripts/ai-repo-rules-sync.sh. Edit the .mdc, then re-run."
  df_ai_rules_mdc_body "$mdc"
}

STALE=0

sync_rule() {
  local mdc="$1"
  local dest tmp
  dest="$DEST_DIR/$(df_ai_rules_markdown_name "$mdc")"
  tmp="$(mktemp)"
  render_rule "$mdc" >"$tmp"

  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    return 0
  fi
  STALE=1
  if [[ "$CHECK" -eq 1 ]]; then
    log "out of date: ${dest#"$DOTFILES_DIR"/}"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    log "would write: ${dest#"$DOTFILES_DIR"/}"
  else
    mkdir -p "$DEST_DIR"
    cat "$tmp" >"$dest"
    log "wrote: ${dest#"$DOTFILES_DIR"/}"
  fi
  rm -f "$tmp"
}

remove_stale() {
  local md base
  [[ -d "$DEST_DIR" ]] || return 0
  shopt -s nullglob
  local -a existing=("$DEST_DIR"/*.md)
  shopt -u nullglob
  for md in "${existing[@]}"; do
    grep -qF "$MARKER" "$md" || continue
    base="$(basename "$md" .md)"
    [[ -f "$SRC_DIR/$base.mdc" ]] && continue
    STALE=1
    if [[ "$CHECK" -eq 1 ]]; then
      log "stale (no .mdc): ${md#"$DOTFILES_DIR"/}"
    elif [[ "$DRY_RUN" -eq 1 ]]; then
      log "would remove: ${md#"$DOTFILES_DIR"/}"
    else
      log "remove stale: ${md#"$DOTFILES_DIR"/}"
      if command -v trash-put >/dev/null 2>&1; then
        trash-put "$md"
      else
        rm -f "$md"
      fi
    fi
  done
}

[[ -d "$SRC_DIR" ]] || {
  echo "ERROR: missing $SRC_DIR" >&2
  exit 1
}

shopt -s nullglob
mdc_files=("$SRC_DIR"/*.mdc)
shopt -u nullglob

for f in "${mdc_files[@]}"; do
  sync_rule "$f"
done
remove_stale

if [[ "$CHECK" -eq 1 && "$STALE" -eq 1 ]]; then
  echo "Run ./scripts/ai-repo-rules-sync.sh and commit .claude/rules/." >&2
  exit 1
fi
if [[ "$STALE" -eq 0 ]]; then
  log ".claude/rules is up to date (${#mdc_files[@]} rules)"
fi
