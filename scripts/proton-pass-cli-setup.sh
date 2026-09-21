#!/usr/bin/env bash
set -euo pipefail

# Optional manual setup: Proton Pass CLI + PAT file layout + key storage choice.
# Not part of devbox.sh / server.sh --all.
#
# https://protonpass.github.io/pass-cli/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_CONFIG_DIR="${HOME}/.config/proton-pass"
PASS_PAT_FILE="${PASS_CONFIG_DIR}/key.pat"
PASS_ENV_FILE="${PASS_CONFIG_DIR}/env"
PASS_INSTALL_URL="https://proton.me/download/pass-cli/install.sh"

MARK_BEGIN="# >>> proton-pass-cli-setup >>>"
MARK_END="# <<< proton-pass-cli-setup <<<"

DRY_RUN=0
KEY_PROVIDER="" # keyring | fs

usage() {
  cat <<'EOF'
Usage: ./scripts/proton-pass-cli-setup.sh [options]

Manual setup for Proton Pass CLI on devbox or headless servers:
  - Install pass-cli from Proton's official install script
  - Create ~/.config/proton-pass/key.pat (empty; you paste the PAT later)
  - Ask where to store the local DB encryption key (kernel keyring vs filesystem)
  - Write ~/.config/proton-pass/env when filesystem is chosen (loaded via
    ~/.config/dotfiles/proton-pass-env.sh on login)

Does NOT log in, does NOT read or store your PAT, does NOT start the SSH agent.
May run pass-cli update -y after sourcing ~/.config/proton-pass/env.

Options:
  --keyring       Use kernel keyring (default Proton behavior; no env file)
  --filesystem    Store encryption key on disk (PROTON_PASS_KEY_PROVIDER=fs)
  --dry-run       Print actions only
  -h, --help      Show this help

Examples:
  ./scripts/proton-pass-cli-setup.sh
  ./scripts/proton-pass-cli-setup.sh --filesystem
EOF
}

log() {
  printf '[proton-pass-setup] %s\n' "$*"
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

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# shellcheck source=lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --keyring) KEY_PROVIDER=keyring ;;
    --filesystem) KEY_PROVIDER=fs ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

require_cmds() {
  local c
  for c in curl jq; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: $c (install curl and jq first)"
  done
}

choose_key_provider() {
  if [[ -n "$KEY_PROVIDER" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "choose key storage interactively or pass --keyring / --filesystem"
  fi

  cat <<'EOF'

Proton Pass CLI stores a local key to encrypt its session database.

  1) Kernel keyring (default)
     Uses the Linux kernel keyring. Cleared on reboot. Good for desktops and
     devboxes with a normal kernel keyring.

  2) Filesystem
     Stores the key at ~/.local/share/proton-pass-cli/.session/local.key
     (mode 0600). Survives reboot. Use for headless VMs, containers, or when
     the keyring is unreliable (tmux-heavy SSH, LXC, etc.).

EOF

  local choice=""
  while true; do
    read -r -p "Select key storage [1=keyring, 2=filesystem] (default 1): " choice
    choice="${choice:-1}"
    case "$choice" in
      1 | keyring)
        KEY_PROVIDER=keyring
        return 0
        ;;
      2 | fs | filesystem)
        KEY_PROVIDER=fs
        return 0
        ;;
      *)
        echo "Enter 1 or 2." >&2
        ;;
    esac
  done
}

ensure_pat_layout() {
  log "config dir: $PASS_CONFIG_DIR"
  log "PAT file:   $PASS_PAT_FILE (you paste the token manually; not in dotfiles)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run mkdir -p "$PASS_CONFIG_DIR"
    run chmod 700 "$PASS_CONFIG_DIR"
    if [[ ! -f "$PASS_PAT_FILE" ]]; then
      run touch "$PASS_PAT_FILE"
    fi
    run chmod 600 "$PASS_PAT_FILE"
    return 0
  fi

  mkdir -p "$PASS_CONFIG_DIR"
  chmod 700 "$PASS_CONFIG_DIR"
  if [[ ! -f "$PASS_PAT_FILE" ]]; then
    : >"$PASS_PAT_FILE"
    log "created empty $PASS_PAT_FILE"
  else
    log "PAT file already exists (contents unchanged)"
  fi
  chmod 600 "$PASS_PAT_FILE"
}

strip_setup_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if ! grep -qF "$MARK_BEGIN" "$file" 2>/dev/null; then
    return 0
  fi
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip { print }
  ' "$file"
}

write_key_provider_env() {
  local tmp preserved=""
  tmp="$(mktemp)"
  chmod 600 "$tmp"

  if [[ -f "$PASS_ENV_FILE" ]]; then
    preserved="$(strip_setup_block "$PASS_ENV_FILE")"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$KEY_PROVIDER" == fs ]]; then
      log "would write PROTON_PASS_KEY_PROVIDER=fs to $PASS_ENV_FILE"
    else
      log "would remove proton-pass block from $PASS_ENV_FILE (kernel keyring default)"
    fi
    rm -f "$tmp"
    return 0
  fi

  if [[ "$KEY_PROVIDER" == fs ]]; then
    {
      [[ -n "$preserved" ]] && printf '%s\n' "$preserved"
      cat <<EOF
$MARK_BEGIN
# Loaded via ~/.config/dotfiles/proton-pass-env.sh on login.
export PROTON_PASS_KEY_PROVIDER=fs
$MARK_END
EOF
    } >"$tmp"
    mv -f "$tmp" "$PASS_ENV_FILE"
    chmod 600 "$PASS_ENV_FILE"
    log "wrote $PASS_ENV_FILE (filesystem key storage)"
  else
    rm -f "$tmp"
    if [[ -n "$preserved" ]]; then
      printf '%s\n' "$preserved" >"$PASS_ENV_FILE"
      chmod 600 "$PASS_ENV_FILE"
    else
      rm -f "$PASS_ENV_FILE"
    fi
    log "kernel keyring: no PROTON_PASS_KEY_PROVIDER in $PASS_ENV_FILE"
  fi
}

# Load ~/.config/proton-pass/env before pass-cli update (filesystem key mode).
apply_pass_cli_env() {
  if [[ -f "$PASS_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$PASS_ENV_FILE"
  fi
}

pass_cli_try_update() {
  if ! command -v pass-cli >/dev/null 2>&1; then
    return 0
  fi

  apply_pass_cli_env
  log "checking for pass-cli updates..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run pass-cli update -y
    return 0
  fi

  pass-cli update -y || log "pass-cli update skipped (see instructions below if KeyRevoked)"
}

install_pass_cli() {
  if command -v pass-cli >/dev/null 2>&1; then
    log "pass-cli already installed: $(command -v pass-cli)"
    pass-cli --version 2>/dev/null | head -n1 || true
    pass_cli_try_update
    return 0
  fi

  log "installing pass-cli from $PASS_INSTALL_URL"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run bash -c "curl -fsSL '$PASS_INSTALL_URL' | bash"
    return 0
  fi

  bash -c "curl -fsSL '$PASS_INSTALL_URL' | bash"

  command -v pass-cli >/dev/null 2>&1 || die "pass-cli not found in PATH after install"
  log "installed: $(pass-cli --version 2>/dev/null | head -n1 || pass-cli --version)"
  pass_cli_try_update
}

print_next_steps() {
  cat <<EOF

Setup finished (login and agent are still manual).

1) Paste your machine PAT into (file only, no trailing newline required):
     $PASS_PAT_FILE
   chmod 600 "$PASS_PAT_FILE"
   Use a separate PAT per machine; keys vault, viewer role is enough.

2) Before login:
EOF
  if [[ "$KEY_PROVIDER" == fs ]]; then
    cat <<EOF
   Filesystem key storage is enabled. Load it in this shell:
     source "$PASS_ENV_FILE"
   Or: source ~/.profile  (loads ~/.config/dotfiles/proton-pass-env.sh)
EOF
  fi
  cat <<EOF

   If login ever failed with keyring / KeyRevoked errors, reset local session:
     pass-cli logout --force

   Log in (does not run automatically):
     PROTON_PASS_PERSONAL_ACCESS_TOKEN="\$(<"$PASS_PAT_FILE")" pass-cli login
   Verify:
     pass-cli info
     pass-cli vault list

3) Start the SSH agent daemon (example vault name "keys"):
     pass-cli ssh-agent daemon start --vault-name "keys"
     pass-cli ssh-agent daemon status

4) SSH_AUTH_SOCK
   Dotfiles set it when the socket exists (~/.ssh/proton-pass-agent.sock),
   via ~/.config/dotfiles/proton-pass-env.sh (sourced from ~/.profile).
   Open a new login shell or: source ~/.profile

   Check keys: ssh-add -l

Optional logout before switching PAT:
  pass-cli logout --force

Docs: https://protonpass.github.io/pass-cli/

EOF
}

require_cmds
choose_key_provider
ensure_pat_layout
write_key_provider_env
install_pass_cli
print_next_steps
