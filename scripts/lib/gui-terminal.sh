#!/usr/bin/env bash
# Desktop launcher + default-terminal helpers for GUI terminal installers.

df_os_family() {
  case "$(df_host_os_id)" in
    fedora) printf 'fedora\n' ;;
    ubuntu | debian | linuxmint | pop) printf 'debian\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

df_desktop_file_exists() {
  local name="$1"
  [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/${name}" ]] && return 0
  [[ -f "/usr/share/applications/${name}" ]] && return 0
  [[ -f "/usr/local/share/applications/${name}" ]] && return 0
  return 1
}

# $1 = desktop file basename (Alacritty.desktop)
# $2 = source .desktop path (copied only if missing)
df_ensure_user_desktop() {
  local name="$1"
  local src="$2"
  local dest="${XDG_DATA_HOME:-$HOME/.local/share}/applications/${name}"

  df_desktop_file_exists "$name" && return 0
  [[ -f "$src" ]] || return 1
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
  printf 'desktop: %s\n' "$dest"
}

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

# $1 = binary name (alacritty / ghostty / kitty)
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
