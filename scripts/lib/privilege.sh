#!/usr/bin/env bash
# Shared root/sudo helpers for dotfiles install scripts.

df_need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

df_is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

df_prompt_yes() {
  local prompt="$1"
  local reply=""

  if [[ "${DF_YES:-}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "ERROR: $prompt requires an interactive terminal (or set DF_YES=1)" >&2
    return 1
  fi

  read -r -p "$prompt [Y/n] " reply
  reply="${reply:-Y}"
  case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

df_install_sudo_package() {
  if ! df_need_cmd apt-get; then
    echo "ERROR: apt-get not found; install sudo manually" >&2
    return 1
  fi

  if ! df_is_root; then
    echo "ERROR: must be root to install sudo" >&2
    return 1
  fi

  echo "Installing sudo..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
}

# Ensure sudo exists before privileged install steps.
# Root without sudo: prompt to install (optional; root can still run apt directly).
# Non-root without sudo: fail with instructions.
df_ensure_sudo() {
  if df_need_cmd sudo; then
    return 0
  fi

  if df_is_root; then
    echo "sudo is not installed."
    if df_prompt_yes "Install sudo now?"; then
      df_install_sudo_package
      if ! df_need_cmd sudo; then
        echo "ERROR: sudo install failed" >&2
        return 1
      fi
      echo "sudo installed."
    else
      echo "Continuing as root without sudo."
    fi
    return 0
  fi

  echo "ERROR: sudo is not installed and you are not root." >&2
  echo "Install sudo as root, then re-run this script:" >&2
  echo "  apt-get update && apt-get install -y sudo" >&2
  return 1
}

# Print "sudo" when not root; empty when already root.
df_sudo() {
  if ! df_is_root; then
    if df_need_cmd sudo; then
      printf '%s' sudo
    else
      echo "ERROR: need root or sudo (run df_ensure_sudo first)" >&2
      return 1
    fi
  fi
}

# Run a command as root (directly or via sudo).
df_run_privileged() {
  local sudo_cmd=""
  sudo_cmd="$(df_sudo)" || exit 1
  # shellcheck disable=SC2086
  $sudo_cmd "$@"
}
