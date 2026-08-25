# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# UTF-8 locale (minimal Debian/CT images often default to C/POSIX).
if [ -z "${LANG:-}" ] || [ "$LANG" = "C" ] || [ "$LANG" = "POSIX" ]; then
  if locale -a 2>/dev/null | grep -qE 'en_US\.(utf8|UTF-8)'; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
  fi
fi

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
# Optional Rust/cargo (not installed by dotfiles by default).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Debian/Proxmox skel: do not allow write/wall to this terminal.
mesg n 2> /dev/null || true
