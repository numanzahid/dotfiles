#!/usr/bin/env bash
# Install dotfiles AI agent rules (cursor, codex, claude) and the dotfiles-owned
# Claude/Codex settings keys (see scripts/ai-config-install.sh).
# Also run automatically by ./devbox.sh and ./desktop.sh (not by ./server.sh).
# Sudo askpass + unrestricted agents: scripts/ai-agent-sudo-install.sh (opt-in).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
Usage: ./scripts/ai-rules-install.sh [options]

Install dotfiles AI agent rules for Cursor, Codex, and Claude Code, plus the
dotfiles-owned keys of the Claude/Codex config (see ./scripts/ai-config-install.sh).

Master source:
  home/.config/dotfiles/ai-rules/cursor/*.mdc

Destination:
  ~/.cursor/rules/*.mdc   symlinks to repo (copies on a server); add custom *.mdc here
  ~/.codex/AGENTS.md      merged from all .mdc (Codex needs one file)
  ~/.claude/rules/*.md    one file per rule (frontmatter stripped)

  ~/.claude/settings.json and ~/.codex/config.toml  keys merged, not replaced

Sudo askpass and unrestricted sandboxes: ./scripts/ai-agent-sudo-install.sh (separate).

Runs automatically during ./devbox.sh, ./desktop.sh and dotfiles update.
./server.sh does not run it; on a server use `dotfiles install ai-config`
(this script, with copies instead of links).

Options:
  --copy      Copy files instead of linking (default on a server profile)
  --link      Link files into the clone (default elsewhere)
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
    --copy) export DF_AI_COPY_MODE=1 ;;
    --link) export DF_AI_COPY_MODE=0 ;;
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
