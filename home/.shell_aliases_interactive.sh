# ~/.shell_aliases_interactive.sh
# Interactive-only shell customizations.
# This file is sourced from ~/.bashrc only for real interactive terminals.

##### fzf ###############################################################

# Set up fzf key bindings and fuzzy completion.
# Git installer writes ~/.fzf.bash. Fedora dnf fzf uses `fzf --bash`.
if [ -f ~/.fzf.bash ]; then
  source ~/.fzf.bash
elif command -v fzf >/dev/null 2>&1; then
  _dotfiles_fzf_bash="$(fzf --bash 2>/dev/null)" && eval "$_dotfiles_fzf_bash"
  unset _dotfiles_fzf_bash
fi

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

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

_dotfiles_show_fetch_banner() {
  # Once per shell. Inside tmux, pane bindings run fetch explicitly and set
  # NO_FETCH=1 so login shells spawned by those bindings do not run it again.
  [[ -n "${DOTFILES_FETCH_SHOWN:-}" || -n "${NO_FETCH:-}" ]] && return 0
  [[ -n "${TMUX:-}" ]] && return 0

  if command -v fastfetch >/dev/null 2>&1; then
    if [[ -x "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch-banner.sh" ]]; then
      "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch-banner.sh"
    else
      fastfetch --config "${XDG_CONFIG_HOME:-$HOME}/.config/fastfetch/banner.jsonc"
    fi
    DOTFILES_FETCH_SHOWN=1
  fi
}

fetch() {
  if command -v fastfetch >/dev/null 2>&1; then
    if [[ -x "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch-banner.sh" ]]; then
      "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch-banner.sh"
    else
      fastfetch --config "${XDG_CONFIG_HOME:-$HOME}/.config/fastfetch/banner.jsonc"
    fi
  else
    echo "fastfetch not installed. Run: ~/dotfiles/install-fetch.sh"
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
