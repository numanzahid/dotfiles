# ~/.shell_aliases_interactive.sh
# Interactive-only shell customizations for install-copy.
# No fzf, zoxide, eza, or fetch banners.

##### ls ################################################################

# Closest GNU ls stand-in for the eza aliases:
#   ls  = long, human sizes, dirs first, color
#   lsa = same, including hidden
#   lt  = two-level listing (eza --tree --level=2)
#   lta = same, including hidden
alias ls='command ls -lh --group-directories-first --color=auto'
alias lsa='command ls -lha --group-directories-first --color=auto'

_ls_two_level() {
  local hidden="$1"
  shift
  local target="${1:-.}"
  local flags=(-lh --group-directories-first --color=auto)
  local d old_nullglob old_dotglob

  if [[ "$hidden" == "1" ]]; then
    flags=(-lha --group-directories-first --color=auto)
  fi

  command ls "${flags[@]}" -- "$target"

  old_nullglob="$(shopt -p nullglob)"
  old_dotglob="$(shopt -p dotglob)"
  shopt -s nullglob
  if [[ "$hidden" == "1" ]]; then
    shopt -s dotglob
  fi
  for d in "$target"/*/ ; do
    [[ -d "$d" ]] || continue
    printf '\n%s:\n' "${d%/}"
    command ls "${flags[@]}" -- "$d"
  done
  eval "$old_nullglob"
  eval "$old_dotglob"
}

lt() { _ls_two_level 0 "${1:-.}"; }
lta() { _ls_two_level 1 "${1:-.}"; }

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
