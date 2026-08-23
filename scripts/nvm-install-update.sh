#!/usr/bin/env bash
# Install or upgrade nvm and Node.js.
# https://github.com/nvm-sh/nvm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/nvm.sh
source "$SCRIPT_DIR/lib/nvm.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

# Major Node lines offered in the interactive menu (nvm installs latest x.y.z in the line).
NVM_NODE_RECOMMENDED_MAJOR="${NVM_NODE_RECOMMENDED_MAJOR:-22}"
NVM_NODE_MAJOR_OPTIONS=(22 20 18)

NVM_VERSION="${NVM_VERSION:-}"
NODE_VERSION="${NODE_VERSION:-}"
INSTALL_NODE="${INSTALL_NODE:-1}"
NON_INTERACTIVE=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [major]

Install nvm into \$HOME/.nvm and Node.js via nvm.
Major selection installs the latest release in that line (e.g. 22 -> latest 22.x).

Environment:
  NVM_VERSION=              Pin nvm tag (default: latest GitHub release)
  NODE_VERSION=             Node major line (e.g. 22). Skips version prompt.
  INSTALL_NODE=0            Install nvm only
  NVM_NODE_RECOMMENDED_MAJOR Default recommended major (default: 22)
  NVM_NON_INTERACTIVE=1     No prompts; use recommended major
  NVM_YES=1                 Accept defaults without prompting

Options:
  --nvm-only          Install/update nvm only (no node install)
  --yes, -y           Use recommended major without prompting
  --non-interactive   Same as NVM_NON_INTERACTIVE=1
  --dry-run           Print actions only
  -h, --help          Show this help

Examples:
  $(basename "$0")                  # interactive prompts
  $(basename "$0") 20               # install latest 20.x
  NODE_VERSION=22 $(basename "$0")  # non-interactive major
  $(basename "$0") --nvm-only
EOF
}

log() {
  printf '[nvm] %s\n' "$*"
}

die() {
  printf '[nvm] ERROR: %s\n' "$*" >&2
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

truthy() {
  case "${1,,}" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_yes() {
  local prompt="$1"
  local reply=""

  if truthy "${NVM_YES:-}" || truthy "${DF_YES:-}"; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 || ! -t 0 ]]; then
    return 1
  fi

  read -r -p "$prompt [Y/n] " reply
  reply="${reply:-Y}"
  case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

major_label() {
  local major="$1"
  case "$major" in
    "$NVM_NODE_RECOMMENDED_MAJOR") printf '%s (recommended, latest %s.x)' "$major" "$major" ;;
    20) printf '%s (LTS, latest %s.x)' "$major" "$major" ;;
    18) printf '%s (maintenance LTS, latest %s.x)' "$major" "$major" ;;
    *) printf '%s (latest %s.x)' "$major" "$major" ;;
  esac
}

prompt_node_major() {
  local choice

  if [[ -n "$NODE_VERSION" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 || ! -t 0 ]] || truthy "${NVM_YES:-}" || truthy "${DF_YES:-}"; then
    NODE_VERSION="$NVM_NODE_RECOMMENDED_MAJOR"
    log "using recommended Node major: ${NODE_VERSION} (latest ${NODE_VERSION}.x)"
    return 0
  fi

  echo
  echo "Select Node.js major version (nvm installs the latest patch in that line):"
  local i=1
  for major in "${NVM_NODE_MAJOR_OPTIONS[@]}"; do
    echo "  ${i}) $(major_label "$major")"
    i=$((i + 1))
  done
  echo
  read -r -p "Choose [1-${#NVM_NODE_MAJOR_OPTIONS[@]}] (default 1): " choice

  case "${choice:-1}" in
    1 | "") NODE_VERSION="${NVM_NODE_MAJOR_OPTIONS[0]}" ;;
    2) NODE_VERSION="${NVM_NODE_MAJOR_OPTIONS[1]}" ;;
    3) NODE_VERSION="${NVM_NODE_MAJOR_OPTIONS[2]}" ;;
    22 | 20 | 18) NODE_VERSION="$choice" ;;
    *)
      die "invalid choice: $choice"
      ;;
  esac

  log "selected Node major: ${NODE_VERSION} (latest ${NODE_VERSION}.x)"
}

resolve_nvm_tag() {
  if [[ -n "$NVM_VERSION" ]]; then
    printf '%s\n' "$NVM_VERSION"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v jq >/dev/null 2>&1 || die "jq is required"

  gr_latest_tag "nvm-sh/nvm"
}

install_nvm() {
  local tag url tmp

  export NVM_DIR="$(nvm_dir)"

  if [[ -d "$NVM_DIR/.git" ]]; then
    log "nvm already present at $NVM_DIR"
    return 0
  fi

  tag="$(resolve_nvm_tag)"
  [[ -n "$tag" && "$tag" != "null" ]] || die "could not resolve nvm release tag"

  url="https://raw.githubusercontent.com/nvm-sh/nvm/${tag}/install.sh"
  log "installing nvm ${tag} into $NVM_DIR"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run gr_curl -fsSL "$url"
    return 0
  fi

  tmp="$(mktemp)"
  gr_curl -fsSL -o "$tmp" "$url"
  bash "$tmp"
  rm -f "$tmp"
}

install_node_major() {
  local major="$1"

  nvm_load || die "nvm is not available after install (expected $(nvm_dir)/nvm.sh)"

  log "installing Node.js latest ${major}.x with nvm"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run nvm install "$major"
    run nvm alias default "$major"
    run nvm use default
    return 0
  fi

  nvm install "$major"
  nvm alias default "$major"
  nvm use default

  nvm_node_ready || die "node/npm still missing after nvm install"
  log "node OK: $(node --version), npm $(npm --version) (default: latest ${major}.x line)"
}

should_install_node() {
  nvm_load || true

  if [[ -n "$NODE_VERSION" ]]; then
    return 0
  fi

  if ! nvm_node_ready; then
    return 0
  fi

  log "current node: $(node --version), npm $(npm --version)"

  if [[ "$NON_INTERACTIVE" -eq 1 || ! -t 0 ]]; then
    return 1
  fi

  prompt_yes "Install another Node major version?"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --nvm-only)
        INSTALL_NODE=0
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --yes | -y)
        NVM_YES=1
        shift
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          NODE_VERSION="$1"
          shift
        else
          die "unknown option: $1"
        fi
        ;;
    esac
  done

  if truthy "${NVM_NON_INTERACTIVE:-}"; then
    NON_INTERACTIVE=1
  fi
}

main() {
  parse_args "$@"

  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v git >/dev/null 2>&1 || die "git is required"

  install_nvm

  if [[ "$INSTALL_NODE" != "1" ]]; then
    log "nvm install complete (node install skipped)"
    exit 0
  fi

  if ! should_install_node; then
    log "done (existing node left unchanged)"
    exit 0
  fi

  prompt_node_major
  install_node_major "$NODE_VERSION"

  log "done"
  log "re-run to install another major: ./scripts/nvm-install-update.sh"
  log "example: ./scripts/nvm-install-update.sh 20"
}

main "$@"
