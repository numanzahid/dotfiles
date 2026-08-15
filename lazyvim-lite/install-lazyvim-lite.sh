#!/usr/bin/env bash
# LazyVim-lite: LazyVim look and feel without Mason, LSP, Node, or lang IDE extras.
# Neovim itself must already be installed (./install.sh --neovim).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=../lazyvim/lib/nvim-profile.sh
source "$SCRIPT_DIR/../lazyvim/lib/nvim-profile.sh"

LAZYVIM_MIN_NEOVIM="0.11.2"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

LazyVim-lite: editor-focused LazyVim (no Mason/LSP/Node/lang IDE stack).
Tree-sitter CLI and parsers use the same path as ./lazyvim/install-lazyvim.sh.

Options:
  --dry-run       Print actions without changing the system
  --migrate       Run legacy cleanup before install
  --skip-sync     Skip headless LazyVim plugin sync
  -h, --help      Show this help

Configuration: lazyvim-lite/install.conf
EOF
}

parse_args() {
  RUN_MIGRATE=0
  SKIP_SYNC=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --migrate) RUN_MIGRATE=1 ;;
      --skip-sync) SKIP_SYNC=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -C -V
}

check_neovim() {
  local version luajit_ok=0

  command -v nvim >/dev/null 2>&1 || die "nvim not found. Run: ./install.sh --neovim"

  version="$(nvim --version | head -n 1 | sed -n 's/.*NVIM v\([0-9.]*\).*/\1/p')"
  [[ -n "$version" ]] || die "could not parse nvim version"

  if ! version_ge "$version" "$LAZYVIM_MIN_NEOVIM"; then
    die "nvim $version is too old (LazyVim requires >= $LAZYVIM_MIN_NEOVIM)"
  fi

  if nvim --version | grep -qi luajit; then
    luajit_ok=1
  fi

  if [[ "$luajit_ok" -ne 1 ]]; then
    die "nvim must be built with LuaJIT (LazyVim requirement)"
  fi

  log "neovim OK: $(nvim --version | head -n 1)"
}

prepare_lazyvim_lite_config() {
  log "enabling LazyVim-lite nvim profile"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run set_nvim_profile "lazyvim-lite"
  else
    set_nvim_profile "lazyvim-lite"
  fi

  if [[ -f "$NVIM_CONFIG_DIR/lua/plugins/nvim-extras.lua" ]]; then
    log "removing legacy nvim-extras.lua (replaced by dotfiles-extras.lua)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run rm -f "$NVIM_CONFIG_DIR/lua/plugins/nvim-extras.lua"
    else
      rm -f "$NVIM_CONFIG_DIR/lua/plugins/nvim-extras.lua"
    fi
  fi
}

verify_installation() {
  local sync_ok=1 parser_ok=1
  local ts_bin="${HOME}/.local/bin/tree-sitter"

  ensure_local_bin_path

  log "verification"

  command -v nvim >/dev/null 2>&1 || record_fail "nvim missing"
  command -v git >/dev/null 2>&1 || record_fail "git missing"
  command -v curl >/dev/null 2>&1 || record_fail "curl missing"
  command -v rg >/dev/null 2>&1 || record_fail "rg missing"
  command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 || record_fail "C compiler missing"

  # shellcheck source=../scripts/lib/platform.sh
  source "$DOTFILES_DIR/scripts/lib/platform.sh"
  if df_tree_sitter_cli_ok_for_host "$ts_bin"; then
    log "tree-sitter CLI OK: $("$ts_bin" --version 2>/dev/null | head -n1)"
  else
    record_fail "tree-sitter CLI missing or too old at $ts_bin (host glibc $(df_host_glibc_version 2>/dev/null || echo unknown))"
  fi

  if [[ "$SKIP_SYNC" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    if ! nvim --headless "+checkhealth lazy" +qa >/tmp/lazyvim-lite-health-lazy.log 2>&1; then
      sync_ok=0
      record_fail "checkhealth lazy failed (see /tmp/lazyvim-lite-health-lazy.log)"
    fi

    if ! nvim --headless "+lua if vim.fn.executable('tree-sitter')~=1 then os.exit(2) end" +qa >/tmp/lazyvim-lite-health-ts.log 2>&1; then
      parser_ok=0
      record_fail "nvim cannot run tree-sitter CLI (see /tmp/lazyvim-lite-health-ts.log)"
    elif ! df_version_ge "$(df_host_glibc_version)" "2.39"; then
      warn "nvim-treesitter :checkhealth may warn about CLI 0.26.1 on glibc $(df_host_glibc_version); installed $(df_tree_sitter_expected_cli_version) is expected"
    fi
  fi

  print_summary "$sync_ok" "$parser_ok"
  [[ "$FAILED" -eq 0 ]] || exit 1
}

print_summary() {
  local sync_ok="$1" parser_ok="$2"
  local fd_path

  fd_path="$(command -v fd 2>/dev/null || command -v fdfind 2>/dev/null || echo missing)"

  cat <<EOF

=== LazyVim-lite setup summary ===
Neovim version:     $(command_version nvim --version)
Tree-sitter CLI:    $(command_version tree-sitter --version)
Tree-sitter path:   $(command -v tree-sitter 2>/dev/null || echo missing)
C compiler path:    $(command -v cc 2>/dev/null || command -v gcc 2>/dev/null || echo missing)
Git version:        $(command_version git --version)
ripgrep version:    $(command_version rg --version)
fd version:         $(command -v fd >/dev/null && fd --version | head -n1 || command -v fdfind >/dev/null && fdfind --version | head -n1 || echo missing)
LazyVim config:     ${XDG_CONFIG_HOME:-$HOME/.config}/nvim
LazyVim data:       ${XDG_DATA_HOME:-$HOME/.local/share}/nvim
Profile:            lazyvim-lite (no Mason/LSP/Node)

LazyVim core sync:  $( [[ "$SKIP_SYNC" -eq 1 ]] && echo SKIP || ([[ "$sync_ok" -eq 1 ]] && echo PASS || echo FAIL) )
Tree-sitter health: $( [[ "$SKIP_SYNC" -eq 1 ]] && echo SKIP || ([[ "$parser_ok" -eq 1 ]] && echo PASS || echo FAIL) )

Disk usage:
  nvim data:  $(format_bytes "$(disk_usage_bytes "${XDG_DATA_HOME:-$HOME/.local/share}/nvim")")
  nvim cache: $(format_bytes "$(disk_usage_bytes "${XDG_CACHE_HOME:-$HOME/.cache}/nvim")")

Nerd Font recommended for complete icon display (not required).

Next steps:
  1. Run: nvim
  2. Inside nvim: :LazyHealth
  3. See plugin list: lazyvim-lite/README.md

EOF
}

main() {
  local disk_before=0

  load_install_conf
  check_platform
  check_not_root_for_user_phase "$@"
  parse_args "$@"

  if [[ "$RUN_MIGRATE" -eq 1 ]]; then
    bash "$LAZYVIM_DIR/migrate-legacy.sh"
  else
    bash "$LAZYVIM_DIR/migrate-legacy.sh" --pack-only
  fi

  disk_before="$(disk_usage_bytes "${XDG_DATA_HOME:-$HOME/.local/share}/nvim")"
  disk_before=$((disk_before + $(disk_usage_bytes "${XDG_CACHE_HOME:-$HOME/.cache}/nvim")))

  log "estimated footprint before install: $(format_bytes "$disk_before") (nvim data+cache only)"
  log "plugins will download on first sync (lite profile skips Mason/LSP tooling)"

  check_neovim
  ensure_local_bin_path

  run bash "$LAZYVIM_DIR/install-system-deps.sh"
  run bash "$LAZYVIM_DIR/install-tree-sitter-cli.sh"
  prepare_lazyvim_lite_config

  if [[ "$SKIP_SYNC" -eq 0 ]]; then
    DRY_RUN="$DRY_RUN" bash "$SCRIPT_DIR/sync-lazyvim-lite.sh"
  else
    log "skipping headless sync (--skip-sync)"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run complete"
    exit 0
  fi

  verify_installation
}

main "$@"
