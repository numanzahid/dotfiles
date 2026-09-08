# ~/.shell_aliases_interactive.sh
# Interactive-only shell customizations.
# This file is sourced from ~/.bashrc only for real interactive terminals.
# Shortcuts reference: ~/.dotfiles/SHORTCUTS.md

##### fzf ###############################################################

# Set up fzf key bindings and fuzzy completion.
# Git installer writes ~/.fzf.bash. Fedora dnf fzf uses `fzf --bash`.
if [ -f ~/.fzf.bash ]; then
  source ~/.fzf.bash
elif command -v fzf >/dev/null 2>&1; then
  _dotfiles_fzf_bash="$(fzf --bash 2>/dev/null)" && eval "$_dotfiles_fzf_bash"
  unset _dotfiles_fzf_bash
fi

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  # Ctrl+T inserts a path at the cursor (files and dirs; e.g. mv src <pick dest dir>).
  export FZF_CTRL_T_COMMAND='fd --hidden --follow --exclude .git'
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview-window right:50%'
if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS='--preview "bat --color=always --line-range :500 {}"'
fi
if command -v eza >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS='--preview "eza -1 --color=always {}"'
fi

# File browser with bat preview (uses FZF_DEFAULT_COMMAND when fd is available).
alias ff='fzf --preview "bat --color=always --line-range :500 {}"'

# Fuzzy cd into a directory under the current tree.
fcd() {
  local dir
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found" >&2
    return 1
  fi
  if command -v fd >/dev/null 2>&1; then
    dir="$(fd --type d --hidden --follow --exclude .git | fzf --preview 'eza -1 --color=always {} 2>/dev/null || ls -1 --color=always {}')"
  else
    dir="$(find . -type d 2>/dev/null | fzf)"
  fi
  [[ -n "$dir" ]] && cd "$dir" && pwd
}

# Fuzzy find a file and open it in $EDITOR.
fe() {
  local file
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found" >&2
    return 1
  fi
  if command -v fd >/dev/null 2>&1; then
    file="$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --color=always --line-range :500 {} 2>/dev/null || head -200 {}')"
  else
    file="$(find . -type f 2>/dev/null | fzf)"
  fi
  [[ -n "$file" ]] && "${EDITOR:-nvim}" "$file"
}

# Fuzzy kill by process list (default signal 9; pass 15 for SIGTERM).
fkill() {
  local pid sig="${1:-9}"
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found" >&2
    return 1
  fi
  pid="$(ps -ef | sed 1d | fzf -m --header 'Select process(es) to kill' | awk '{print $2}')"
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -"$sig"
}

# Fuzzy tldr page picker (needs tldr from tealdeer-install-update.sh).
ftldr() {
  if ! command -v tldr >/dev/null 2>&1; then
    echo "tldr not found. Run: dotfiles install devbox --tldr" >&2
    return 1
  fi
  if ! command -v fzf >/dev/null 2>&1; then
    tldr "$@"
    return $?
  fi
  if [[ $# -gt 0 ]]; then
    tldr "$@"
    return $?
  fi
  tldr --list | fzf --preview 'tldr {}' | xargs -r tldr
}

# Fuzzy ssh from ~/.ssh/config Host aliases (skips Host * and other patterns).
_dotfiles_ssh_config_hosts() {
  local config="${HOME}/.ssh/config"
  [[ -f "$config" ]] || return 1
  awk '
    /^[[:space:]]*Host[[:space:]]+/ {
      for (i = 2; i <= NF; i++) {
        if ($i !~ /[*?]/) print $i
      }
    }
  ' "$config"
}

fssh() {
  local host config="${HOME}/.ssh/config"
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found" >&2
    return 1
  fi
  if [[ ! -f "$config" ]]; then
    echo "no ~/.ssh/config (see ~/.dotfiles/home/.ssh/config.example)" >&2
    return 1
  fi
  host="$(
    _dotfiles_ssh_config_hosts | sort -u | fzf --prompt 'ssh> ' \
      --preview 'ssh -G {} 2>/dev/null | grep -v "^$" | head -40'
  )"
  [[ -n "$host" ]] && ssh "$host" "$@"
}

##### zoxide ############################################################

# Smarter cd with zoxide.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"

  alias cd="zd"

  zd() {
    if [ $# -eq 0 ]; then
      builtin cd ~ && return
    elif [ "$1" = "-" ]; then
      builtin cd - && return
    elif [ -d "$1" ]; then
      builtin cd "$1"
    else
      z "$@" && pwd || echo "Error: Directory not found"
    fi
  }
fi

##### fetch banner (fastfetch) ##########################################

_dotfiles_ff_banner() {
  local sh="${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch-banner.sh"
  if [[ -x "$sh" ]]; then
    "$sh"
  else
    command fastfetch
  fi
}

# No-arg fastfetch uses the same boxed config + selected art as tmux.
fastfetch() {
  if [[ $# -eq 0 ]]; then
    _dotfiles_ff_banner
  else
    command fastfetch "$@"
  fi
}

_dotfiles_show_fetch_banner() {
  [[ -n "${DOTFILES_FETCH_SHOWN:-}" || -n "${NO_FETCH:-}" ]] && return 0
  [[ -n "${TMUX:-}" ]] && return 0

  if command -v fastfetch >/dev/null 2>&1; then
    _dotfiles_ff_banner
    DOTFILES_FETCH_SHOWN=1
  fi
}

fetch() {
  if command -v fastfetch >/dev/null 2>&1; then
    _dotfiles_ff_banner
  else
    echo "fastfetch not installed. Run: ~/.dotfiles/install-fetch.sh"
  fi
}

_dotfiles_show_fetch_banner

##### eza / ls ##########################################################

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto --git'
  alias lsa='eza -lh --group-directories-first --icons=auto --git -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='eza --tree --level=2 --long --icons --git -a'
else
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi

##### grep ##############################################################

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

##### tmux ##############################################################

# Fresh CTs often start tmux while LANG is still C; -u forces UTF-8 drawing.
alias tmux='command tmux -u'

# Kitty SSH with terminfo sync. Extra command only; never override ssh.
# TERM=xterm-kitty on a remote host does not mean kitten is installed there.
if command -v kitten >/dev/null 2>&1; then
  alias sshk='kitten ssh'
fi

##### Navigation aliases ###############################################

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

mkcd() {
  mkdir -p -- "$1" && builtin cd -- "$1"
}

##### trash #############################################################

if command -v trash-put >/dev/null 2>&1; then
  alias del='trash-put'
fi

##### Desktop notification helper ######################################

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
