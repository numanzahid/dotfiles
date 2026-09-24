#!/usr/bin/env bash
set -euo pipefail

# Install Syncthing for the current user (~/.local/bin) with systemd user autostart.
# User-owned binary so in-app upgrades work without sudo.
# GUI defaults to loopback-only; --expose-lan opts into 0.0.0.0 (LAN/Tailscale).
# Optional; not part of --all.
#
# Same install path on Ubuntu, Debian, Fedora, Arch/Omarchy, and other systemd
# Linux: official GitHub tarball (not apt/dnf/pacman packages).
#
# https://docs.syncthing.net/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="${HOME}/.local/bin/syncthing"
UNIT_SRC="${SCRIPT_DIR}/data/systemd/user/syncthing.service"
UNIT_DEST="${HOME}/.config/systemd/user/syncthing.service"
SYSTEM_UNIT_TEMPLATE="${SCRIPT_DIR}/data/systemd/system/syncthing-user.service.template"
SYSTEM_UNIT_DEST="/etc/systemd/system/syncthing-${USER}.service"
SYNCTHING_HOME="${HOME}/.local/share/syncthing"
AUTOSTART_MODE="" # user | system
CONFIG_XML="${SYNCTHING_HOME}/config.xml"
REPO="syncthing/syncthing"
GUI_PORT="8384"
GUI_LOCAL_ADDRESS="127.0.0.1:${GUI_PORT}"
GUI_LAN_ADDRESS="0.0.0.0:${GUI_PORT}"
EXPOSE_MODE="" # "" (decide below) | local | lan
GUI_ADDRESS=""

usage() {
  cat <<'EOF'
Usage: ./scripts/syncthing-install-update.sh [options]

Install or upgrade Syncthing from official GitHub releases into ~/.local/bin
(user-writable, so Syncthing can auto-upgrade without sudo).

Also:
  - Generates config on first install (~/.local/share/syncthing)
  - GUI defaults to loopback-only (127.0.0.1:8384). Pass --expose-lan to bind
    0.0.0.0 (reachable over LAN/Tailscale) instead, or --local-only to be
    explicit. With neither flag: interactive first install prompts; a
    non-interactive first install defaults to loopback-only. Re-running on an
    already-configured install leaves the GUI address alone unless you pass
    one of these flags.
  - Autostart via systemd user unit (default), or --system-service on LXC/CTs
    where user@UID.service does not work

Not tied to devbox/server/desktop.

Tested distros: Ubuntu, Debian, Fedora, Arch Linux (and Omarchy). Does not use
distro packages.

Needs: curl, jq, tar, systemctl. User units also need loginctl + working
systemctl --user. --system-service needs sudo for /etc/systemd/system/.
Package examples if tools are missing:
  Debian/Ubuntu: sudo apt install curl jq tar
  Fedora:        sudo dnf install curl jq tar
  Arch:          sudo pacman -S curl jq tar

Options:
  --local-only Bind GUI to 127.0.0.1 only (default)
  --expose-lan Bind GUI to 0.0.0.0 (LAN and Tailscale reachable)
  --system-service
      Use a system unit (syncthing-USER.service) running as you. For headless
      LXC/Proxmox CTs when user@UID.service fails. Binary stays in ~/.local/bin.
  --status     Show install/service/config summary (no changes)
  --uninstall  Stop service, remove unit and binary (keeps ~/.../syncthing data)
  --purge      With --uninstall, also remove ~/.local/share/syncthing
  --dry-run    Print actions only
  --yes, -y    Skip confirmation prompts
  -h, --help   Show this help

After install: open http://<host-ip>:8384 and set a GUI username/password.
EOF
}

log() {
  printf '[syncthing] %s\n' "$*"
}

run() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"
# shellcheck source=lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"

_df_entry=0
DF_INSTALL_ALLOW_EXTRA=1
df_install_cli_entry "$@" || _df_entry=$?
DRY_RUN="${DF_INSTALL_DRY_RUN:-0}"
export DRY_RUN

case "$_df_entry" in
  1)
    # --uninstall handled below after parse_extra
    ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

STATUS_ONLY=0
PURGE_DATA=0
USE_SYSTEM_SERVICE=0
while [[ ${#DF_INSTALL_EXTRA_ARGS[@]} -gt 0 ]]; do
  case "${DF_INSTALL_EXTRA_ARGS[0]}" in
    --status) STATUS_ONLY=1 ;;
    --purge) PURGE_DATA=1 ;;
    --system-service) USE_SYSTEM_SERVICE=1 ;;
    --local-only) EXPOSE_MODE=local ;;
    --expose-lan) EXPOSE_MODE=lan ;;
    *)
      echo "Unknown option: ${DF_INSTALL_EXTRA_ARGS[0]}" >&2
      usage >&2
      exit 1
      ;;
  esac
  DF_INSTALL_EXTRA_ARGS=("${DF_INSTALL_EXTRA_ARGS[@]:1}")
done

if [[ "$DF_INSTALL_WANTS_UNINSTALL" -eq 1 ]]; then
  df_inst_run_uninstall syncthing uninstall_syncthing
  exit 0
fi

gr_require_cmds curl jq tar systemctl

user_systemd_available() {
  if [[ -z "${XDG_RUNTIME_DIR:-}" ]] && [[ -d "/run/user/$(id -u)" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  fi
  systemctl --user show-environment >/dev/null 2>&1
}

fail_user_systemd() {
  echo "ERROR: systemd user manager is not running (systemctl --user fails)." >&2
  echo "  SSH is fine; this is common on LXC/CTs when user@$(id -u).service will not start." >&2
  echo "  Diagnose (root): systemctl status user@$(id -u).service" >&2
  echo "                   journalctl -xeu user@$(id -u).service" >&2
  echo "  Use system autostart instead (binary still in ~/.local/bin):" >&2
  echo "    ./scripts/syncthing-install-update.sh --system-service" >&2
  exit 1
}

resolve_autostart_mode() {
  if [[ "$USE_SYSTEM_SERVICE" -eq 1 ]]; then
    AUTOSTART_MODE=system
    return 0
  fi
  if user_systemd_available; then
    AUTOSTART_MODE=user
    return 0
  fi
  fail_user_systemd
}

ensure_user_systemd() {
  if [[ "$AUTOSTART_MODE" != user ]]; then
    return 0
  fi
  if ! user_systemd_available; then
    fail_user_systemd
  fi
  gr_require_cmds loginctl
}

syncthing_primary_ipv4() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "$ip" ]]; then
    printf '%s' "$ip"
    return 0
  fi
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
    [[ -n "$ip" ]] && printf '%s' "$ip"
  fi
}

syncthing_linux_asset() {
  local tag="$1"
  local arch raw
  raw="$(gr_arch_raw)" || exit 1
  case "$raw" in
    amd64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    armv7 | armv6) arch="arm" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
  # Release files use the tag in the name, e.g. syncthing-linux-amd64-v2.1.5.tar.gz
  printf 'syncthing-linux-%s-%s.tar.gz' "$arch" "$tag"
}

# Current bound GUI address as it actually is in config.xml right now
# (independent of what this run may plan to set it to). Must scope to the
# <gui> block specifically: config.xml also has a sync-listen <address>
# (typically the literal string "dynamic") and a relay-pool <address>, both
# of which appear before the GUI's own <address> tag.
syncthing_configured_gui_address() {
  [[ -f "$CONFIG_XML" ]] || return 1
  awk '/<gui /{f=1} f && /<address>/{print; exit} /<\/gui>/{f=0}' "$CONFIG_XML" 2>/dev/null |
    grep -oP '(?<=<address>)[^<]+'
}

syncthing_gui_exposed_lan() {
  local addr
  addr="$(syncthing_configured_gui_address || true)"
  [[ "$addr" == 0.0.0.0:* || "$addr" == \[::\]:* ]]
}

# Decide the GUI bind address for this run. An explicit --local-only/
# --expose-lan flag always wins. With neither flag: on an already-configured
# install we leave the address alone (so we never silently revert a change
# made by hand through the Syncthing UI on a routine `dotfiles update`); on a
# brand-new install we ask interactively, or default to loopback-only when
# there's no terminal to ask.
resolve_gui_address() {
  case "$EXPOSE_MODE" in
    local)
      GUI_ADDRESS="$GUI_LOCAL_ADDRESS"
      return 0
      ;;
    lan)
      GUI_ADDRESS="$GUI_LAN_ADDRESS"
      return 0
      ;;
  esac

  if [[ -f "$CONFIG_XML" ]]; then
    GUI_ADDRESS=""
    return 0
  fi

  if [[ -t 0 ]]; then
    cat <<EOF

Syncthing GUI network exposure:
  1) Local only     127.0.0.1:${GUI_PORT} (default; reach it via SSH port-forward
                     or Tailscale Serve)
  2) LAN/Tailscale  0.0.0.0:${GUI_PORT} (reachable from your network; set a GUI
                     password immediately after install)
EOF
    local choice=""
    read -r -p "Select [1-2] (default 1): " choice
    case "${choice:-1}" in
      2) GUI_ADDRESS="$GUI_LAN_ADDRESS" ;;
      *) GUI_ADDRESS="$GUI_LOCAL_ADDRESS" ;;
    esac
  else
    log "no --local-only/--expose-lan given and no terminal to prompt; defaulting to loopback-only (${GUI_LOCAL_ADDRESS})"
    GUI_ADDRESS="$GUI_LOCAL_ADDRESS"
  fi
}

syncthing_gui_address_in_config() {
  [[ -n "$GUI_ADDRESS" ]] || return 1
  [[ "$(syncthing_configured_gui_address || true)" == "$GUI_ADDRESS" ]]
}

syncthing_set_gui_in_config() {
  [[ -n "$GUI_ADDRESS" ]] || return 0
  if [[ ! -f "$CONFIG_XML" ]]; then
    return 0
  fi
  if syncthing_gui_address_in_config; then
    return 0
  fi
  log "setting GUI listen address to ${GUI_ADDRESS} in config.xml"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    echo "+ sed -i (gui block only) address -> ${GUI_ADDRESS} in $CONFIG_XML"
    return 0
  fi
  # Scoped to the <gui>...</gui> range only -- config.xml also has a
  # sync-listen <address> ("dynamic") and a relay-pool <address> that must
  # not be touched.
  sed -i "/<gui /,/<\\/gui>/ s|<address>[^<]*</address>|<address>${GUI_ADDRESS}</address>|" "$CONFIG_XML"
}

syncthing_ensure_config() {
  resolve_gui_address
  if [[ -f "$CONFIG_XML" ]]; then
    syncthing_set_gui_in_config
    return 0
  fi
  log "generating Syncthing config in $SYNCTHING_HOME"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    run mkdir -p "$SYNCTHING_HOME"
    run "$BIN_PATH" generate --no-port-probing --home="$SYNCTHING_HOME"
    return 0
  fi
  mkdir -p "$SYNCTHING_HOME"
  "$BIN_PATH" generate --no-port-probing --home="$SYNCTHING_HOME"
  syncthing_set_gui_in_config
}

install_systemd_unit() {
  if [[ ! -f "$UNIT_SRC" ]]; then
    echo "ERROR: missing unit template: $UNIT_SRC" >&2
    exit 1
  fi
  log "installing user systemd unit: $UNIT_DEST"
  run mkdir -p "$(dirname "$UNIT_DEST")"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    run cp "$UNIT_SRC" "$UNIT_DEST"
  else
    cp "$UNIT_SRC" "$UNIT_DEST"
  fi
}

linger_enabled() {
  loginctl show-user "$USER" -p Linger --value 2>/dev/null | grep -qi '^yes$'
}

enable_linger() {
  if linger_enabled; then
    log "systemd linger already enabled for $USER"
    return 0
  fi
  log "enabling systemd linger (starts user services at boot without login)"
  df_ensure_sudo
  run df_run_privileged loginctl enable-linger "$USER"
}

start_syncthing_user_service() {
  run systemctl --user daemon-reload
  run systemctl --user enable syncthing.service
  run systemctl --user restart syncthing.service
}

install_system_service_unit() {
  local tmp group
  if [[ ! -f "$SYSTEM_UNIT_TEMPLATE" ]]; then
    echo "ERROR: missing $SYSTEM_UNIT_TEMPLATE" >&2
    exit 1
  fi
  group="$(id -gn)"
  log "installing system unit: $SYSTEM_UNIT_DEST (runs as $USER)"
  df_ensure_sudo
  tmp="$(mktemp)"
  sed \
    -e "s|@USER@|${USER}|g" \
    -e "s|@GROUP@|${group}|g" \
    -e "s|@HOME@|${HOME}|g" \
    -e "s|@BIN@|${BIN_PATH}|g" \
    "$SYSTEM_UNIT_TEMPLATE" >"$tmp"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    run df_run_privileged install -m 644 "$tmp" "$SYSTEM_UNIT_DEST"
  else
    df_run_privileged install -m 644 "$tmp" "$SYSTEM_UNIT_DEST"
  fi
  rm -f "$tmp"
}

remove_system_service_unit() {
  if [[ -f "$SYSTEM_UNIT_DEST" ]]; then
    run df_run_privileged systemctl disable --now "syncthing-${USER}.service" 2>/dev/null || true
    run df_run_privileged rm -f "$SYSTEM_UNIT_DEST"
    run df_run_privileged systemctl daemon-reload
  fi
}

remove_user_service_unit() {
  if systemctl --user is-active syncthing.service >/dev/null 2>&1; then
    run systemctl --user stop syncthing.service
  fi
  run systemctl --user disable syncthing.service 2>/dev/null || true
  if [[ -f "$UNIT_DEST" ]]; then
    run rm -f "$UNIT_DEST"
    run systemctl --user daemon-reload 2>/dev/null || true
  fi
}

start_syncthing_system_service() {
  df_ensure_sudo
  run df_run_privileged systemctl daemon-reload
  run df_run_privileged systemctl enable "syncthing-${USER}.service"
  run df_run_privileged systemctl restart "syncthing-${USER}.service"
}

start_syncthing_service() {
  if [[ "$AUTOSTART_MODE" == system ]]; then
    if user_systemd_available; then
      remove_user_service_unit
    elif [[ -f "$UNIT_DEST" ]]; then
      run rm -f "$UNIT_DEST"
    fi
    install_system_service_unit
    start_syncthing_system_service
  else
    remove_system_service_unit
    install_systemd_unit
    enable_linger
    start_syncthing_user_service
  fi
}

print_access_hints() {
  local ts_ip lan_ip
  cat <<EOF

Syncthing GUI (set username/password on first visit):
  http://127.0.0.1:${GUI_PORT}
EOF
  if syncthing_gui_exposed_lan; then
    lan_ip="$(syncthing_primary_ipv4)"
    if [[ -n "$lan_ip" ]]; then
      echo "  http://${lan_ip}:${GUI_PORT}  (LAN)"
    fi
    if command -v tailscale >/dev/null 2>&1; then
      ts_ip="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
      if [[ -n "$ts_ip" ]]; then
        echo "  http://${ts_ip}:${GUI_PORT}  (Tailscale)"
      fi
    fi
    print_firewall_hint
  else
    echo "  (loopback-only; re-run with --expose-lan to bind LAN/Tailscale too)"
  fi
  cat <<EOF

EOF
  if [[ "$AUTOSTART_MODE" == system ]]; then
    cat <<EOF
Service:  sudo systemctl status syncthing-${USER}
Logs:     sudo journalctl -u syncthing-${USER} -e
EOF
  else
    cat <<EOF
Service:  systemctl --user status syncthing
Logs:     journalctl --user-unit=syncthing -e
EOF
  fi
  echo "Upgrade:  use Syncthing web UI (binary in ~/.local/bin is user-writable)"
}

print_firewall_hint() {
  if command -v firewall-cmd >/dev/null 2>&1 &&
    systemctl is-active firewalld.service >/dev/null 2>&1; then
    echo
    echo "firewalld: allow GUI and sync if remote access fails:"
    echo "  sudo firewall-cmd --permanent --add-port=8384/tcp"
    echo "  sudo firewall-cmd --permanent --add-port=22000/tcp"
    echo "  sudo firewall-cmd --reload"
    return 0
  fi
  if command -v ufw >/dev/null 2>&1 &&
    ufw status 2>/dev/null | grep -qi 'Status: active'; then
    echo
    echo "ufw: allow GUI and sync if remote access fails:"
    echo "  sudo ufw allow 8384/tcp"
    echo "  sudo ufw allow 22000/tcp"
    return 0
  fi
  echo
  echo "If a host firewall blocks access, allow TCP 8384 (GUI) and 22000 (sync)."
  echo "  Fedora often uses firewalld; Debian/Ubuntu may use ufw; Arch may use nftables."
}

print_status() {
  echo -n "Binary:   ${BIN_PATH}"
  if [[ -x "$BIN_PATH" ]]; then
    echo " ($(syncthing --version 2>&1 | head -n1))"
  else
    echo " (missing)"
  fi
  echo "Config:   $CONFIG_XML"
  if [[ -f "$CONFIG_XML" ]]; then
    local configured
    configured="$(syncthing_configured_gui_address || true)"
    if [[ -n "$configured" ]]; then
      if syncthing_gui_exposed_lan; then
        echo "GUI:      ${configured} (LAN/Tailscale exposed; --local-only to restrict)"
      else
        echo "GUI:      ${configured} (loopback-only; --expose-lan to open to LAN)"
      fi
    else
      echo "GUI:      check config.xml"
    fi
  fi
  if [[ -f "$SYSTEM_UNIT_DEST" ]]; then
    AUTOSTART_MODE=system
    echo "Autostart: system ($SYSTEM_UNIT_DEST)"
  elif [[ -f "$UNIT_DEST" ]]; then
    AUTOSTART_MODE=user
    echo "Autostart: user ($UNIT_DEST)"
    echo "Linger:   $(linger_enabled && echo yes || echo no)"
  else
    echo "Autostart: (none)"
  fi
  if [[ -f "$SYSTEM_UNIT_DEST" ]]; then
    if systemctl is-active "syncthing-${USER}.service" >/dev/null 2>&1; then
      echo "Service:  active (system)"
    else
      echo "Service:  $(systemctl is-active "syncthing-${USER}.service" 2>/dev/null || echo inactive) (system)"
    fi
  elif user_systemd_available && systemctl --user is-active syncthing.service >/dev/null 2>&1; then
    echo "Service:  active (user)"
  else
    echo "Service:  inactive"
  fi
  print_access_hints
}

uninstall_syncthing() {
  if [[ -f "$SYSTEM_UNIT_DEST" ]]; then
    df_ensure_sudo
    remove_system_service_unit
  fi
  if user_systemd_available; then
    remove_user_service_unit
  elif [[ -f "$UNIT_DEST" ]]; then
    run rm -f "$UNIT_DEST"
  fi
  if [[ -x "$BIN_PATH" ]]; then
    run rm -f "$BIN_PATH"
  fi
  if [[ "$PURGE_DATA" -eq 1 ]]; then
    run rm -rf "$SYNCTHING_HOME"
    log "removed $SYNCTHING_HOME"
  else
    log "kept $SYNCTHING_HOME (use --purge with --uninstall to remove)"
  fi
}

install_syncthing_binary() {
  local tag asset url tarball extract_dir binary
  local -a cleanup_dirs=()

  tag="$(gr_latest_tag "$REPO" || true)"
  [[ -n "$tag" && "$tag" != "null" ]] || {
    gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
    echo "ERROR: could not resolve latest Syncthing release tag" >&2
    exit 1
  }

  asset="$(syncthing_linux_asset "$tag")"
  url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

  if gr_bin_has_tag "$BIN_PATH" "$tag"; then
    echo "Already current: $BIN_PATH ($tag)"
    gr_print_version_line syncthing
    return 0
  fi

  cleanup_dirs+=("$(mktemp -d)")
  tarball="${cleanup_dirs[0]}/${asset}"
  extract_dir="${cleanup_dirs[0]}/extract"

  if ! gr_download "$url" "$tarball"; then
    rm -rf "${cleanup_dirs[0]}"
    gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
    echo "ERROR: download failed: $url" >&2
    exit 1
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir"

  binary="$(gr_find_binary "$extract_dir" syncthing || true)"
  if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
    rm -rf "${cleanup_dirs[0]}"
    echo "ERROR: syncthing binary not found in archive" >&2
    exit 1
  fi
  if ! gr_file_is_elf "$binary"; then
    rm -rf "${cleanup_dirs[0]}"
    echo "ERROR: refusing to install non-ELF $binary as $BIN_PATH" >&2
    exit 1
  fi

  log "installing $BIN_PATH (user-writable, auto-upgrade capable)"
  run mkdir -p "$(dirname "$BIN_PATH")"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    run install -m 755 "$binary" "$BIN_PATH"
  else
    install -m 755 "$binary" "$BIN_PATH"
    if declare -F df_journal_once >/dev/null 2>&1; then
      df_journal_once binary "$BIN_PATH"
    fi
  fi

  rm -rf "${cleanup_dirs[0]}"
  gr_print_version_line syncthing
}

if [[ "$STATUS_ONLY" -eq 1 ]]; then
  df_prepend_local_bin
  print_status
  exit 0
fi

df_prepend_local_bin
resolve_autostart_mode
ensure_user_systemd
install_syncthing_binary
syncthing_ensure_config
start_syncthing_service

log "done."
print_access_hints
