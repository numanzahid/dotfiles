#!/usr/bin/env bash
# Compact boxed fastfetch layout: ~/.config/fastfetch/banner.jsonc
# Arts: ~/.config/fastfetch/artN.txt  (0=none, 1=default). Add art4.txt etc.
# Custom art (not in git): ~/.config/custom-fetch-art.txt  (choice: c)
# Local padding overlay (not in git): ~/.config/custom-fetch-padding.jsonc
# Choice: ~/.local/share/dotfiles/fastfetch-art
# Plain `fastfetch` uses the built-in default (no config.jsonc).
#
# Sourced by ./install-fetch.sh for listing/preview. Executed as the banner.
# Fastfetch allows only one --config, so padding jsonc is applied via CLI flags.

df_ff_art_choice_file() {
  printf '%s/dotfiles/fastfetch-art\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

df_ff_art_dir() {
  if [[ -n "${DF_FF_ART_DIR:-}" ]]; then
    printf '%s\n' "$DF_FF_ART_DIR"
    return 0
  fi
  printf '%s/fastfetch\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Untracked local files. Never under ~/.config/fastfetch (that dir is the repo).
df_ff_art_custom_path() {
  printf '%s/custom-fetch-art.txt\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

df_ff_padding_path() {
  printf '%s/custom-fetch-padding.jsonc\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

df_ff_art_path() {
  local n="$1"
  if [[ "$n" == "c" ]]; then
    df_ff_art_custom_path
    return 0
  fi
  printf '%s/art%s.txt\n' "$(df_ff_art_dir)" "$n"
}

df_ff_art_normalize() {
  case "$1" in
    none) printf '0\n' ;;
    custom) printf 'c\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Copy art1 into the custom file only when it does not exist.
df_ff_art_ensure_custom() {
  local dest src old
  dest="$(df_ff_art_custom_path)"
  old="${XDG_CONFIG_HOME:-$HOME/.config}/.custom-fetch-art.txt"
  if [[ -e "$old" || -L "$old" ]] && [[ ! -e "$dest" && ! -L "$dest" ]]; then
    mv "$old" "$dest"
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  src="$(df_ff_art_path 1)"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dest"
  else
    : >"$dest"
  fi
}

# Placeholder matches banner.jsonc. Edit locally; never overwrite.
df_ff_padding_ensure() {
  local dest
  dest="$(df_ff_padding_path)"
  if [[ -e "$dest" || -L "$dest" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
// Local fastfetch logo padding. Not in git.
// right = gap between the art and the boxed keys.
{
  "logo": {
    "padding": {
      "top": 0,
      "left": 1,
      "right": 2
    }
  }
}
EOF
}

# Read "key": N from the padding jsonc (// comments stripped).
df_ff_padding_value() {
  local file="$1"
  local key="$2"
  local line
  [[ -f "$file" ]] || return 1
  line="$(sed -e 's|//.*||' "$file" | grep -E "\"${key}\"[[:space:]]*:" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  line="$(printf '%s\n' "$line" | tr -cd '0-9')"
  [[ "$line" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$line"
}

df_ff_padding_append_args() {
  local file n
  file="$(df_ff_padding_path)"
  [[ -f "$file" ]] || return 0
  n="$(df_ff_padding_value "$file" top || true)"
  if [[ -n "$n" ]]; then
    args+=(--logo-padding-top "$n")
  fi
  n="$(df_ff_padding_value "$file" left || true)"
  if [[ -n "$n" ]]; then
    args+=(--logo-padding-left "$n")
  fi
  n="$(df_ff_padding_value "$file" right || true)"
  if [[ -n "$n" ]]; then
    args+=(--logo-padding-right "$n")
  fi
  n="$(df_ff_padding_value "$file" bottom || true)"
  if [[ -n "$n" ]]; then
    args+=(--logo-padding-bottom "$n")
  fi
}

df_ff_art_ids() {
  local dir f base nullglob_on=0
  local -a ids=()
  dir="$(df_ff_art_dir)"
  [[ -d "$dir" ]] || return 0
  if shopt -q nullglob; then
    nullglob_on=1
  else
    shopt -s nullglob
  fi
  for f in "$dir"/art*.txt; do
    base="${f##*/}"
    if [[ "$base" =~ ^art([0-9]+)\.txt$ ]]; then
      ids+=("${BASH_REMATCH[1]}")
    fi
  done
  if [[ "$nullglob_on" -eq 0 ]]; then
    shopt -u nullglob
  fi
  if ((${#ids[@]} == 0)); then
    return 0
  fi
  printf '%s\n' "${ids[@]}" | sort -n -u
}

df_ff_art_valid() {
  local n
  n="$(df_ff_art_normalize "$1")"
  [[ "$n" == "0" ]] && return 0
  [[ "$n" == "c" ]] && return 0
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  [[ -f "$(df_ff_art_path "$n")" ]]
}

df_ff_art_current() {
  local f id
  f="$(df_ff_art_choice_file)"
  if [[ -f "$f" ]]; then
    id="$(df_ff_art_normalize "$(tr -d '[:space:]' <"$f")")"
    if df_ff_art_valid "$id"; then
      printf '%s\n' "$id"
      return 0
    fi
  fi
  printf '1\n'
}

df_ff_art_choices_csv() {
  local ids
  ids="$(df_ff_art_ids | paste -sd, -)"
  if [[ -n "$ids" ]]; then
    printf '0,%s,c\n' "$ids"
  else
    printf '0,c\n'
  fi
}

# Option number, then a blank line, then the art (or none).
df_ff_art_preview() {
  local n path
  n="$(df_ff_art_normalize "$1")"
  if [[ "$n" == "c" ]]; then
    printf 'c) custom (%s)\n' "$(df_ff_art_custom_path)"
  else
    printf '%s)\n' "$n"
  fi
  printf '\n'
  if [[ "$n" == "0" ]]; then
    printf '(none)\n'
  else
    if [[ "$n" == "c" ]]; then
      df_ff_art_ensure_custom
    fi
    path="$(df_ff_art_path "$n")"
    if [[ -f "$path" ]]; then
      cat "$path"
      if [[ -s "$path" && "$(tail -c 1 "$path")" != $'\n' ]]; then
        printf '\n'
      fi
    else
      printf '(missing %s)\n' "$path"
    fi
  fi
  printf '\n'
}

df_ff_art_show_all() {
  local n
  printf '\n'
  df_ff_art_preview 0
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    df_ff_art_preview "$n"
  done < <(df_ff_art_ids)
  df_ff_art_preview c
}

df_ff_art_set() {
  local choice
  choice="$(df_ff_art_normalize "$1")"
  if ! df_ff_art_valid "$choice"; then
    echo "Unknown text art: $1 (use $(df_ff_art_choices_csv))" >&2
    return 1
  fi
  if [[ "$choice" == "c" ]]; then
    df_ff_art_ensure_custom
  fi
  mkdir -p "$(dirname "$(df_ff_art_choice_file)")"
  printf '%s\n' "$choice" >"$(df_ff_art_choice_file)"
}

df_ff_logo_arg() {
  local choice path
  choice="$(df_ff_art_current)"
  if [[ "$choice" == "0" ]]; then
    printf 'none\n'
    return 0
  fi
  if [[ "$choice" == "c" ]]; then
    df_ff_art_ensure_custom
  fi
  path="$(df_ff_art_path "$choice")"
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  path="$(df_ff_art_path 1)"
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  printf 'none\n'
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

set -euo pipefail

if [[ "${1:-}" == "--ensure-local" ]]; then
  df_ff_art_ensure_custom
  df_ff_padding_ensure
  exit 0
fi

command -v fastfetch >/dev/null 2>&1 || exit 0

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/banner.jsonc"
logo="$(df_ff_logo_arg)"
args=(--config "$CONFIG" --logo "$logo")
df_ff_padding_ensure
df_ff_padding_append_args
exec fastfetch "${args[@]}"
