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
    elif [ "$1" = "-" ]; then
      builtin cd - && return
    elif [ -d "$1" ]; then
      builtin cd "$1"
    else
      z "$@" && pwd || echo "Error: Directory not found"
    fi
  }
fi

##### fetch banner (fastfetch / pfetch) #################################

export PF_SOURCE="${XDG_CONFIG_HOME:-$HOME}/.config/pfetch/pfetchrc"

_dotfiles_fetch_mode() {
  local conf="${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fetch.conf"
  local target

  if [[ ! -e "$conf" ]]; then
    echo none
    return 0
  fi

  target="$(readlink -f "$conf" 2>/dev/null || readlink "$conf" 2>/dev/null || true)"
  case "$(basename "${target:-}")" in
    fetch-fastfetch.conf) echo fastfetch ;;
    fetch-pfetch.conf) echo pfetch ;;
    *) echo none ;;
  esac
}

_dotfiles_show_fetch_banner() {
  # Once per shell. Inside tmux, pane bindings run fetch explicitly and set
  # NO_FETCH=1 so login shells spawned by those bindings do not run it again.
  [[ -n "${DOTFILES_FETCH_SHOWN:-}" || -n "${NO_FETCH:-}" ]] && return 0
  [[ -n "${TMUX:-}" ]] && return 0

  local mode
  mode="$(_dotfiles_fetch_mode)"

  case "$mode" in
    fastfetch)
      if command -v fastfetch >/dev/null 2>&1; then
        fastfetch --config "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch.jsonc"
        DOTFILES_FETCH_SHOWN=1
      fi
      ;;
    pfetch)
      if command -v pfetch >/dev/null 2>&1; then
        pfetch
        DOTFILES_FETCH_SHOWN=1
      fi
      ;;
  esac
}

fetch() {
  local mode
  mode="$(_dotfiles_fetch_mode)"
  case "$mode" in
    fastfetch)
      command -v fastfetch >/dev/null 2>&1 &&
        fastfetch --config "${XDG_CONFIG_HOME:-$HOME}/.config/tmux/fastfetch.jsonc"
      ;;
    pfetch)
      command -v pfetch >/dev/null 2>&1 && pfetch
      ;;
    *)
      echo "fetch banner disabled (mode: none). Run: ~/dotfiles/install-fetch.sh"
      ;;
  esac
}

_dotfiles_show_fetch_banner

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
alias -- -='cd -'

mkcd() {
  mkdir -p -- "$1" && builtin cd -- "$1"
}

##### Desktop notification helper ######################################

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
