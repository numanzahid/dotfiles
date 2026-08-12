# ~/.shell_aliases_interactive.sh
# Interactive-only shell customizations.
# This file is sourced from ~/.bashrc only for real interactive terminals.

##### fzf ###############################################################

# Set up fzf key bindings and fuzzy completion.
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

##### zoxide ############################################################

# Smarter cd with zoxide.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"

  alias cd="zd"

  zd() {
    if [ $# -eq 0 ]; then
      builtin cd ~ && return
    elif [ -d "$1" ]; then
      builtin cd "$1"
    else
      z "$@" && pwd || echo "Error: Directory not found"
    fi
  }
fi

##### pfetch ############################################################

export PF_SOURCE="${XDG_CONFIG_HOME:-$HOME/.config}/pfetch/pfetchrc"

##### eza / ls ##########################################################

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto --git .'
  alias lsa='eza -lh --group-directories-first --icons=auto --git -a .'
  alias lt='eza --tree --level=2 --long --icons --git .'
  alias lta='eza --tree --level=2 --long --icons --git -a .'
else
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi

##### grep ##############################################################

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

##### Navigation aliases ###############################################

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

##### Desktop notification helper ######################################

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

##### chafa #############################################################

if command -v chafa >/dev/null 2>&1; then
  alias chafa='chafa -c full'
fi
