#!/usr/bin/env bash
# Per-component last-success timestamps for dotfiles update skip logic.
# Format: component<TAB>updated_at<TAB>version<TAB>note
#
# updated_at: UTC ISO-8601 (same style as install-journal.tsv)
# Freshness: dotfiles update skips software reinstall when age < DOTFILES_UPDATE_SKIP_DAYS.

DOTFILES_UPDATE_SKIP_DAYS="${DOTFILES_UPDATE_SKIP_DAYS:-30}"

# shellcheck source=journal.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/journal.sh"

df_component_state_file() {
  printf '%s/component-state.tsv' "$(df_journal_dir)"
}

df_profile_file() {
  printf '%s/profile' "$(df_journal_dir)"
}

df_profile_save() {
  local profile="$1"
  local file dir

  [[ -n "$profile" ]] || return 1
  file="$(df_profile_file)"
  dir="$(df_journal_dir)"
  mkdir -p "$dir"
  printf '%s\n' "$profile" >"$file"
}

df_profile_load() {
  local file
  file="$(df_profile_file)"
  if [[ -f "$file" ]]; then
    tr -d '[:space:]' <"$file"
    return 0
  fi
  return 1
}

df_profile_detect() {
  local saved
  if saved="$(df_profile_load 2>/dev/null)" && [[ -n "$saved" ]]; then
    printf '%s' "$saved"
    return 0
  fi

  # shellcheck source=platform.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"

  case "$(df_host_os_id)" in
    fedora)
      printf 'desktop\n'
      ;;
    *)
      if [[ -L "${HOME}/.bashrc" ]]; then
        printf 'devbox\n'
      elif [[ -f "${HOME}/.local/share/dotfiles/managed-paths" ]] &&
        grep -Fxq -- "${HOME}/.bashrc" "${HOME}/.local/share/dotfiles/managed-paths" 2>/dev/null; then
        printf 'server\n'
      else
        printf 'devbox\n'
      fi
      ;;
  esac
}

df_component_touch() {
  local component="$1"
  local version="${2:-}"
  local note="${3:-}"
  local file dir ts tmp

  [[ -n "$component" ]] || return 1
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  file="$(df_component_state_file)"
  dir="$(df_journal_dir)"
  mkdir -p "$dir"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp)"

  if [[ -f "$file" ]]; then
    awk -F '\t' -v c="$component" '($1 != c) { print }' "$file" >"$tmp"
  else
    : >"$tmp"
  fi
  printf '%s\t%s\t%s\t%s\n' "$component" "$ts" "$version" "$note" >>"$tmp"
  mv -f "$tmp" "$file"
}

df_component_get_field() {
  local component="$1"
  local field="$2"
  local file

  file="$(df_component_state_file)"
  [[ -f "$file" ]] || return 1
  awk -F '\t' -v c="$component" -v f="$field" '
    $1 == c {
      if (f == 1) { print $2; exit }
      if (f == 2) { print $3; exit }
      if (f == 3) { print $4; exit }
    }
  ' "$file"
}

df_component_age_days() {
  local component="$1"
  local ts ts_sec now days

  ts="$(df_component_get_field "$component" 1)"
  [[ -n "$ts" ]] || return 1

  ts_sec="$(date -u -d "$ts" +%s 2>/dev/null || true)"
  [[ -n "$ts_sec" ]] || return 1
  now="$(date -u +%s)"
  days=$(( (now - ts_sec) / 86400 ))
  printf '%s' "$days"
}

df_component_is_fresh() {
  local component="$1"
  local max_days="${2:-$DOTFILES_UPDATE_SKIP_DAYS}"
  local age

  age="$(df_component_age_days "$component" 2>/dev/null || true)"
  [[ -n "$age" ]] && (( age < max_days ))
}

df_component_age_label() {
  local component="$1"
  local ts age

  ts="$(df_component_get_field "$component" 1)"
  if [[ -z "$ts" ]]; then
    printf 'never'
    return 0
  fi

  age="$(df_component_age_days "$component" 2>/dev/null || echo 0)"
  if (( age == 0 )); then
    printf 'today (%s)' "$ts"
  elif (( age == 1 )); then
    printf '1 day ago (%s)' "$ts"
  else
    printf '%s days ago (%s)' "$age" "$ts"
  fi
}

df_component_detect_version() {
  local component="$1"
  local v

  case "$component" in
    neovim)
      v="$(nvim --version 2>/dev/null | head -n1 | sed -n 's/.*NVIM v\([0-9.]*\).*/\1/p')"
      ;;
    gh)
      v="$(gh --version 2>/dev/null | awk 'NR==1 {print $3}')"
      ;;
    lazygit)
      v="$(lazygit --version 2>/dev/null | awk '{print $NF}')"
      ;;
    btop)
      v="$(btop --version 2>/dev/null | awk '{print $2}')"
      ;;
    fzf)
      v="$(fzf --version 2>/dev/null | awk '{print $1}')"
      ;;
    starship)
      v="$(starship --version 2>/dev/null | awk '{print $2}')"
      ;;
    repo)
      v="$(git -C "${DOTFILES_DIR:-}" rev-parse --short HEAD 2>/dev/null || true)"
      ;;
    configs)
      v="$(git -C "${DOTFILES_DIR:-}" rev-parse --short HEAD 2>/dev/null || true)"
      ;;
    *)
      v=""
      ;;
  esac
  printf '%s' "$v"
}

df_component_list_known() {
  local profile="$1"
  case "$profile" in
    devbox)
      printf '%s\n' configs deps tools lazygit gh fzf tpm neovim btop fonts
      ;;
    desktop)
      printf '%s\n' configs deps tools lazygit gh fzf tpm neovim btop fonts starship
      ;;
    server)
      printf '%s\n' configs deps neovim fetch
      ;;
    lazyvim | lazyvim-lite)
      printf '%s\n' "$profile"
      ;;
    *)
      printf '%s\n' configs deps tools lazygit gh fzf tpm neovim btop fonts starship
      ;;
  esac
}

df_component_status_print() {
  local profile="$1"
  local component version ts_label

  printf 'Profile: %s (skip software updated within %s days on dotfiles update)\n' \
    "$profile" "$DOTFILES_UPDATE_SKIP_DAYS"
  printf '%-12s %-28s %s\n' 'COMPONENT' 'LAST UPDATED' 'VERSION'
  while IFS= read -r component; do
    [[ -n "$component" ]] || continue
    version="$(df_component_get_field "$component" 2)"
    ts_label="$(df_component_age_label "$component")"
    printf '%-12s %-28s %s\n' "$component" "$ts_label" "${version:--}"
  done < <(df_component_list_known "$profile")
}
