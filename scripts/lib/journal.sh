#!/usr/bin/env bash
# Append-only install journal. Lives on the machine, not in the clone.
# Format: timestamp<TAB>kind<TAB>path<TAB>extra
#
# Kinds and uninstall behavior (uninstall.sh):
#   backup       - no-op (restore uses dest.pre-dotfiles on disk)
#   link         - restore home path from backup or remove symlink
#   copy         - restore home path from backup or remove our copy
#   skip         - no-op (pre-existing file left alone)
#   patch        - reserved, no-op
#   package-new  - apt/dnf remove when path names the package
#   binary       - remove file or tree (home or system)
#   symlink      - remove system symlink
#   opt-tree     - remove system directory tree
#   git-clone    - remove clone directory under $HOME
#   hide-clone   - no-op (informational; purge removes the clone)
#   locale       - no-op (system locale left enabled)
#   gsettings-key - remove GNOME custom keybinding (path = binding id)
#   system-dropin - remove system config file we created (path = absolute path)
#
# Callers: link.sh, github-release.sh, install-deps, hide-clone, uninstall.sh

df_journal_dir() {
  printf '%s/dotfiles' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

df_journal_file() {
  printf '%s/install-journal.tsv' "$(df_journal_dir)"
}

df_install_log_file() {
  printf '%s/install.log' "$(df_journal_dir)"
}

df_journal_append() {
  local kind="$1"
  local path="${2:-}"
  local extra="${3:-}"
  local file logf dir ts

  file="$(df_journal_file)"
  logf="$(df_install_log_file)"
  dir="$(df_journal_dir)"
  mkdir -p "$dir"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\t%s\t%s\t%s\n' "$ts" "$kind" "$path" "$extra" >>"$file"
  printf '%s %s %s %s\n' "$ts" "$kind" "$path" "$extra" >>"$logf"
}

df_journal_has() {
  local kind="$1"
  local path="$2"
  local file
  file="$(df_journal_file)"
  [[ -f "$file" ]] || return 1
  awk -F '\t' -v k="$kind" -v p="$path" '
    $2 == k && $3 == p { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$file"
}

# No-op on installer --dry-run. Skips duplicates of kind+path.
df_journal_once() {
  local kind="$1"
  local path="${2:-}"
  local extra="${3:-}"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi
  if df_journal_has "$kind" "$path"; then
    return 0
  fi
  df_journal_append "$kind" "$path" "$extra"
}

df_pkg_is_installed() {
  local pkg="$1"
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
    return $?
  fi
  if command -v rpm >/dev/null 2>&1; then
    rpm -q "$pkg" >/dev/null 2>&1
    return $?
  fi
  return 1
}

# Record packages that were missing before a successful install.
# Usage: df_journal_new_packages pkg1 pkg2 ...
df_journal_new_packages() {
  local pkg
  for pkg in "$@"; do
    [[ -n "$pkg" ]] || continue
    df_journal_once package-new "$pkg"
  done
}

df_collect_missing_packages() {
  local pkg
  for pkg in "$@"; do
    if df_pkg_is_installed "$pkg"; then
      continue
    fi
    printf '%s\n' "$pkg"
  done
}

# Print unique paths for a journal kind (last column ignored).
df_journal_paths_for_kind() {
  local want="$1"
  local file p kind
  file="$(df_journal_file)"
  [[ -f "$file" ]] || return 0
  while IFS=$'\t' read -r _ts kind p _extra; do
    [[ "$kind" == "$want" ]] || continue
    [[ -n "$p" ]] || continue
    printf '%s\n' "$p"
  done <"$file" | awk 'NF && !seen[$0]++'
}

# Kinds uninstall.sh does not act on (by design).
df_journal_is_skip_kind() {
  case "$1" in
    backup | skip | patch | hide-clone | locale) return 0 ;;
    *) return 1 ;;
  esac
}
