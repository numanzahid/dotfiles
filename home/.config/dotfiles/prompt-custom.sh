# Custom hostname:path prompt (Debian-style). No username.
# Linked as ~/.config/dotfiles/prompt.sh by ./install.sh (and copy-install).

# Set variable identifying the chroot.
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# Prompt path: full when short (<=2 dirs); else last 2 segments with "..." prefix.
# Full path stays in the window title below.
prompt_short_path() {
  local p parts=() n

  case "$PWD" in
    "$HOME") p='~' ;;
    "$HOME"/*) p="~${PWD#$HOME}" ;;
    *) p="$PWD" ;;
  esac

  if [[ "$p" == "~" ]]; then
    printf '~'
    return
  fi

  if [[ "$p" == "~/"* ]]; then
    IFS='/' read -ra parts <<< "${p:2}"
    if ((${#parts[@]} <= 2)); then
      printf '%s' "$p"
    else
      n=$((${#parts[@]} - 1))
      printf '.../%s/%s' "${parts[n - 1]}" "${parts[n]}"
    fi
    return
  fi

  if [[ "$p" == "/" ]]; then
    printf '/'
    return
  fi

  IFS='/' read -ra parts <<< "${p:1}"
  if ((${#parts[@]} <= 2)); then
    printf '%s' "$p"
  else
    n=$((${#parts[@]} - 1))
    printf '.../%s/%s' "${parts[n - 1]}" "${parts[n]}"
  fi
}

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\h\[\033[00m\]:\[\033[01;34m\]$(prompt_short_path)\[\033[00m\]\$ '

# Window title (xterm / SSH): hostname and directory only.
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\h: \w\a\]$PS1"
  ;;
esac
