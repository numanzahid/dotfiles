#!/usr/bin/env bash
# Install dotfiles AI agent rules (cursor, codex, claude).
# Also run automatically by ./devbox.sh and ./desktop.sh.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

usage() {
  cat <<'EOF'
Usage: ./install-ai-rules.sh [options]

Install dotfiles AI agent rules for Cursor, Codex, and Claude Code.

Master source:
  home/.config/dotfiles/ai-rules/cursor/*.mdc

Destination:
  ~/.cursor/rules/*.mdc   symlinks to repo; add custom *.mdc here
  ~/.codex/AGENTS.md      merged from all .mdc (Codex needs one file)
  ~/.claude/rules/*.md    one file per rule (frontmatter stripped)

Also runs during ./devbox.sh and ./desktop.sh.

Options:
  --dry-run   Print actions without changing anything
  -h, --help  Show this help
EOF
}

log() {
  printf '[ai-rules] %s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

log "installing AI agent rules"
df_ai_rules_install_all
