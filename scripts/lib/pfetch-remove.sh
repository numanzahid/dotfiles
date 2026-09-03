#!/usr/bin/env bash
# Remove leftover pfetch from the old GitHub installer (dropped in 877a140).
# That script cloned dylanaraps/pfetch to /opt/pfetch and installed
# /usr/local/bin/pfetch. Copy-install also left ~/pfetch-install-update.sh
# and ~/.config/pfetch.
#
# Does not apt/dnf remove pfetch. Distro copies under /usr/bin are left alone.
# Callers must provide run() and (for system paths) df_ensure_sudo / df_run_privileged.

df_pfetch_home() {
  printf '%s' "${TARGET_HOME:-$HOME}"
}

df_pfetch_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$*"
  else
    printf '%s\n' "$*"
  fi
}

df_pfetch_is_apply() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 1
  fi
  if [[ "${APPLY:-1}" -eq 0 ]]; then
    return 1
  fi
  return 0
}

# True if a path is owned by dpkg/rpm (not our /usr/local GitHub install).
df_pfetch_owned_by_pkg() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 1
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -S "$path" >/dev/null 2>&1 && return 0
  fi
  if command -v rpm >/dev/null 2>&1; then
    rpm -qf "$path" >/dev/null 2>&1 && return 0
  fi
  return 1
}

df_pfetch_is_our_opt() {
  local url=""
  [[ -d /opt/pfetch ]] || return 1
  [[ -f /opt/pfetch/pfetch || -f /opt/pfetch/pfetch.sh ]] || return 1
  if [[ -d /opt/pfetch/.git ]] && command -v git >/dev/null 2>&1; then
    url="$(git -C /opt/pfetch remote get-url origin 2>/dev/null || true)"
    if [[ -n "$url" && "$url" != *dylanaraps/pfetch* ]]; then
      return 1
    fi
  fi
  return 0
}

df_pfetch_trash_home() {
  local dest="$1"
  [[ -e "$dest" || -L "$dest" ]] || return 0
  df_pfetch_log "remove leftover pfetch: $dest"
  if command -v trash-put >/dev/null 2>&1; then
    run trash-put "$dest"
  elif [[ -d "$dest" && ! -L "$dest" ]]; then
    run rm -rf "$dest"
  else
    run rm -f "$dest"
  fi
}

df_legacy_pfetch_system_present() {
  if [[ -e /usr/local/bin/pfetch || -L /usr/local/bin/pfetch ]] &&
    ! df_pfetch_owned_by_pkg /usr/local/bin/pfetch; then
    return 0
  fi
  df_pfetch_is_our_opt
}

df_legacy_pfetch_present() {
  local home
  home="$(df_pfetch_home)"
  df_legacy_pfetch_system_present && return 0
  [[ -e "$home/pfetch-install-update.sh" || -L "$home/pfetch-install-update.sh" ]] && return 0
  [[ -e "$home/pfetch-install-update.lib.sh" || -L "$home/pfetch-install-update.lib.sh" ]] && return 0
  [[ -e "$home/.install-scripts/pfetch-install-update.sh" ]] && return 0
  [[ -e "$home/.config/pfetch" || -L "$home/.config/pfetch" ]] && return 0
  [[ -e "$home/.config/tmux/fetch-pfetch.conf" ]] && return 0
  if [[ -f "$home/.config/tmux/fetch.conf" ]] && grep -q pfetch "$home/.config/tmux/fetch.conf"; then
    return 0
  fi
  return 1
}

df_remove_legacy_pfetch() {
  local home dest

  df_legacy_pfetch_present || return 0
  home="$(df_pfetch_home)"

  if df_legacy_pfetch_system_present; then
    if df_pfetch_is_apply; then
      df_ensure_sudo
    fi
    if [[ -e /usr/local/bin/pfetch || -L /usr/local/bin/pfetch ]]; then
      if df_pfetch_owned_by_pkg /usr/local/bin/pfetch; then
        df_pfetch_log "leave packaged pfetch: /usr/local/bin/pfetch"
      else
        df_pfetch_log "remove leftover pfetch: /usr/local/bin/pfetch"
        run df_run_privileged rm -f /usr/local/bin/pfetch
      fi
    fi
    if df_pfetch_is_our_opt; then
      df_pfetch_log "remove leftover pfetch: /opt/pfetch"
      run df_run_privileged rm -rf /opt/pfetch
    fi
  fi

  for dest in \
    "$home/pfetch-install-update.sh" \
    "$home/pfetch-install-update.lib.sh" \
    "$home/.install-scripts/pfetch-install-update.sh" \
    "$home/.config/pfetch" \
    "$home/.config/tmux/fetch-pfetch.conf"; do
    df_pfetch_trash_home "$dest"
  done

  dest="$home/.config/tmux/fetch.conf"
  if [[ -f "$dest" ]] && grep -q pfetch "$dest"; then
    df_pfetch_trash_home "$dest"
  fi
}
