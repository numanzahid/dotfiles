#!/usr/bin/env bash
# Let Claude Code and Codex run sudo through a tmux password popup, and drop
# their sandboxes. Separate from install-ai-rules.sh / devbox.sh / desktop.sh:
# run it only on machines where you want agents unrestricted.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"
DRY_RUN=0
UNINSTALL=0
NO_APPROVALS=1

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/ai-agent-sudo-install.sh [options]

Agent sudo setup for Claude Code and Codex, with agent restrictions removed.

What it does:
  ~/.local/bin/tmux-askpass   symlink; asks for the sudo password in a tmux
                              popup so agent shells never see it
  ~/.local/bin/sudo           symlink; wrapper that adds -A when SUDO_ASKPASS
                              is set (agent shells only; normal shells unchanged)
  Claude settings.json        env.SUDO_ASKPASS, sandbox.enabled=false,
                              permissions.defaultMode=bypassPermissions,
                              skipDangerousModePermissionPrompt=true
  Codex config.toml           sandbox_mode="danger-full-access",
                              approval_policy="never",
                              shell_environment_policy.set.SUDO_ASKPASS
  ~/.cursor/rules/sudo.mdc    "how to run root commands" rule, merged into
                              ~/.claude/rules/sudo.md and ~/.codex/AGENTS.md

Only those keys are touched; the rest of each config file is left alone.
The sudo password is never read, stored, or passed through this script.

Options:
  --keep-approvals  Keep approval prompts: skip bypassPermissions (Claude) and
                    approval_policy="never" (Codex); the sandbox is still
                    removed. Also reverts an earlier unrestricted run.
  --uninstall       Remove what this script added (keys, symlinks, sudo rule)
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
    --keep-approvals) NO_APPROVALS=0 ;;
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
  mkdir -p "$bin"
  run chmod +x "$src/tmux-askpass" "$src/sudo"
  df_link_path "$src/tmux-askpass" "$bin/tmux-askpass"
  df_link_path "$src/sudo" "$bin/sudo"

  df_agent_sudo_merge "$NO_APPROVALS"

  mkdir -p "$(dirname "$rule_dest")"
  df_link_path "$rule_src" "$rule_dest"
  refresh_generated_rules

  df_journal_once patch agent-sudo "ai-agent-sudo-install.sh"
  if [[ "$NO_APPROVALS" -eq 1 ]]; then
    df_journal_once patch agent-sudo-no-approvals "ai-agent-sudo-install.sh"
  fi
  log "done. Restart running Claude Code / Codex sessions to pick up the new settings."
}

# Remove a symlink only when it points into this clone.
unlink_ours() {
  local dest="$1"
  if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$DOTFILES_DIR/"* ]]; then
    log "remove link: $dest"
    run rm -f "$dest"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      df_journal_remove_path "$dest"
    fi
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
  log "removed. Originals (if any) are under $(df_backups_dir); repo copies stay in scripts/agent-sudo/."
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  uninstall_agent_sudo
else
  install_agent_sudo
fi
