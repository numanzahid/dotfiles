# Setup fzf
# ---------
# Prefer git-installed fzf (~/.fzf) over older distro packages.
if [[ -x "$HOME/.fzf/bin/fzf" ]]; then
  PATH="$HOME/.fzf/bin:${PATH}"
fi

setup_fzf() {
  command -v fzf >/dev/null 2>&1 || return 0

  # fzf 0.48+ (git install / recent releases)
  if fzf --help 2>&1 | grep -q -- '--bash'; then
    eval "$(fzf --bash)"
    return 0
  fi

  # Older fzf (e.g. Debian apt) via junegunn/fzf shell scripts
  if [[ -f "$HOME/.fzf/shell/key-bindings.bash" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.fzf/shell/key-bindings.bash"
  fi
  if [[ -f "$HOME/.fzf/shell/completion.bash" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.fzf/shell/completion.bash"
  fi
}

setup_fzf
