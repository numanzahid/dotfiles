#!/usr/bin/env bash
# Optional AI coding CLIs from official vendor installers.
# Not part of ./install.sh --all.
#
# Installs user-local binaries (no apt). Run as your normal user, not root.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$DOTFILES_DIR/home"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
DRY_RUN=0
DO_STATUS=0
SELECTED=()

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPTS_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/link.sh
source "$SCRIPTS_DIR/lib/link.sh"
df_prepend_local_bin

usage() {
  cat <<'EOF'
Usage: ./install-ai-cli.sh [tools...] [options]

Install AI coding CLIs from their official sources (user-local, not apt).

Tools:
  opencode    https://opencode.ai/install
  cursor      https://cursor.com/install          (agent / cursor-agent)
  claude      https://claude.ai/install.sh        (Claude Code)
  codex       https://chatgpt.com/codex/install.sh
  all         Install all four

If no tool is given and stdin is a TTY, you are prompted per tool (default skip).
If no tool is given and stdin is not a TTY, nothing is installed.

Options:
  --status    Show install status only
  --dry-run   Print installer commands without running them
  -h, --help  Show this help

Examples:
  ./install-ai-cli.sh
  ./install-ai-cli.sh all
  ./install-ai-cli.sh claude opencode
  ./install-ai-cli.sh --status
EOF
}

log() {
  printf '[ai-cli] %s\n' "$*"
}

die() {
  printf '[ai-cli] ERROR: %s\n' "$*" >&2
  exit 1
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

tool_cmd() {
  case "$1" in
    opencode) printf '%s\n' "opencode" ;;
    cursor) printf '%s\n' "agent" ;;
    claude) printf '%s\n' "claude" ;;
    codex) printf '%s\n' "codex" ;;
    *) return 1 ;;
  esac
}

tool_installed() {
  local name="$1"
  case "$name" in
    opencode)
      command -v opencode >/dev/null 2>&1 || [[ -x "${HOME}/.opencode/bin/opencode" ]]
      ;;
    cursor)
      command -v agent >/dev/null 2>&1 || command -v cursor-agent >/dev/null 2>&1
      ;;
    claude)
      command -v claude >/dev/null 2>&1
      ;;
    codex)
      command -v codex >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

tool_version_line() {
  local name="$1" bin=""
  case "$name" in
    opencode)
      bin="$(command -v opencode 2>/dev/null || true)"
      [[ -n "$bin" ]] || bin="${HOME}/.opencode/bin/opencode"
      ;;
    cursor)
      bin="$(command -v agent 2>/dev/null || command -v cursor-agent 2>/dev/null || true)"
      ;;
    claude)
      bin="$(command -v claude 2>/dev/null || true)"
      ;;
    codex)
      bin="$(command -v codex 2>/dev/null || true)"
      ;;
  esac
  if [[ -n "$bin" && -x "$bin" ]]; then
    local ver
    ver="$("$bin" --version 2>/dev/null | head -n 1 || true)"
    if [[ -n "$ver" ]]; then
      printf '%s\n' "$ver"
    else
      printf '%s\n' "$bin"
    fi
  else
    printf '%s\n' "missing"
  fi
}

print_status() {
  local name
  echo "AI CLI status:"
  for name in opencode cursor claude codex; do
    if tool_installed "$name"; then
      printf '  %-9s installed  %s\n' "$name" "$(tool_version_line "$name")"
    else
      printf '  %-9s missing\n' "$name"
    fi
  done
}

prompt_yes() {
  local prompt="$1"
  local reply=""

  if [[ ! -t 0 ]]; then
    return 1
  fi

  read -r -p "$prompt [y/N] " reply
  case "${reply:-N}" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_tools() {
  echo >&2
  echo "Install AI coding CLIs from official sources?" >&2
  echo "Each installer writes user-local files (typically ~/.local/bin)." >&2
  echo >&2
  print_status >&2
  echo >&2

  if prompt_yes "Install OpenCode CLI"; then
    SELECTED+=("opencode")
  fi
  if prompt_yes "Install Cursor CLI (agent)"; then
    SELECTED+=("cursor")
  fi
  if prompt_yes "Install Claude Code CLI"; then
    SELECTED+=("claude")
  fi
  if prompt_yes "Install Codex CLI"; then
    SELECTED+=("codex")
  fi
}

normalize_tool() {
  case "$1" in
    opencode | open-code) printf '%s\n' "opencode" ;;
    cursor | cursor-agent | agent) printf '%s\n' "cursor" ;;
    claude | claud | claude-code) printf '%s\n' "claude" ;;
    codex | openai-codex | openai) printf '%s\n' "codex" ;;
    *) return 1 ;;
  esac
}

run_official_installer() {
  local name="$1"
  local url="$2"
  local shell="$3"
  local tmp

  log "installing $name from $url"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would download $url and run: $shell <installer>"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required"

  tmp="$(mktemp)"
  # Download first so a failed fetch cannot pipe HTML into a shell.
  curl -fsSL --retry 3 --retry-delay 1 "$url" -o "$tmp"
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    die "downloaded empty installer for $name"
  fi
  "$shell" "$tmp"
  rm -f "$tmp"
}

link_opencode_config() {
  local src="$SOURCE_DIR/.config/opencode/opencode.jsonc"
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.jsonc"

  if [[ ! -e "$src" ]]; then
    log "skip missing OpenCode config: $src"
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  df_link_path "$src" "$dest"
}

install_opencode() {
  export PATH="${HOME}/.opencode/bin:${PATH}"
  run_official_installer "opencode" "https://opencode.ai/install" bash
  link_opencode_config
}

install_cursor() {
  run_official_installer "cursor" "https://cursor.com/install" bash
}

install_claude() {
  run_official_installer "claude" "https://claude.ai/install.sh" bash
}

install_codex() {
  run_official_installer "codex" "https://chatgpt.com/codex/install.sh" sh
}

install_tool() {
  case "$1" in
    opencode) install_opencode ;;
    cursor) install_cursor ;;
    claude) install_claude ;;
    codex) install_codex ;;
    *) die "unknown tool: $1" ;;
  esac
}

print_next_steps() {
  cat <<'EOF'

Next steps (authenticate in a real terminal):
  opencode   opencode auth login
  cursor     agent login
  claude     claude
  codex      codex login

PATH: ~/.local/bin is already exported by .bashrc.
OpenCode also uses ~/.opencode/bin when that directory exists.
EOF
}

if [[ "$(id -u)" -eq 0 ]]; then
  die "run as your normal user, not root (these CLIs install into \$HOME)"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --status | status) DO_STATUS=1 ;;
    all)
      SELECTED=(opencode cursor claude codex)
      ;;
    opencode | open-code | cursor | cursor-agent | agent | claude | claud | claude-code | codex | openai-codex | openai)
      SELECTED+=("$(normalize_tool "$1")")
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$DO_STATUS" -eq 1 ]]; then
  print_status
  exit 0
fi

if [[ "${#SELECTED[@]}" -eq 0 ]]; then
  if [[ -t 0 ]]; then
    prompt_tools
  else
    log "no tools selected; current setup left unchanged"
    print_status
    exit 0
  fi
fi

if [[ "${#SELECTED[@]}" -eq 0 ]]; then
  log "nothing selected"
  exit 0
fi

# De-duplicate while keeping order.
declare -A seen=()
unique=()
for name in "${SELECTED[@]}"; do
  if [[ -z "${seen[$name]:-}" ]]; then
    seen["$name"]=1
    unique+=("$name")
  fi
done
SELECTED=("${unique[@]}")

for name in "${SELECTED[@]}"; do
  echo
  install_tool "$name"
done

df_prepend_local_bin
export PATH="${HOME}/.opencode/bin:${PATH}"

echo
print_status
print_next_steps
