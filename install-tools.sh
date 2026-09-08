#!/usr/bin/env bash
# Install or upgrade CLI tools from upstream releases (not apt).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

TOOLS=(
  bat-install-update.sh
  fd-install-update.sh
  zoxide-install-update.sh
  eza-install-update.sh
)

usage() {
  cat <<'EOF'
Usage: ./install-tools.sh [options]

Install or upgrade from upstream releases:
  bat, fd, zoxide, eza

Fastfetch is separate:
  ./install-fetch.sh

Lazygit is separate:
  ./scripts/lazygit-install-update.sh

Options:
  --uninstall  Uninstall bat, fd, zoxide, eza via each tool script
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help

Re-run anytime to upgrade:
  ./install-tools.sh
  ./devbox.sh --tools
EOF
}

UNINSTALL=0
DRY=0
YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    --yes | -y) YES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

run_tool() {
  local script="$1"
  local -a args=()

  [[ "$UNINSTALL" -eq 1 ]] && args+=(--uninstall)
  [[ "$DRY" -eq 1 ]] && args+=(--dry-run)
  [[ "$YES" -eq 1 ]] && args+=(--yes)

  echo
  echo "==> ${script}"
  bash "$SCRIPTS_DIR/$script" "${args[@]}"
}

failed=()
for tool_script in "${TOOLS[@]}"; do
  if run_tool "$tool_script"; then
    continue
  fi
  echo "WARN: ${tool_script} failed" >&2
  failed+=("$tool_script")
done

echo
if ((${#failed[@]} > 0)); then
  echo "WARN: tool scripts failed: ${failed[*]}" >&2
  exit 1
fi
if [[ "$UNINSTALL" -eq 1 ]]; then
  # shellcheck source=scripts/lib/component-state.sh
  source "$SCRIPTS_DIR/lib/component-state.sh"
  if [[ "$DRY" -eq 0 ]]; then
    df_component_forget tools
  fi
  echo "CLI tools uninstall complete."
else
  echo "CLI tools install complete."
fi
