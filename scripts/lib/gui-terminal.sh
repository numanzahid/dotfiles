#!/usr/bin/env bash
# Desktop launcher + default-terminal helpers for GUI terminal installers.

GUI_TERM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=journal.sh
if [[ -f "$GUI_TERM_LIB_DIR/journal.sh" ]]; then
  source "$GUI_TERM_LIB_DIR/journal.sh"
fi

# $1 = icon basename without path (Alacritty.svg)
# $2 = source svg
df_ensure_user_icon() {
  local name="$1"
  local src="$2"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/${name}"

  [[ -f "$dest" || -f "/usr/share/icons/hicolor/scalable/apps/${name}" ]] && return 0
  [[ -f "$src" ]] || return 1
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once copy "$dest" "$src"
  fi
  printf 'icon: %s\n' "$dest"
}

df_refresh_desktop_db() {
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "$dir" ]]; then
    update-desktop-database "$dir" 2>/dev/null || true
  fi
}

# $1 = binary name (alacritty / kitty)
# $2 = desktop file basename
df_set_default_terminal() {
  local bin="$1"
  local desktop="$2"
  local path

  path="$(command -v "$bin" || true)"
  if [[ -z "$path" ]]; then
    echo "WARN: $bin not on PATH; skip default terminal" >&2
    return 0
  fi

  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
  dest="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"
  printf '%s\n' "$desktop" >"$dest"
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once copy "$dest" "dotfiles-default-terminal-list"
  fi
  printf 'default terminal list: %s\n' "$desktop"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec "$bin" 2>/dev/null || true
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' 2>/dev/null || true
    if declare -F df_journal_once >/dev/null 2>&1; then
      df_journal_once gsettings-key "default-terminal"
    fi
    printf 'gsettings terminal exec: %s\n' "$bin"
  fi

  if command -v update-alternatives >/dev/null 2>&1 && [[ "$path" == /usr/bin/* || "$path" == /usr/local/bin/* ]]; then
    df_ensure_sudo
    df_run_privileged update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$path" 50
    df_run_privileged update-alternatives --set x-terminal-emulator "$path"
    printf 'x-terminal-emulator: %s\n' "$path"
  fi

  df_gnome_bind_super_enter_terminal
}

df_gnome_has_custom_keybinding_schema() {
  command -v gsettings >/dev/null 2>&1 || return 1
  gsettings list-relocatable-schemas 2>/dev/null |
    grep -qx 'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding'
}

# GNOME session, or gnome-shell installed (next graphical login).
df_gnome_desktop_available() {
  df_gnome_has_custom_keybinding_schema || return 1
  case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME* | *gnome*) return 0 ;;
  esac
  command -v gnome-shell >/dev/null 2>&1
}

df_install_default_terminal_launcher() {
  local src dest
  src="${GUI_TERM_LIB_DIR}/../data/dotfiles-default-terminal"
  dest="${HOME}/.local/bin/dotfiles-default-terminal"
  [[ -f "$src" ]] || {
    echo "WARN: missing launcher source: $src" >&2
    return 1
  }
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
  chmod 755 "$dest"
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once copy "$dest" "$src"
  fi
  printf 'default terminal launcher: %s\n' "$dest"
}

# Super+Enter opens ~/.local/bin/dotfiles-default-terminal (last Alacritty/Kitty wins).
# No-op when GNOME is not present. Does not wipe other custom keybindings.
df_gnome_bind_super_enter_terminal() {
  local kb custom_schema custom_path list new dest

  if ! df_gnome_desktop_available; then
    echo "skip GNOME Super+Enter (GNOME not present)"
    return 0
  fi

  df_install_default_terminal_launcher || return 0
  dest="${HOME}/.local/bin/dotfiles-default-terminal"

  kb="org.gnome.settings-daemon.plugins.media-keys"
  custom_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  custom_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dotfiles-terminal/"

  list="$(gsettings get "$kb" custom-keybindings)"
  if [[ "$list" != *"dotfiles-terminal/"* ]]; then
    if [[ "$list" == "@as []" || "$list" == "[]" ]]; then
      new="['${custom_path}']"
    else
      new="${list/%]/, '${custom_path}']}"
    fi
    gsettings set "$kb" custom-keybindings "$new"
  fi

  gsettings set "${custom_schema}:${custom_path}" name 'Default terminal'
  gsettings set "${custom_schema}:${custom_path}" command "$dest"
  gsettings set "${custom_schema}:${custom_path}" binding '<Super>Return'
  printf 'GNOME Super+Enter: %s\n' "$dest"
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once gsettings-key "dotfiles-terminal"
  fi
}

# Undo df_gnome_bind_super_enter_terminal for one binding id (e.g. dotfiles-terminal).
df_gnome_unbind_custom_keybinding() {
  local binding_id="$1"
  local kb custom_schema custom_path list new

  [[ -n "$binding_id" ]] || return 0

  case "$binding_id" in
    default-terminal)
      if command -v gsettings >/dev/null 2>&1; then
        gsettings reset org.gnome.desktop.default-applications.terminal exec 2>/dev/null || true
        gsettings reset org.gnome.desktop.default-applications.terminal exec-arg 2>/dev/null || true
      fi
      return 0
      ;;
  esac

  if ! df_gnome_has_custom_keybinding_schema; then
    return 0
  fi

  kb="org.gnome.settings-daemon.plugins.media-keys"
  custom_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  custom_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${binding_id}/"

  gsettings reset-recursively "${custom_schema}:${custom_path}" 2>/dev/null || true

  list="$(gsettings get "$kb" custom-keybindings 2>/dev/null || true)"
  [[ -n "$list" ]] || return 0
  if [[ "$list" != *"${binding_id}/"* ]]; then
    return 0
  fi

  new="$(printf '%s' "$list" | sed -E \
    -e "s|, '${custom_path}'||g" \
    -e "s|'${custom_path}', ||g" \
    -e "s|'${custom_path}'||g")"
  case "$new" in
    "[]" | "@as []") new="@as []" ;;
  esac
  gsettings set "$kb" custom-keybindings "$new" 2>/dev/null || true
}
