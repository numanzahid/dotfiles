# One-line hostname:path prompt (devbox / server). No starship.
# Linked as ~/.config/dotfiles/prompt.sh by ./devbox.sh (and copy-install).
# Path truncation via PROMPT_COMMAND (faster than $(...) in PS1).
#
#   hostname:~

# Set variable identifying the chroot.
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# Prompt path: full when short (<=2 dirs); else last 2 segments with "..." prefix.
# Full path stays in the window title below.
prompt_update_dir() {
  local p parts=() n

  case "$PWD" in
    "$HOME") PROMPT_DIR='~'; return ;;
    "$HOME"/*) p="~${PWD#$HOME}" ;;
    *) p="$PWD" ;;
  esac

  if [[ "$p" == "~" ]]; then
    PROMPT_DIR='~'
    return
  fi

  if [[ "$p" == "~/"* ]]; then
    IFS='/' read -ra parts <<< "${p:2}"
    if ((${#parts[@]} <= 2)); then
      PROMPT_DIR="$p"
    else
      n=$((${#parts[@]} - 1))
      PROMPT_DIR=".../${parts[n - 1]}/${parts[n]}"
    fi
    return
  fi

  if [[ "$p" == "/" ]]; then
    PROMPT_DIR='/'
    return
  fi

  IFS='/' read -ra parts <<< "${p:1}"
  if ((${#parts[@]} <= 2)); then
    PROMPT_DIR="$p"
  else
    n=$((${#parts[@]} - 1))
    PROMPT_DIR=".../${parts[n - 1]}/${parts[n]}"
  fi
}

case "${PROMPT_COMMAND:-}" in
*prompt_update_dir*) ;;
'')
  PROMPT_COMMAND=prompt_update_dir
  ;;
*)
  PROMPT_COMMAND="prompt_update_dir; $PROMPT_COMMAND"
  ;;
esac

prompt_update_dir

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\h\[\033[00m\]:\[\033[01;34m\]${PROMPT_DIR}\[\033[00m\]\$ '

# Window title (xterm / SSH): hostname and directory only.
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\h: \w\a\]$PS1"
  ;;
esac
