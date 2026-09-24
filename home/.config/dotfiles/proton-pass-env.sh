# shellcheck shell=sh
# Proton Pass CLI machine settings and SSH agent socket.
# PAT login is manual; see: ./scripts/proton-pass-cli-setup.sh
#
# Optional: ~/.config/proton-pass/env (written by the setup script for
# PROTON_PASS_KEY_PROVIDER=fs on headless hosts).
#
# Sourced from both ~/.profile (login shells, including non-bash) and
# ~/.bashrc (interactive non-login shells, e.g. a new terminal pane) --
# a login+interactive bash shell hits both, so guard against running the
# pass-cli daemon-status check (a subprocess+IPC round trip) twice.
if [ -n "${_DOTFILES_PROTON_PASS_ENV_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_DOTFILES_PROTON_PASS_ENV_LOADED=1

if [ -f "$HOME/.config/proton-pass/env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.config/proton-pass/env"
fi

# Default socket path used by pass-cli ssh-agent (start / daemon).
_pp_ssh_sock="$HOME/.ssh/proton-pass-agent.sock"
if [ -S "$_pp_ssh_sock" ]; then
  export SSH_AUTH_SOCK="$_pp_ssh_sock"
elif command -v pass-cli >/dev/null 2>&1; then
  if pass-cli ssh-agent daemon status >/dev/null 2>&1; then
    export SSH_AUTH_SOCK="$_pp_ssh_sock"
  fi
fi
unset _pp_ssh_sock
