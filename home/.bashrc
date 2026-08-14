# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, do not do anything.
case $- in
*i*) ;;
*) return ;;
esac

##### Bash history ######################################################

# Do not put duplicate lines or lines starting with space in history.
HISTCONTROL=ignoreboth

# Append to the history file, do not overwrite it.
shopt -s histappend

# History size.
HISTSIZE=1000
HISTFILESIZE=2000

##### Shell behavior ####################################################

# Check window size after each command and update LINES/COLUMNS.
shopt -s checkwinsize

# Make less more friendly for non-text input files.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

##### Terminal color and Prompt ##########################################

export COLORTERM=truecolor

# Set variable identifying the chroot.
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# Short multi-line prompt.
PS1='\[\e[38;5;208m\]┌──[\[\e[94m\]\w\[\e[38;5;208m\]]\n└─\$\[\e[0m\] '

# If this is an xterm/rxvt-compatible terminal, set title to user@host:dir.
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
esac

##### Bash aliases ######################################################

# Keep normal bash_aliases support.
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

##### Completion ########################################################

# Enable programmable completion.
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

##### Environment #######################################################

# Default editor.
export EDITOR=nvim

# User-local binaries.
export PATH="$HOME/.local/bin:$PATH"

# opencode.
export PATH="$HOME/.opencode/bin:$PATH"

# Optional Rust/cargo (not installed by dotfiles by default).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# nvm.
export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi

if [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi

##### Interactive-only customizations ###################################

# Load visual/terminal-only customizations.
# This includes aliases, fzf, zoxide, eza, fetch banner, etc.
if [[ $- == *i* ]] && [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  [ -f ~/.shell_aliases_interactive.sh ] && source ~/.shell_aliases_interactive.sh
fi

##### tmux autostart ####################################################

# Autostart tmux over SSH unless disabled.
# Disable temporarily with: NO_TMUX=1 ssh host
if command -v tmux >/dev/null 2>&1 &&
  [ -z "${TMUX:-}" ] &&
  [ -n "${SSH_CONNECTION:-}" ] &&
  [ -z "${NO_TMUX:-}" ] &&
  [ "${TERM:-}" != "dumb" ]; then
  if tmux ls >/dev/null 2>&1; then
    tmux attach-session
  else
    tmux new-session -s default
  fi
fi
