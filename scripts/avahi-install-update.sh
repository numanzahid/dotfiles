#!/usr/bin/env bash
set -euo pipefail

# Install Avahi and configure .local mDNS (Fedora, Debian/Ubuntu, Arch/Omarchy).
# Re-run anytime to repair packages, NSS, firewall, and resolved/NM.
#
# Avahi publishes hostname.local. nss-mdns/libnss-mdns makes ping/ssh
# resolve .local. systemd-resolved mDNS is turned off so it does not
# steal UDP 5353 from Avahi.
#
# Usage:
#   ./scripts/avahi-install-update.sh
#   ./scripts/avahi-install-update.sh --status
#
# Override auto-detected LAN interface(s):
#   AVAHI_ALLOW_INTERFACES=eth0 ./scripts/avahi-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STATUS_ONLY=0
REPAIR=0
AVAHI_CONF_CHANGED=0
declare -a SUMMARY=()

usage() {
  cat <<'EOF'
Usage: ./scripts/avahi-install-update.sh [options]

Install Avahi and configure hostname.local mDNS on Fedora, Debian/Ubuntu,
Arch Linux, and Omarchy (Arch-based). Re-run to repair packages, NSS,
firewall, and systemd-resolved/NetworkManager.

Avahi publishes hostname.local. nss-mdns makes ping/ssh resolve .local.
systemd-resolved mDNS is turned off so it does not steal UDP 5353.
Needs sudo for install/configure. Optional, not part of --all.

LAN interface(s) are detected automatically (NetworkManager or default route).
Override when auto-detect is wrong:
  AVAHI_ALLOW_INTERFACES=eth0 ./scripts/avahi-install-update.sh
  AVAHI_ALLOW_INTERFACES=wlan0,enp3s0 ./scripts/avahi-install-update.sh

Options:
  --status   Show setup details only (no install or config changes)
  --repair   Reinstall packages and restart avahi-daemon
  -h, --help Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) STATUS_ONLY=1 ;;
      --repair) REPAIR=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

# shellcheck source=scripts/lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"
# shellcheck source=scripts/lib/journal.sh
source "$SCRIPT_DIR/lib/journal.sh"

AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
RESOLVED_DROPIN="/etc/systemd/resolved.conf.d/dotfiles-mdns.conf"
NM_DROPIN="/etc/NetworkManager/conf.d/dotfiles-mdns.conf"

summary_add() {
  local file="$1"
  local desc="$2"
  SUMMARY+=("$file|$desc")
}

os_family() {
  local id like=""
  id="$(df_host_os_id)"
  case "$id" in
    fedora) printf '%s' fedora && return 0 ;;
    debian | ubuntu | linuxmint | pop) printf '%s' debian && return 0 ;;
    arch | omarchy) printf '%s' arch && return 0 ;;
  esac
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    like="${ID_LIKE:-}"
  fi
  case " $like " in
    *" fedora "* | *" rhel "*) printf '%s' fedora && return 0 ;;
    *" debian "*) printf '%s' debian && return 0 ;;
    *" arch "*) printf '%s' arch && return 0 ;;
  esac
  printf '%s' unknown
}

avahi_package_names() {
  local family="$1"
  case "$family" in
    fedora) printf '%s\n' avahi nss-mdns avahi-tools ;;
    debian) printf '%s\n' avahi-daemon libnss-mdns avahi-utils ;;
    arch) printf '%s\n' avahi nss-mdns avahi-utils ;;
  esac
}

avahi_packages_installed() {
  local family="$1" pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    df_pkg_is_installed "$pkg" || return 1
  done < <(avahi_package_names "$family")
}

install_packages() {
  local family="$1"
  local -a missing=() pkgs=()
  local pkg

  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    pkgs+=("$pkg")
    df_pkg_is_installed "$pkg" || missing+=("$pkg")
  done < <(avahi_package_names "$family")

  if ((${#missing[@]} == 0)) && [[ "$REPAIR" -eq 0 ]]; then
    echo "Avahi packages already installed: ${pkgs[*]}"
    return 0
  fi

  case "$family" in
    fedora)
      echo "Installing Fedora packages: avahi nss-mdns avahi-tools"
      df_run_privileged dnf install -y avahi nss-mdns avahi-tools
      ((${#missing[@]} > 0)) && df_journal_new_packages "${missing[@]}"
      ((${#missing[@]} > 0)) && summary_add "(packages)" "installed: ${missing[*]}"
      ;;
    debian)
      echo "Installing Debian/Ubuntu packages: avahi-daemon libnss-mdns avahi-utils"
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y avahi-daemon libnss-mdns avahi-utils
      ((${#missing[@]} > 0)) && df_journal_new_packages "${missing[@]}"
      ((${#missing[@]} > 0)) && summary_add "(packages)" "installed: ${missing[*]}"
      ;;
    arch)
      echo "Installing Arch/Omarchy packages: avahi nss-mdns avahi-utils"
      df_run_privileged pacman -Sy --needed --noconfirm avahi nss-mdns avahi-utils
      ((${#missing[@]} > 0)) && df_journal_new_packages "${missing[@]}"
      ((${#missing[@]} > 0)) && summary_add "(packages)" "installed: ${missing[*]}"
      ;;
    *)
      echo "ERROR: unsupported OS ($(df_host_os_id)). Need Fedora, Debian/Ubuntu, or Arch/Omarchy." >&2
      exit 1
      ;;
  esac
}

ensure_nss_mdns() {
  local family="$1"
  local hosts

  hosts="$(grep -E '^hosts:' /etc/nsswitch.conf 2>/dev/null || true)"
  if echo "$hosts" | grep -qE 'mdns4_minimal|mdns_minimal|mdns4 '; then
    echo "nsswitch already has mDNS: $hosts"
    return 0
  fi

  if [[ "$family" == "fedora" ]] && command -v authselect >/dev/null 2>&1; then
    if authselect current >/dev/null 2>&1; then
      echo "Enabling authselect feature with-mdns4"
      df_run_privileged authselect enable-feature with-mdns4 ||
        echo "WARN: authselect enable-feature with-mdns4 failed" >&2
      summary_add "/etc/nsswitch.conf" "enabled authselect with-mdns4"
    fi
  fi

  hosts="$(grep -E '^hosts:' /etc/nsswitch.conf 2>/dev/null || true)"
  if echo "$hosts" | grep -qE 'mdns4_minimal|mdns_minimal|mdns4 '; then
    echo "nsswitch mDNS ok: $hosts"
    return 0
  fi

  echo "WARN: /etc/nsswitch.conf hosts line has no mdns plugin." >&2
  echo "WARN: expected mdns4_minimal [NOTFOUND=return] before dns/resolve" >&2
  echo "WARN: current: $hosts" >&2
  if [[ "$family" == "arch" ]]; then
    echo "WARN: Arch/Omarchy: install nss-mdns and add mdns_minimal [NOTFOUND=return] to hosts:" >&2
  fi
}

write_file() {
  local dest="$1"
  local note="$2"
  local dir before after

  dir="$(dirname "$dest")"
  before=""
  if [[ -f "$dest" ]]; then
    before="$(cat "$dest" 2>/dev/null || true)"
  fi

  df_run_privileged mkdir -p "$dir"
  after="$(cat)"
  if [[ "$before" == "$after" ]]; then
    echo "Unchanged: $dest"
    return 0
  fi

  printf '%s' "$after" | df_run_privileged tee "$dest" >/dev/null
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once system-dropin "$dest"
  fi
  summary_add "$dest" "$note"
}

configure_resolved() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi
  if ! systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
    return 0
  fi
  if ! systemctl is-enabled systemd-resolved.service >/dev/null 2>&1 &&
    ! systemctl is-active systemd-resolved.service >/dev/null 2>&1; then
    return 0
  fi

  echo "Disabling systemd-resolved mDNS (Avahi owns UDP 5353)"
  write_file "$RESOLVED_DROPIN" "MulticastDNS=no" <<'EOF'
[Resolve]
MulticastDNS=no
EOF
  df_run_privileged systemctl restart systemd-resolved.service || true
}

configure_networkmanager() {
  if [[ ! -d /etc/NetworkManager ]]; then
    return 0
  fi
  echo "Setting NetworkManager connection.mdns=0 (Avahi publishes)"
  write_file "$NM_DROPIN" "connection.mdns=0" <<'EOF'
[connection]
connection.mdns=0
EOF
  if command -v nmcli >/dev/null 2>&1; then
    df_run_privileged nmcli general reload || true
  elif command -v systemctl >/dev/null 2>&1; then
    df_run_privileged systemctl reload NetworkManager.service || true
  fi
}

avahi_conf_value() {
  local key="$1"
  [[ -f "$AVAHI_CONF" ]] || return 0
  grep -E "^[[:space:]]*${key}=" "$AVAHI_CONF" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

summary_avahi_key() {
  local key="$1"
  local value="$2"
  local count

  if [[ "$value" != *","* ]] || ((${#value} <= 100)); then
    printf 'set %s=%s' "$key" "$value"
    return 0
  fi
  count="$(awk -F, '{print NF}' <<<"$value")"
  printf 'set %s=<%s interfaces>' "$key" "$count"
}

set_avahi_key() {
  local key="$1"
  local value="$2"
  local file="$AVAHI_CONF"
  local old new

  [[ -f "$file" ]] || return 0

  old="$(avahi_conf_value "$key")"
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    if ! df_run_privileged sed -i "s|^[[:space:]]*#\\?[[:space:]]*${key}=.*|${key}=${value}|" "$file"; then
      echo "ERROR: failed to set ${key} in $file" >&2
      return 1
    fi
  elif grep -q '^\[server\]' "$file"; then
    if ! df_run_privileged sed -i "/^\[server\]/a ${key}=${value}" "$file"; then
      echo "ERROR: failed to add ${key} in $file" >&2
      return 1
    fi
  else
    if ! printf '\n# Added by dotfiles avahi-install-update.sh\n%s=%s\n' "$key" "$value" |
      df_run_privileged tee -a "$file" >/dev/null; then
      echo "ERROR: failed to append ${key} to $file" >&2
      return 1
    fi
  fi

  new="$(avahi_conf_value "$key")"
  if [[ "$old" != "$new" ]]; then
    AVAHI_CONF_CHANGED=1
    summary_add "$file" "$(summary_avahi_key "$key" "$value")"
  fi
}

is_virtual_iface() {
  case "$1" in
    docker* | br-* | veth* | virbr* | lxc* | cni* | flannel* | podman* | tun* | tap*)
      return 0
      ;;
  esac
  return 1
}

iface_has_global_ipv4() {
  local dev="$1"
  ip -4 -o addr show dev "$dev" scope global 2>/dev/null | grep -q .
}

default_route_iface() {
  ip -o route show default 2>/dev/null | awk '{
    for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit }
  }'
}

lan_interfaces_nmcli() {
  local dev type state
  while IFS=: read -r dev type state; do
    [[ "$state" == "connected" ]] || continue
    case "$type" in
      wifi | ethernet | wifi-p2p)
        is_virtual_iface "$dev" && continue
        iface_has_global_ipv4 "$dev" || continue
        printf '%s\n' "$dev"
        ;;
    esac
  done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
}

lan_interfaces_route() {
  local dev
  dev="$(default_route_iface)"
  [[ -n "$dev" ]] || return 0
  is_virtual_iface "$dev" && return 0
  iface_has_global_ipv4 "$dev" || return 0
  printf '%s\n' "$dev"
}

lan_interfaces() {
  local dev part out

  if [[ -n "${AVAHI_ALLOW_INTERFACES:-}" ]]; then
    IFS=',' read -ra parts <<<"${AVAHI_ALLOW_INTERFACES}"
    for part in "${parts[@]}"; do
      part="${part// /}"
      [[ -n "$part" ]] && printf '%s\n' "$part"
    done
    return 0
  fi

  if command -v nmcli >/dev/null 2>&1; then
    out="$(lan_interfaces_nmcli)"
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi

  lan_interfaces_route
}

bridge_interfaces() {
  local name
  while IFS= read -r name; do
    name="${name%%@*}"
    is_virtual_iface "$name" && printf '%s\n' "$name"
  done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}')
}

docker_virtual_present() {
  if [[ -S /var/run/docker.sock ]] || ip link show docker0 >/dev/null 2>&1; then
    return 0
  fi
  bridge_interfaces | grep -q .
}

iface_detection_note() {
  local out
  if [[ -n "${AVAHI_ALLOW_INTERFACES:-}" ]]; then
    echo "LAN interfaces: ${AVAHI_ALLOW_INTERFACES} (AVAHI_ALLOW_INTERFACES override)"
    return 0
  fi
  if command -v nmcli >/dev/null 2>&1; then
    out="$(lan_interfaces_nmcli)"
    if [[ -n "$out" ]]; then
      echo "LAN interfaces: detected via NetworkManager (connected ethernet/wifi with IPv4)"
      return 0
    fi
  fi
  echo "LAN interfaces: detected via default route (physical iface with global IPv4)"
}

configure_avahi_interfaces() {
  local -a lan=() deny=()
  local n list

  iface_detection_note

  while IFS= read -r n; do
    [[ -n "$n" ]] && lan+=("$n")
  done < <(lan_interfaces)

  if ((${#lan[@]} > 0)); then
    list="$(IFS=,; echo "${lan[*]}")"
    echo "Avahi allow-interfaces: $list"
    set_avahi_key allow-interfaces "$list"
    echo "Skipping deny-interfaces (allow-interfaces already limits Avahi to the LAN uplink)"
    return 0
  fi

  echo "WARN: no LAN interface detected; skipping allow-interfaces" >&2
  echo "WARN: set AVAHI_ALLOW_INTERFACES=eth0 and re-run" >&2

  if ! docker_virtual_present; then
    return 0
  fi

  while IFS= read -r n; do
    [[ -n "$n" ]] && deny+=("$n")
  done < <(bridge_interfaces | sort -u)
  if ((${#deny[@]} == 0)); then
    return 0
  fi

  list="$(IFS=,; echo "${deny[*]}")"
  echo "Avahi deny-interfaces (no allow list; blocking Docker/virtual): ${#deny[@]} interfaces"
  set_avahi_key deny-interfaces "$list"
}

configure_avahi_conf() {
  if [[ ! -f "$AVAHI_CONF" ]]; then
    echo "WARN: $AVAHI_CONF missing; skipping daemon.conf tweaks" >&2
    return 0
  fi

  echo "Setting Avahi publish defaults in $AVAHI_CONF"
  set_avahi_key use-ipv4 yes
  set_avahi_key use-ipv6 yes
  set_avahi_key disable-publishing no
  set_avahi_key publish-addresses yes
  set_avahi_key publish-workstation yes
  configure_avahi_interfaces
}

skip_firewall_zone() {
  case "$1" in
    docker | libvirt | libvirt-devel | kube* | podman) return 0 ;;
  esac
  return 1
}

configure_firewalld() {
  command -v firewall-cmd >/dev/null 2>&1 || return 0
  if ! systemctl is-active firewalld.service >/dev/null 2>&1; then
    echo "firewalld is not active; skip mdns service"
    return 0
  fi

  echo "Allowing firewalld mdns (UDP 5353 multicast)"
  df_run_privileged firewall-cmd --permanent --add-service=mdns || true

  local zone="" line default
  default="$(firewall-cmd --get-default-zone 2>/dev/null || true)"
  if [[ -n "$default" ]]; then
    echo "Allowing mdns on default zone: $default"
    df_run_privileged firewall-cmd --permanent --zone="$default" --add-service=mdns || true
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$line" =~ ^[[:space:]] ]]; then
      continue
    fi
    zone="${line%% (*}"
    zone="${zone%%[[:space:]]*}"
    skip_firewall_zone "$zone" && continue
    echo "Allowing mdns on zone: $zone"
    df_run_privileged firewall-cmd --permanent --zone="$zone" --add-service=mdns || true
  done < <(firewall-cmd --get-active-zones 2>/dev/null || true)

  df_run_privileged firewall-cmd --reload || true
}

configure_ufw() {
  command -v ufw >/dev/null 2>&1 || return 0
  if ! ufw status 2>/dev/null | grep -qi 'Status: active'; then
    echo "ufw is not active; skip 5353/udp"
    return 0
  fi
  echo "Allowing ufw 5353/udp (mDNS)"
  df_run_privileged ufw allow 5353/udp comment 'mDNS' || true
}

enable_avahi() {
  local restart=0
  echo "Enabling avahi-daemon"
  df_run_privileged systemctl enable --now avahi-daemon.service
  if [[ "$REPAIR" -eq 1 ]]; then
    restart=1
  elif [[ "$AVAHI_CONF_CHANGED" -eq 1 ]]; then
    restart=1
    echo "avahi-daemon.conf changed; restarting avahi-daemon"
  elif ! systemctl is-active avahi-daemon.service >/dev/null 2>&1; then
    restart=1
  fi
  if [[ "$restart" -eq 1 ]]; then
    df_run_privileged systemctl restart avahi-daemon.service
    summary_add "avahi-daemon.service" "restarted"
  else
    echo "avahi-daemon already active; skip restart (use --repair to force)"
  fi
}

print_lan_addresses() {
  local dev cidr any=0
  while IFS= read -r dev; do
    [[ -n "$dev" ]] || continue
    while IFS= read -r cidr; do
      [[ -n "$cidr" ]] || continue
      printf '  %s on %s\n' "$cidr" "$dev"
      any=1
    done < <(ip -4 -o addr show dev "$dev" scope global 2>/dev/null | awk '{print $4}')
  done < <(lan_interfaces)
  if [[ "$any" -eq 0 ]]; then
    echo "  (no connected LAN interface found)"
  fi
}

print_avahi_warnings() {
  if ! command -v journalctl >/dev/null 2>&1; then
    return 0
  fi
  if journalctl -u avahi-daemon -n 80 --no-pager 2>/dev/null |
    grep -q 'IP_ADD_MEMBERSHIP failed'; then
    echo
    echo "WARN: avahi journal shows IP_ADD_MEMBERSHIP failed (multicast / too many interfaces)."
    echo "WARN: check allow-interfaces in $AVAHI_CONF and restart avahi-daemon."
    echo "WARN: override: AVAHI_ALLOW_INTERFACES=eth0 $0"
  fi
}

print_status() {
  local host short configured=0
  host="$(hostname -s 2>/dev/null || hostname)"
  short="$host"

  if [[ -n "${FAMILY:-}" ]] && avahi_packages_installed "$FAMILY"; then
    configured=1
  fi

  echo
  if [[ "$configured" -eq 1 ]]; then
    echo "Avahi is configured on this machine."
  else
    echo "Avahi is not fully installed on this machine."
  fi
  echo
  echo "mDNS hostname:  ${short}.local"
  echo "SSH example:    ssh ${short}.local"
  echo "Ping example:   ping ${short}.local"
  echo
  echo "Service:        $(systemctl is-active avahi-daemon.service 2>/dev/null || echo unknown)"
  echo "Enabled:        $(systemctl is-enabled avahi-daemon.service 2>/dev/null || echo unknown)"
  echo "nsswitch:       $(grep -E '^hosts:' /etc/nsswitch.conf 2>/dev/null || echo missing)"
  if [[ -f "$AVAHI_CONF" ]]; then
    echo "host-name:      $(avahi_conf_value host-name || echo "$short")"
    echo "allow-ifaces:   $(avahi_conf_value allow-interfaces || echo "(not set)")"
    echo "deny-ifaces:    $(avahi_conf_value deny-interfaces || echo "(not set)")"
  fi
  echo "LAN addresses:"
  print_lan_addresses
  if command -v avahi-resolve >/dev/null 2>&1; then
    echo "Self resolve:   $(avahi-resolve -n -4 "${short}.local" 2>/dev/null || echo "failed (${short}.local)")"
  fi
  if [[ -f "$RESOLVED_DROPIN" ]]; then
    echo "resolved drop:  $RESOLVED_DROPIN (MulticastDNS=no)"
  fi
  if [[ -f "$NM_DROPIN" ]]; then
    echo "NM drop-in:     $NM_DROPIN (connection.mdns=0)"
  fi
  print_avahi_warnings
  echo
  echo "Test from another machine on the LAN: ping ${short}.local"
  echo "Note: resolvectl query ${short}.local can work locally without LAN mDNS."
}

print_changes_summary() {
  local entry file desc

  echo
  echo "=== This run: files and settings ==="
  if ((${#SUMMARY[@]} == 0)); then
    echo "  No config files changed (packages and services were already in place)."
    echo
    echo "Key files to edit manually if needed:"
    echo "  $AVAHI_CONF"
    echo "    allow-interfaces=<your-lan-nic>"
    echo "    deny-interfaces=... (fallback only when allow-interfaces is not set)"
    echo "  /etc/nsswitch.conf"
    echo "    hosts: files mdns4_minimal [NOTFOUND=return] dns"
    [[ -f "$RESOLVED_DROPIN" ]] && echo "  $RESOLVED_DROPIN"
    [[ -f "$NM_DROPIN" ]] && echo "  $NM_DROPIN"
    echo
    echo "After manual edits: sudo systemctl restart avahi-daemon"
    echo "Override auto-detect: AVAHI_ALLOW_INTERFACES=eth0 $0"
    return 0
  fi

  for entry in "${SUMMARY[@]}"; do
    file="${entry%%|*}"
    desc="${entry#*|}"
    printf '  %s\n    -> %s\n' "$file" "$desc"
  done
  echo
  echo "If interface detection was wrong, edit $AVAHI_CONF (allow-interfaces)"
  echo "or re-run: AVAHI_ALLOW_INTERFACES=eth0 $0"
  echo "Then: sudo systemctl restart avahi-daemon"
}

main() {
  parse_args "$@"

  if [[ "$STATUS_ONLY" -eq 1 ]]; then
    FAMILY="$(os_family)"
    echo "OS family: $FAMILY ($(df_host_os_id))"
    print_status
    exit 0
  fi

  df_ensure_sudo

  FAMILY="$(os_family)"
  echo "OS family: $FAMILY ($(df_host_os_id))"

  if avahi_packages_installed "$FAMILY"; then
    echo "Avahi already configured; applying idempotent fixes and showing status."
  fi

  install_packages "$FAMILY"
  ensure_nss_mdns "$FAMILY"
  configure_resolved
  configure_networkmanager
  configure_avahi_conf
  configure_firewalld
  configure_ufw
  enable_avahi
  print_status
  print_changes_summary
}

main "$@"
