#!/usr/bin/env bash
# Install dotfiles-owned Claude Code and Codex settings (keys only, not whole files).
# Also run automatically by ai-rules-install.sh, ./devbox.sh and ./desktop.sh.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0
UNINSTALL=0

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/ai-config-install.sh [options]

Merge dotfiles-owned settings into Claude Code and Codex config. Only the keys
in the repo are set; trust entries, auth, history and UI state are never touched.

Source (home/.config/dotfiles/ai-config/):
  claude/settings.base.json   merged into ~/.claude/settings.json (jq)
  codex/config.base.toml      merged into ~/.codex/config.toml

Linked one item at a time, copied on a server (parent dirs are never replaced):
  home/.claude/statusline-command.sh -> ~/.claude/statusline-command.sh
  home/.claude/{skills,agents,commands}/*  -> ~/.claude/<kind>/*
  home/.codex/{prompts,skills}/*           -> ~/.codex/<kind>/*

Settings only; ./scripts/ai-rules-install.sh does these plus the rules, and runs
in devbox.sh, desktop.sh and dotfiles update. Sudo askpass and unrestricted
sandboxes are a separate opt-in script: ./scripts/ai-agent-sudo-install.sh

Options:
  --uninstall  Remove the merged keys again (links are reverted by uninstall.sh)
  --copy       Copy files instead of linking (default on a server profile)
  --link       Link files into the clone (default elsewhere)
  --dry-run    Print actions without changing anything
  -h, --help   Show this help
EOF
}

log() {
  printf '[ai-config] %s\n' "$*"
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
    --uninstall) UNINSTALL=1 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  log "removing merged keys"
  df_ai_config_unmerge_all
else
  log "installing Claude Code and Codex config"
  df_ai_config_install_all
fi
