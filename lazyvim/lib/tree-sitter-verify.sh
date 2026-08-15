#!/usr/bin/env bash
# Shared tree-sitter CLI verification for LazyVim installers.
set -euo pipefail

# Sets TS_CLI_VERIFY_STATUS to pass | warn | fail.
verify_tree_sitter_cli_for_install() {
  local ts_bin="${1:-${HOME}/.local/bin/tree-sitter}"

  TS_CLI_VERIFY_STATUS="fail"

  if ! df_tree_sitter_cli_runs "$ts_bin"; then
    record_fail "tree-sitter CLI missing or not executable at $ts_bin"
    return 1
  fi

  log "tree-sitter CLI runs: $("$ts_bin" --version 2>/dev/null | head -n1) ($ts_bin)"

  if df_tree_sitter_cli_meets_nvim_treesitter_min "$ts_bin"; then
    TS_CLI_VERIFY_STATUS="pass"
    return 0
  fi

  TS_CLI_VERIFY_STATUS="warn"
  warn "tree-sitter CLI is below nvim-treesitter minimum ($(df_nvim_treesitter_cli_min)); :checkhealth nvim-treesitter will ERROR (highlighting and :TSUpdate still work)"
  return 0
}

ts_cli_verify_summary_label() {
  case "${TS_CLI_VERIFY_STATUS:-fail}" in
    pass) printf 'PASS' ;;
    warn) printf 'WARN (degraded CLI)' ;;
    *) printf 'FAIL' ;;
  esac
}

verify_nvim_tree_sitter_runtime() {
  local log_file="$1"

  if ! nvim --headless "+lua if vim.fn.executable('tree-sitter')~=1 then os.exit(2) end" +qa >"$log_file" 2>&1; then
    record_fail "nvim cannot run tree-sitter CLI (see $log_file)"
    return 1
  fi

  return 0
}
