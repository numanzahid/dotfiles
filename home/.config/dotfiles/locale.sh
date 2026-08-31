# UTF-8 locale for SSH/tmux on minimal Debian CTs (often start as C/POSIX).
# LANG is the default. Do not set LC_ALL: it overrides every LC_* and
# leaks into `pct enter` / LXC attach on the host.
#
# Sourced from ~/.profile and ~/.bashrc. Safe to source more than once.

_df_locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
case "$_df_locale" in
  *.[Uu][Tt][Ff][-]*8* | *.[Uu][Tt][Ff]8*) ;;
  *)
    if locale -a 2>/dev/null | grep -qE 'en_US\.(utf8|UTF-8)'; then
      LANG=en_US.UTF-8
      export LANG
    elif locale -a 2>/dev/null | grep -qE 'C\.(utf8|UTF-8)'; then
      LANG=C.UTF-8
      export LANG
    fi
    ;;
esac
unset _df_locale
unset LC_ALL
