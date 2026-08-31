# ~/.bashrc: executed by bash(1) for non-login shells.

# Fedora/RHEL: system bashrc (completions, umask). Missing on Debian: no-op.
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific environment (Fedora skel idiom). Harmless on Debian/Ubuntu.
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# OpenCode (only if installed; see ./install-ai-cli.sh).
if [ -d "$HOME/.opencode/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.opencode/bin:"*) ;;
    *) export PATH="$HOME/.opencode/bin:$PATH" ;;
  esac
fi

# Optional Rust/cargo (not installed by dotfiles by default).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export EDITOR="${EDITOR:-nvim}"
export COLORTERM=truecolor

# UTF-8 for interactive and `ssh host cmd` (tmux often inherits LANG=C from
# the session that ran before locale-gen).
if [ -f "$HOME/.config/dotfiles/locale.sh" ]; then
  . "$HOME/.config/dotfiles/locale.sh"
fi

# Stop here for non-interactive shells (scp/rsync/sftp/ssh host 'cmd').
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

##### Prompt ############################################################

# Active prompt is ~/.config/dotfiles/prompt.sh (custom or starship).
# Switch: ln -sfn ~/dotfiles/home/.config/dotfiles/prompt-custom.sh ~/.config/dotfiles/prompt.sh
#     or: ln -sfn ~/dotfiles/home/.config/dotfiles/prompt-starship.sh ~/.config/dotfiles/prompt.sh
if [ -f ~/.config/dotfiles/prompt.sh ]; then
  . ~/.config/dotfiles/prompt.sh
fi

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

##### nvm ###############################################################

export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi

if [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi

##### User bashrc.d (Fedora convention; no-op if the directory is empty) #

if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

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
