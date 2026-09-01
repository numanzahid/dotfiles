#!/usr/bin/env bash
# Desktop launcher + default-terminal helpers for GUI terminal installers.

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
  printf '%s\n' "$desktop" >"${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list"
  printf 'default terminal list: %s\n' "$desktop"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec "$bin" 2>/dev/null || true
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' 2>/dev/null || true
    printf 'gsettings terminal exec: %s\n' "$bin"
  fi

  if command -v update-alternatives >/dev/null 2>&1 && [[ "$path" == /usr/bin/* || "$path" == /usr/local/bin/* ]]; then
    df_ensure_sudo
    df_run_privileged update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$path" 50
    df_run_privileged update-alternatives --set x-terminal-emulator "$path"
    printf 'x-terminal-emulator: %s\n' "$path"
  fi
}
