#!/usr/bin/env bash
# Let Claude Code and Codex run sudo through a tmux password popup (SUDO_ASKPASS).
# Opt-in per machine: devbox.sh, desktop.sh and dotfiles update never run it.
# Also applies the base Claude/Codex settings. It never changes sandbox or
# approval settings; those are explicit: `dotfiles install ai-config --nosandbox`.
# Run as ./scripts/ai-agent-sudo-install.sh or `dotfiles install ai-sudo`.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0
UNINSTALL=0
# Sandbox choice is explicit and belongs to ai-config; ignore any inherited value.
unset DF_AI_SANDBOX_ACTION

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/ai-agent-sudo-install.sh [options]

Agent sudo setup for Claude Code and Codex.

What it does:
  base settings               first applies the dotfiles Claude/Codex settings
                              (same as ./scripts/ai-config-install.sh)
  ~/.local/bin/tmux-askpass   link (copy on a server); asks for the sudo
                              password in a tmux popup so agent shells never
                              see it
  ~/.local/bin/sudo           link (copy on a server); wrapper that adds -A when
                              SUDO_ASKPASS is set (agent shells only; normal
                              shells unchanged)
  Claude settings.json        env.SUDO_ASKPASS
  Codex config.toml           shell_environment_policy.set.SUDO_ASKPASS
  ~/.cursor/rules/sudo.mdc    "how to run root commands" rule, merged into
                              ~/.claude/rules/sudo.md and ~/.codex/AGENTS.md

Sandboxes and approval prompts are not part of this: use
`dotfiles install ai-config --nosandbox` (or --sandbox to put them back).
Only those keys are touched; the rest of each config file is left alone.
The sudo password is never read, stored, or passed through this script.
Needs: tmux (agents must run inside it), jq, python3 >= 3.11, ~/.local/bin
before /usr/bin on PATH. Restart running Claude Code / Codex sessions after.

Options:
  --uninstall       Remove the sudo setup (SUDO_ASKPASS keys, links, sudo
                    rule). Sandbox settings are never touched here
  --copy            Copy files instead of linking (default on a server profile)
  --link            Link files into the clone (default elsewhere)
  --yes, -y         Accepted for `dotfiles uninstall ai-sudo`; there are no prompts
  --dry-run         Print actions without changing anything
  -h, --help        Show this help
EOF
}

log() {
  printf '[agent-sudo] %s\n' "$*"
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
    --uninstall) UNINSTALL=1 ;;
    --copy) export DF_AI_COPY_MODE=1 ;;
    --link) export DF_AI_COPY_MODE=0 ;;
    --yes | -y) ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# Regenerate ~/.claude/rules/*.md and ~/.codex/AGENTS.md from the cursor rules
# (ai-rules.sh also merges custom ~/.cursor/rules/*.mdc such as sudo.mdc).
refresh_generated_rules() {
  df_ai_rules_install_codex
  df_ai_rules_install_claude
}

preflight() {
  command -v tmux >/dev/null 2>&1 || log "WARN: tmux not found; the sudo popup needs it (agents must run inside tmux)"
  command -v jq >/dev/null 2>&1 || log "WARN: jq not found; Claude settings will be skipped"
  df_toml_can_edit || log "WARN: python3 >= 3.11 not found; Codex config will be skipped"
  case ":$PATH:" in
    *":$TARGET_HOME/.local/bin:"*) ;;
    *) log "WARN: ~/.local/bin is not on PATH; the sudo wrapper will not take effect" ;;
  esac
  if [[ "$(command -v sudo 2>/dev/null || true)" != "$TARGET_HOME/.local/bin/sudo" ]]; then
    log "note: 'sudo' currently resolves to $(command -v sudo 2>/dev/null || echo 'nothing'); put ~/.local/bin before /usr/bin in PATH for agents to pick up the wrapper"
  fi
}

install_agent_sudo() {
  local src bin rule_src rule_dest
  src="$(df_agent_sudo_src_dir)"
  bin="$TARGET_HOME/.local/bin"
  rule_src="$(df_ai_rules_root)/optional/sudo.mdc"
  rule_dest="$(df_ai_rules_cursor_dest_dir)/sudo.mdc"

  preflight
  df_ai_config_install_all

  mkdir -p "$bin"
  run chmod +x "$src/tmux-askpass" "$src/sudo"
  df_ai_place "$src/tmux-askpass" "$bin/tmux-askpass"
  df_ai_place "$src/sudo" "$bin/sudo"

  df_agent_sudo_merge

  mkdir -p "$(dirname "$rule_dest")"
  df_ai_place "$rule_src" "$rule_dest"
  refresh_generated_rules

  df_journal_once patch agent-sudo "ai-agent-sudo-install.sh"
  log "done. Restart running Claude Code / Codex sessions to pick up the new settings."
}

# Remove a symlink that points into this clone, or a copy we installed (tracked).
unlink_ours() {
  local dest="$1"
  if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$DOTFILES_DIR/"* ]]; then
    log "remove link: $dest"
  elif [[ -f "$dest" && ! -L "$dest" ]] && df_path_is_tracked "$dest"; then
    log "remove copy: $dest"
  else
    return 0
  fi
  run rm -f "$dest"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    df_journal_remove_path "$dest"
  fi
}

uninstall_agent_sudo() {
  local claude_rule
  claude_rule="$(df_ai_rules_claude_rules_dir)/sudo.md"

  df_agent_sudo_unmerge
  unlink_ours "$TARGET_HOME/.local/bin/tmux-askpass"
  unlink_ours "$TARGET_HOME/.local/bin/sudo"
  unlink_ours "$(df_ai_rules_cursor_dest_dir)/sudo.mdc"

  if [[ -f "$claude_rule" ]]; then
    log "remove generated rule: $claude_rule"
    if command -v trash-put >/dev/null 2>&1; then
      run trash-put "$claude_rule"
    else
      run rm -f "$claude_rule"
    fi
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    df_journal_remove_path "$claude_rule"
  fi
  refresh_generated_rules
  log "removed. Originals (if any) are under $(df_backups_dir); repo copies stay in scripts/ai-agent-sudo/."
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  uninstall_agent_sudo
else
  install_agent_sudo
fi
