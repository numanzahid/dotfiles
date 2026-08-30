#!/usr/bin/env bash
set -euo pipefail

# Install Avahi and configure .local mDNS (Fedora, Debian, Ubuntu).
# Re-run anytime to repair packages, NSS, firewall, and resolved/NM.
#
# Avahi publishes hostname.local. nss-mdns/libnss-mdns makes ping/ssh
# resolve .local. systemd-resolved mDNS is turned off so it does not
# steal UDP 5353 from Avahi.
#
# Usage:
#   ./scripts/avahi-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"

AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
RESOLVED_DROPIN="/etc/systemd/resolved.conf.d/dotfiles-mdns.conf"
NM_DROPIN="/etc/NetworkManager/conf.d/dotfiles-mdns.conf"

os_family() {
  local id like=""
  id="$(df_host_os_id)"
  case "$id" in
    fedora) printf '%s' fedora && return 0 ;;
    debian | ubuntu | linuxmint | pop) printf '%s' debian && return 0 ;;
  esac
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    like="${ID_LIKE:-}"
  fi
  case " $like " in
    *" fedora "* | *" rhel "*) printf '%s' fedora && return 0 ;;
    *" debian "*) printf '%s' debian && return 0 ;;
  esac
  printf '%s' unknown
}

install_packages() {
  local family="$1"
  case "$family" in
    fedora)
      echo "Installing Fedora packages: avahi nss-mdns avahi-tools"
      df_run_privileged dnf install -y avahi nss-mdns avahi-tools
      ;;
    debian)
      echo "Installing Debian/Ubuntu packages: avahi-daemon libnss-mdns avahi-utils"
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y avahi-daemon libnss-mdns avahi-utils
      ;;
    *)
      echo "ERROR: unsupported OS ($(df_host_os_id)). Need Fedora or Debian/Ubuntu." >&2
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
}

write_file() {
  local dest="$1"
  local dir
  dir="$(dirname "$dest")"
  df_run_privileged mkdir -p "$dir"
  df_run_privileged tee "$dest" >/dev/null
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
  write_file "$RESOLVED_DROPIN" <<'EOF'
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
  write_file "$NM_DROPIN" <<'EOF'
[connection]
connection.mdns=0
EOF
  if command -v nmcli >/dev/null 2>&1; then
    df_run_privileged nmcli general reload || true
  elif command -v systemctl >/dev/null 2>&1; then
    df_run_privileged systemctl reload NetworkManager.service || true
  fi
}

set_avahi_key() {
  local key="$1"
  local value="$2"
  local file="$AVAHI_CONF"

  [[ -f "$file" ]] || return 0

  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    df_run_privileged sed -i "s|^[[:space:]]*#\\?[[:space:]]*${key}=.*|${key}=${value}|" "$file"
  fi
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

lan_interfaces() {
  local dev type state
  if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r dev type state; do
      [[ "$state" == "connected" ]] || continue
      case "$type" in
        wifi | ethernet | wifi-p2p) printf '%s\n' "$dev" ;;
      esac
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
    return 0
  fi
  ip -o route show default 2>/dev/null | awk '{
    for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit }
  }'
}

bridge_interfaces() {
  local name
  while IFS= read -r name; do
    name="${name%%@*}"
    case "$name" in
      docker* | br-* | veth* | virbr* | lxc* | cni* | flannel* | podman* | tun* | tap*)
        printf '%s\n' "$name"
        ;;
    esac
  done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}')
}

configure_avahi_interfaces() {
  local -a lan=() deny=()
  local n list

  while IFS= read -r n; do
    [[ -n "$n" ]] && lan+=("$n")
  done < <(lan_interfaces)

  if ((${#lan[@]} > 0)); then
    list="$(IFS=,; echo "${lan[*]}")"
    echo "Avahi allow-interfaces: $list"
    set_avahi_key allow-interfaces "$list"
    return 0
  fi

  while IFS= read -r n; do
    [[ -n "$n" ]] && deny+=("$n")
  done < <(bridge_interfaces)

  if ((${#deny[@]} > 0)); then
    list="$(IFS=,; echo "${deny[*]}")"
    echo "Avahi deny-interfaces: $list"
    set_avahi_key deny-interfaces "$list"
  fi
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
  echo "Enabling avahi-daemon"
  df_run_privileged systemctl enable --now avahi-daemon.service
  df_run_privileged systemctl restart avahi-daemon.service
}

print_status() {
  local host
  host="$(hostname -s 2>/dev/null || hostname)"
  echo
  echo "Done."
  echo "avahi-daemon: $(systemctl is-active avahi-daemon.service 2>/dev/null || echo unknown)"
  echo "hosts line:   $(grep -E '^hosts:' /etc/nsswitch.conf 2>/dev/null || echo missing)"
  if command -v avahi-resolve >/dev/null 2>&1; then
    echo "self resolve: $(avahi-resolve -n -4 "${host}.local" 2>/dev/null || echo "failed (${host}.local)")"
  fi
  echo "Test from another machine: ping ${host}.local"
  echo "resolvectl query ${host}.local can succeed locally even without LAN mDNS."
}

df_ensure_sudo

FAMILY="$(os_family)"
echo "OS family: $FAMILY ($(df_host_os_id))"

install_packages "$FAMILY"
ensure_nss_mdns "$FAMILY"
configure_resolved
configure_networkmanager
configure_avahi_conf
configure_firewalld
configure_ufw
enable_avahi
print_status
