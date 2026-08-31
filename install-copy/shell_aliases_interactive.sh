# ~/.shell_aliases_interactive.sh
# Interactive-only shell customizations for install-copy.
# No fzf, zoxide, or eza. Fastfetch banner uses the same boxed config.

# Main install used: alias cd="zd" (zoxide). source ~/.bashrc does not drop
# old aliases/functions, so cd would still call zoxide after a copy-install.
unalias cd z zi zd ff 2>/dev/null || true
unset -f zd z zi __zoxide_z __zoxide_zi 2>/dev/null || true

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
  local d

  if [[ "$hidden" == "1" ]]; then
    flags=(-lha --group-directories-first --color=auto)
  fi

  command ls "${flags[@]}" -- "$target"

  local nullglob_on=0 dotglob_on=0
  if shopt -q nullglob; then
    nullglob_on=1
  fi
  if shopt -q dotglob; then
    dotglob_on=1
  fi
  shopt -s nullglob
  if [[ "$hidden" == "1" ]]; then
    shopt -s dotglob
  fi
  for d in "$target"/*/ ; do
    [[ -d "$d" ]] || continue
    printf '\n%s:\n' "${d%/}"
    command ls "${flags[@]}" -- "$d"
  done
  if [[ "$nullglob_on" -eq 0 ]]; then
    shopt -u nullglob
  fi
  if [[ "$hidden" == "1" && "$dotglob_on" -eq 0 ]]; then
    shopt -u dotglob
  fi
}

# If lt/lta already exist as aliases (common: alias lt='ls -lt'), a function
# named lt() is a syntax error. Re-aliasing overwrites them.
unalias lt lta 2>/dev/null || true
_dotfiles_lt() { _ls_two_level 0 "${1:-.}"; }
_dotfiles_lta() { _ls_two_level 1 "${1:-.}"; }
alias lt='_dotfiles_lt'
alias lta='_dotfiles_lta'

##### fetch banner (fastfetch) ##########################################

_dotfiles_show_fetch_banner() {
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
    echo "fastfetch not installed. Run: ~/fastfetch-install-update.sh"
  fi
}

_dotfiles_show_fetch_banner

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
