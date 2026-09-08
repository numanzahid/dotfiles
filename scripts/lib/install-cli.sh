#!/usr/bin/env bash
# Shared --uninstall / --dry-run / --yes flags for install scripts.

: "${DF_INSTALL_WANTS_UNINSTALL:=0}"
: "${DF_INSTALL_DRY_RUN:=0}"
: "${DF_INSTALL_YES:=0}"
DF_INSTALL_EXTRA_ARGS=()

df_install_cli_parse() {
  DF_INSTALL_WANTS_UNINSTALL=0
  DF_INSTALL_DRY_RUN=0
  DF_INSTALL_YES=0
  DF_INSTALL_EXTRA_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) DF_INSTALL_WANTS_UNINSTALL=1 ;;
      --dry-run)
        DF_INSTALL_DRY_RUN=1
        export DRY_RUN=1
        ;;
      --yes | -y) DF_INSTALL_YES=1 ;;
      -h | --help) return 2 ;;
      *) DF_INSTALL_EXTRA_ARGS+=("$1") ;;
    esac
    shift
  done

  if [[ "${DF_YES:-0}" -eq 1 || "${DOTFILES_YES:-0}" -eq 1 ]]; then
    DF_INSTALL_YES=1
  fi
  return 0
}

df_install_cli_require_no_extra_args() {
  if ((${#DF_INSTALL_EXTRA_ARGS[@]} > 0)); then
    echo "Unknown option: ${DF_INSTALL_EXTRA_ARGS[0]}" >&2
    return 1
  fi
  return 0
}

# Returns: 0=install, 1=uninstall handled (caller should exit 0), 2=help, 3=bad args
df_install_cli_entry() {
  local _rc=0

  df_install_cli_parse "$@" || _rc=$?
  if [[ "$_rc" -eq 2 ]]; then
    return 2
  fi
  if [[ "$DF_INSTALL_WANTS_UNINSTALL" -eq 1 ]]; then
    return 1
  fi
  if ! df_install_cli_require_no_extra_args; then
    return 3
  fi
  return 0
}
