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

df_version_sanitize() {
  local v="$1"
  # Keep status rows and component-state.tsv on one line.
  v="${v//$'\t'/ }"
  v="${v//$'\r'/}"
  v="${v%%$'\n'*}"
  v="$(printf '%s' "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  printf '%s' "$v"
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

  version="$(df_version_sanitize "$version")"
  note="$(df_version_sanitize "$note")"

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

df_component_forget() {
  local component="$1"
  local file tmp

  [[ -n "$component" ]] || return 1
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  file="$(df_component_state_file)"
  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  awk -F '\t' -v c="$component" '($1 != c) { print }' "$file" >"$tmp"
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
  printf '%s' "$(df_live_version "$component")"
}

df_live_version() {
  local component="$1"
  local v=""

  case "$component" in
    bat)
      v="$(bat --version 2>/dev/null | head -n1 | awk '{print $2}')"
      ;;
    fd)
      v="$(fd --version 2>/dev/null | head -n1 | awk '{print $2}')"
      ;;
    eza)
      v="$(eza --version 2>/dev/null | head -n1 | awk '{print $1}')"
      ;;
    zoxide)
      v="$(zoxide --version 2>/dev/null | head -n1 | awk '{print $1}')"
      ;;
    neovim)
      v="$(nvim --version 2>/dev/null | head -n1 | sed -n 's/.*NVIM v\([0-9.]*\).*/\1/p')"
      ;;
    gh)
      v="$(gh --version 2>/dev/null | head -n1 | awk '{print $3}')"
      ;;
    lazygit)
      v="$(lazygit --version 2>/dev/null | head -n1 | sed -n 's/.*version[= ]*\([0-9.]*\).*/\1/p')"
      ;;
    btop)
      v="$(btop --version 2>/dev/null | head -n1 | sed -n 's/.*version[= ]*\([0-9.]*\).*/\1/p')"
      ;;
    fzf)
      v="$(fzf --version 2>/dev/null | head -n1 | awk '{print $1}')"
      ;;
    tldr)
      v="$(tldr --version 2>/dev/null | head -n1 | awk '{print $2}')"
      ;;
    starship)
      v="$(starship --version 2>/dev/null | head -n1 | awk '{print $2}')"
      ;;
    fastfetch)
      v="$(fastfetch --version 2>/dev/null | head -n1 | awk '{print $1}')"
      ;;
    repo | configs)
      v="$(git -C "${DOTFILES_DIR:-$HOME/.dotfiles}" rev-parse --short HEAD 2>/dev/null || true)"
      ;;
    lazyvim | lazyvim-lite)
      v="$(get_nvim_profile 2>/dev/null || true)"
      [[ "$v" == "$component" ]] || v=""
      ;;
    *)
      v=""
      ;;
  esac
  df_version_sanitize "$v"
}

df_nvim_status_label() {
  local profile dir
  if [[ -f "${DOTFILES_DIR:-}/lazyvim/lib/nvim-profile.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DOTFILES_DIR}/lazyvim/lib/nvim-profile.sh"
    profile="$(get_nvim_profile 2>/dev/null || echo none)"
  else
    profile="unknown"
  fi
  case "$profile" in
    lazyvim | lazyvim-lite) printf '%s (active)' "$profile" ;;
    none)
      dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
      if [[ -L "$dir" ]]; then
        printf 'plain nvim (symlink)'
      elif [[ -f "$dir/init.lua" ]]; then
        printf 'plain nvim'
      else
        printf 'not configured'
      fi
      ;;
    *) printf '%s' "$profile" ;;
  esac
}

df_fetch_status_label() {
  local cfg art
  cfg="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc"
  if [[ ! -f "$cfg" ]]; then
    printf 'not installed'
    return 0
  fi
  if ! command -v fastfetch >/dev/null 2>&1; then
    printf 'config present, fastfetch binary missing'
    return 0
  fi
  if [[ -f "${DOTFILES_DIR:-}/scripts/fastfetch-banner.sh" ]]; then
    # shellcheck source=/dev/null
    source "${DOTFILES_DIR}/scripts/fastfetch-banner.sh"
    art="$(df_ff_art_current 2>/dev/null || echo '?')"
    printf 'installed (art: %s)' "$art"
  else
    printf 'installed'
  fi
}

df_status_print() {
  local profile component live recorded ts_label

  profile="$(df_profile_detect)"
  printf 'System profile: %s\n' "$profile"
  printf 'Dotfiles repo:  %s\n' "${DOTFILES_DIR:-$HOME/.dotfiles}"
  if git -C "${DOTFILES_DIR:-$HOME/.dotfiles}" rev-parse --short HEAD >/dev/null 2>&1; then
    printf 'Repo commit:    %s\n' "$(git -C "${DOTFILES_DIR:-$HOME/.dotfiles}" rev-parse --short HEAD)"
  fi
  printf 'Nvim:           %s\n' "$(df_nvim_status_label)"
  printf 'Fetch banner:   %s\n' "$(df_fetch_status_label)"
  printf '\nSoftware (live version | last updated):\n'
  printf '%-12s %-16s %-28s %s\n' 'COMPONENT' 'VERSION' 'LAST UPDATED' 'NOTES'

  while IFS= read -r component; do
    [[ -n "$component" ]] || continue
    if [[ "$component" == fetch ]] && ! df_component_get_field fetch 1 >/dev/null 2>&1; then
      continue
    fi
    live="$(df_live_version "$component")"
    recorded="$(df_component_get_field "$component" 2)"
    recorded="$(df_version_sanitize "$recorded")"
    ts_label="$(df_component_age_label "$component")"
    if [[ -z "$live" && -z "$recorded" ]]; then
      live="-"
    elif [[ -z "$live" ]]; then
      live="${recorded} (recorded)"
    fi
    printf '%-12s %-16s %-28s' "$component" "${live:--}" "$ts_label"
    if [[ "$component" != configs && "$component" != repo && "$component" != deps &&
      "$component" != tools && "$component" != fonts && "$component" != tpm &&
      "$component" != fetch ]] &&
      df_component_is_fresh "$component" "$DOTFILES_UPDATE_SKIP_DAYS"; then
      printf ' %s' '(skip on update)'
    fi
    printf '\n'
  done < <(df_component_list_known "$profile")
}

df_component_status_print() {
  df_status_print
}

df_component_list_known() {
  local profile="$1"
  case "$profile" in
    devbox)
      printf '%s\n' configs deps tools lazygit gh fzf tldr tpm neovim btop fonts
      ;;
    desktop)
      printf '%s\n' configs deps tools lazygit gh fzf tldr tpm neovim btop fonts starship
      ;;
    server)
      printf '%s\n' configs deps neovim
      ;;
    lazyvim | lazyvim-lite)
      printf '%s\n' "$profile"
      ;;
    *)
      printf '%s\n' configs deps tools lazygit gh fzf tldr tpm neovim btop fonts starship
      ;;
  esac
}
