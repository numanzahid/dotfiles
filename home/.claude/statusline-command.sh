#!/bin/bash
# Status line: folder | git branch | model | 5h and 7d usage limits with reset times.
input=$(cat)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')

out="\033[01;34m${dir##*/}\033[00m"
branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
[ -n "$branch" ] && out+=" \033[01;36m(${branch})\033[00m"
[ -n "$model" ] && out+=" | \033[01;35m${model}\033[00m"

# rate_limits is absent until the first API response of a session.
read -r h_pct h_reset w_pct w_reset < <(echo "$input" | jq -r '[
  .rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at,
  .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at
] | map(. // "") | @tsv')

color() { if [ "$1" -ge 80 ]; then printf '01;31'; elif [ "$1" -ge 50 ]; then printf '01;33'; else printf '01;32'; fi; }

if [ -n "$h_pct" ]; then
  out+=" | 5h \033[$(color "$h_pct")m${h_pct}%\033[00m"
  [ -n "$h_reset" ] && out+=" ⟳ $(date -d "@$h_reset" +%H:%M)"
fi
if [ -n "$w_pct" ]; then
  out+=" | 7d \033[$(color "$w_pct")m${w_pct}%\033[00m"
  [ -n "$w_reset" ] && out+=" ⟳ $(date -d "@$w_reset" '+%a %H:%M')"
fi

printf '%b' "$out"
