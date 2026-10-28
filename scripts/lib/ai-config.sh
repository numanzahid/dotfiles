#!/usr/bin/env bash
# Merge dotfiles-owned keys into Claude Code and Codex config without owning
# the files. Both tools rewrite their config at runtime (trust entries, UI
# counters, approvals), so we never symlink or template the whole file: only
# the keys listed in ai-config/ are set; everything else is left alone.
#
#   Claude  ~/.claude/settings.json   JSON, merged with jq (repo keys win)
#   Codex   ~/.codex/config.toml      TOML, line-edited key by key and
#                                     re-parsed with python3 tomllib
#
# Reusable assets (statusline, skills, agents, commands, prompts) are
# symlinked one item at a time so tool-managed siblings are never swallowed.
# Used by ai-rules-install.sh, ai-config-install.sh, ai-agent-sudo-install.sh.
# Requires: log, run, and link.sh helpers (SOURCE_DIR / DOTFILES_DIR optional).

# Repo root derived from this file, for callers (uninstall.sh) that do not set
# SOURCE_DIR / DOTFILES_DIR.
DF_AI_CONFIG_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

df_ai_config_source_dir() {
  printf '%s' "${SOURCE_DIR:-$DF_AI_CONFIG_REPO_ROOT/home}"
}

df_ai_config_root() {
  printf '%s/.config/dotfiles/ai-config' "$(df_ai_config_source_dir)"
}

df_ai_config_home() {
  printf '%s' "${TARGET_HOME:-$HOME}"
}

df_ai_config_claude_settings() {
  printf '%s/.claude/settings.json' "$(df_ai_config_home)"
}

df_ai_config_codex_config() {
  printf '%s/.codex/config.toml' "$(df_ai_config_home)"
}

# ---------------------------------------------------------------------------
# Shared write path
# ---------------------------------------------------------------------------

# One copy of the file as it was before we first touched it.
df_ai_config_backup_once() {
  local file="$1"
  local name backup

  [[ -f "$file" ]] || return 0
  name="$(basename "$(dirname "$file")")-$(basename "$file")"
  name="${name#.}"
  backup="$(df_backups_dir)/ai-config/${name}.pre-ai-config"
  [[ -e "$backup" ]] && return 0
  [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0

  mkdir -p "$(dirname "$backup")"
  cp -p "$file" "$backup"
  log "backup before first merge: $file -> $backup"
}

# Replace file contents with tmp (keeps mode/inode of an existing file).
df_ai_config_commit() {
  local file="$1"
  local tmp="$2"
  local label="$3"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log "would update $label: $file"
    return 0
  fi
  df_ai_config_backup_once "$file"
  mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]]; then
    cat "$tmp" >"$file"
  else
    install -m 600 "$tmp" "$file"
  fi
  log "updated $label: $file"
  df_journal_once patch "$file" "ai-config"
}

# ---------------------------------------------------------------------------
# JSON (Claude Code)
# ---------------------------------------------------------------------------

df_json_ready() {
  local file="$1"

  if ! command -v jq >/dev/null 2>&1; then
    log "skip $file (jq missing)"
    return 1
  fi
  if [[ -f "$file" ]] && ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
    log "skip $file (not a valid JSON object)"
    return 1
  fi
  return 0
}

# df_json_merge FILE FRAGMENT_JSON
# Recursive merge; keys in the fragment win, all other keys are kept.
df_json_merge() {
  local file="$1"
  local frag="$2"
  local tmp

  df_json_ready "$file" || return 0
  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    jq --argjson f "$frag" '. * $f' "$file" >"$tmp" 2>/dev/null || true
  else
    jq -n --argjson f "$frag" '$f' >"$tmp" 2>/dev/null || true
  fi
  if [[ ! -s "$tmp" ]]; then
    log "skip $file (could not merge fragment)"
    rm -f "$tmp"
    return 0
  fi
  if [[ -f "$file" && "$(jq -S . "$file")" == "$(jq -S . "$tmp")" ]]; then
    log "up to date: $file"
    rm -f "$tmp"
    return 0
  fi
  df_ai_config_commit "$file" "$tmp" "JSON keys"
  rm -f "$tmp"
}

# df_json_unmerge FILE FRAGMENT_JSON
# Remove fragment leaves from FILE, but only where the value still equals ours.
df_json_unmerge() {
  local file="$1"
  local frag="$2"
  local tmp

  [[ -f "$file" ]] || return 0
  df_json_ready "$file" || return 0
  tmp="$(mktemp)"
  jq --argjson f "$frag" '
    reduce ($f | paths(type != "object" and type != "array")) as $p (.;
      if getpath($p) == ($f | getpath($p)) then delpaths([$p]) else . end)
    | walk(if type == "object" then with_entries(select(.value != {})) else . end)
  ' "$file" >"$tmp" 2>/dev/null || true
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    return 0
  fi
  if [[ "$(jq -S . "$file")" == "$(jq -S . "$tmp")" ]]; then
    rm -f "$tmp"
    return 0
  fi
  df_ai_config_commit "$file" "$tmp" "JSON keys (removed)"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# TOML (Codex). Single-line values only; the result is re-parsed before it is
# written, so a bad edit is skipped instead of breaking the tool.
# ---------------------------------------------------------------------------

df_toml_can_edit() {
  command -v python3 >/dev/null 2>&1 && python3 -I -c 'import tomllib' >/dev/null 2>&1
}

df_toml_valid() {
  python3 -I -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    tomllib.load(f)
' "$1" >/dev/null 2>&1
}

# Write tmp over file when it parses and differs.
df_toml_finish() {
  local file="$1"
  local tmp="$2"
  local label="$3"

  if ! df_toml_valid "$tmp"; then
    log "skip $file ($label would make it invalid TOML)"
    rm -f "$tmp"
    return 0
  fi
  if [[ -f "$file" ]] && cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  df_ai_config_commit "$file" "$tmp" "$label"
  rm -f "$tmp"
}

df_toml_src() {
  if [[ -f "$1" ]]; then
    printf '%s' "$1"
  else
    printf '/dev/null'
  fi
}

# df_toml_get_line FILE TABLE KEY  (TABLE "" = top level) -> first matching line
df_toml_get_line() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  T="$2" K="$3" awk '
    BEGIN { table = ENVIRON["T"]; key = ENVIRON["K"]; cur = "" }
    /^[ \t]*\[/ {
      name = $0
      sub(/^[ \t]*\[+[ \t]*/, "", name)
      sub(/[ \t]*\]+.*$/, "", name)
      gsub(/[ \t]/, "", name)
      cur = name
      next
    }
    cur == table && $0 ~ ("^[ \t]*" key "[ \t]*=") { print; exit }
  ' "$file"
}

# df_toml_set FILE TABLE KEY VALUE  (VALUE is TOML text, e.g. '"on-request"')
df_toml_set() {
  local file="$1"
  local table="$2"
  local key="$3"
  local value="$4"
  local tmp

  df_toml_can_edit || {
    log "skip $file (needs python3 >= 3.11 for TOML validation)"
    return 0
  }
  tmp="$(mktemp)"
  T="$table" K="$key" V="$value" awk '
    function flush_blanks(  i) { for (i = 0; i < nb; i++) print ""; nb = 0 }
    function emit() { print key " = " value; done = 1 }
    BEGIN { table = ENVIRON["T"]; key = ENVIRON["K"]; value = ENVIRON["V"]; cur = ""; nb = 0 }
    /^[ \t]*$/ { nb++; next }
    /^[ \t]*\[/ {
      if (cur == table && !done) emit()
      flush_blanks()
      name = $0
      sub(/^[ \t]*\[+[ \t]*/, "", name)
      sub(/[ \t]*\]+.*$/, "", name)
      gsub(/[ \t]/, "", name)
      cur = name
      if (cur == table) seen = 1
      print
      next
    }
    cur == table && $0 ~ ("^[ \t]*" key "[ \t]*=") {
      flush_blanks()
      if (!done) emit()
      next
    }
    { flush_blanks(); print }
    END {
      if (cur == table && !done) emit()
      flush_blanks()
      if (!done) {
        if (NR > 0) print ""
        print "[" table "]"
        print key " = " value
      }
    }
  ' "$(df_toml_src "$file")" >"$tmp"
  df_toml_finish "$file" "$tmp" "TOML key ${table:+$table.}$key"
}

# df_toml_unset FILE TABLE KEY
df_toml_unset() {
  local file="$1"
  local table="$2"
  local key="$3"
  local tmp

  [[ -f "$file" ]] || return 0
  df_toml_can_edit || return 0
  [[ -n "$(df_toml_get_line "$file" "$table" "$key")" ]] || return 0
  tmp="$(mktemp)"
  T="$table" K="$key" awk '
    BEGIN { table = ENVIRON["T"]; key = ENVIRON["K"]; cur = "" }
    /^[ \t]*\[/ {
      name = $0
      sub(/^[ \t]*\[+[ \t]*/, "", name)
      sub(/[ \t]*\]+.*$/, "", name)
      gsub(/[ \t]/, "", name)
      cur = name
    }
    cur == table && $0 ~ ("^[ \t]*" key "[ \t]*=") { next }
    { print }
  ' "$file" >"$tmp"
  [[ -z "$table" ]] || df_toml_drop_empty_table "$tmp" "$table"
  df_toml_finish "$file" "$tmp" "TOML key ${table:+$table.}$key (removed)"
}

# Remove a [table] header (and its blank lines) when nothing is left under it.
# Edits FILE in place (callers pass a temp copy).
df_toml_drop_empty_table() {
  local file="$1"
  local table="$2"
  local tmp

  tmp="$(mktemp)"
  T="$table" awk '
    function is_header(l) { return l ~ /^[ \t]*\[/ }
    function name_of(l,  n) {
      n = l
      sub(/^[ \t]*\[+[ \t]*/, "", n)
      sub(/[ \t]*\]+.*$/, "", n)
      gsub(/[ \t]/, "", n)
      return n
    }
    { line[NR] = $0 }
    END {
      table = ENVIRON["T"]
      for (i = 1; i <= NR; i++) {
        if (is_header(line[i]) && name_of(line[i]) == table) {
          j = i + 1
          while (j <= NR && line[j] ~ /^[ \t]*$/) j++
          if (j > NR || is_header(line[j])) { i = j - 1; continue }
        }
        print line[i]
      }
    }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# Trim leading/trailing whitespace of $1.
df_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Entries of a one-line inline table (` key = "v", other = "w" `), one per line.
df_toml_inline_entries() {
  local line="$1"
  local inner part
  local -a parts=()

  inner="${line#*\{}"
  inner="${inner%\}*}"
  IFS=',' read -r -a parts <<<"$inner"
  for part in "${parts[@]}"; do
    part="$(df_trim "$part")"
    [[ -n "$part" ]] && printf '%s\n' "$part"
  done
}

# df_toml_env_set FILE TABLE KEY NAME VALUE
# Set NAME = "VALUE" inside a one-line inline table (e.g. codex
# shell_environment_policy.set), keeping other entries.
df_toml_env_set() {
  local file="$1"
  local table="$2"
  local key="$3"
  local name="$4"
  local value="$5"
  local cur entry joined=""

  cur="$(df_toml_get_line "$file" "$table" "$key")"
  if [[ -n "$cur" ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      case "$entry" in
        "$name "* | "$name="*) continue ;;
      esac
      joined+="${joined:+, }$entry"
    done < <(df_toml_inline_entries "$cur")
  fi
  joined+="${joined:+, }$name = \"$value\""
  df_toml_set "$file" "$table" "$key" "{ $joined }"
}

# df_toml_env_unset FILE TABLE KEY NAME
df_toml_env_unset() {
  local file="$1"
  local table="$2"
  local key="$3"
  local name="$4"
  local cur entry joined=""

  cur="$(df_toml_get_line "$file" "$table" "$key")"
  [[ -n "$cur" ]] || return 0
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    case "$entry" in
      "$name "* | "$name="*) continue ;;
    esac
    joined+="${joined:+, }$entry"
  done < <(df_toml_inline_entries "$cur")
  if [[ -n "$joined" ]]; then
    df_toml_set "$file" "$table" "$key" "{ $joined }"
  else
    df_toml_unset "$file" "$table" "$key"
  fi
}

# Apply every `key = value` (optionally under [table]) of a base file.
df_toml_merge_file() {
  local file="$1"
  local base="$2"
  local line table="" key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(df_trim "$line")"
    case "$line" in
      '' | '#'*) continue ;;
      '['*)
        table="${line#\[}"
        table="${table%%\]*}"
        table="${table// /}"
        continue
        ;;
    esac
    key="$(df_trim "${line%%=*}")"
    value="$(df_trim "${line#*=}")"
    df_toml_set "$file" "$table" "$key" "$value"
  done <"$base"
}

df_toml_unmerge_file() {
  local file="$1"
  local base="$2"
  local line table="" key

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(df_trim "$line")"
    case "$line" in
      '' | '#'*) continue ;;
      '['*)
        table="${line#\[}"
        table="${table%%\]*}"
        table="${table// /}"
        continue
        ;;
    esac
    key="$(df_trim "${line%%=*}")"
    df_toml_unset "$file" "$table" "$key"
  done <"$base"
}

# ---------------------------------------------------------------------------
# Linked assets
# ---------------------------------------------------------------------------

# Servers get real copies (the clone may be deleted afterwards); devbox and
# desktop get symlinks. Force with DF_AI_COPY_MODE=1 (copy) or 0 (link), which
# the --copy / --link flags of the ai-*-install.sh scripts set.
df_ai_copy_mode() {
  local profile=""

  if [[ -n "${DF_AI_COPY_MODE:-}" ]]; then
    [[ "$DF_AI_COPY_MODE" == 1 ]]
    return
  fi
  [[ -f "$(df_journal_dir)/profile" ]] && profile="$(cat "$(df_journal_dir)/profile")"
  [[ "$profile" == server ]]
}

# Symlink SRC to DEST, or copy it in copy mode. Either way: backed up once,
# tracked in managed-paths, journaled (link/copy) so uninstall can revert it.
df_ai_place() {
  local src="$1"
  local dest="$2"

  if ! df_ai_copy_mode; then
    df_link_path "$src" "$dest"
    return 0
  fi

  if [[ ! -e "$src" ]]; then
    log "skip missing source: $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    log "replace symlink with copy: $dest"
    run rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    if [[ -f "$src" ]] && df_same_file "$src" "$dest"; then
      log "up to date: $dest"
      df_track_path "$dest"
      df_journal_once copy "$dest" "$src"
      return 0
    fi
    df_stash_original_if_needed "$src" "$dest"
    [[ -e "$dest" ]] && run rm -rf "$dest"
  fi
  log "copy: $src -> $dest"
  run cp -a "$src" "$dest"
  df_track_path "$dest"
  df_journal_once copy "$dest" "$src"
}

# Place each child of SRC_DIR into DEST_DIR (never the directory itself).
df_ai_config_link_children() {
  local src_dir="$1"
  local dest_dir="$2"
  local item

  [[ -d "$src_dir" ]] || return 0
  shopt -s nullglob
  local -a items=("$src_dir"/*)
  shopt -u nullglob
  ((${#items[@]} > 0)) || return 0

  mkdir -p "$dest_dir"
  for item in "${items[@]}"; do
    df_ai_place "$item" "$dest_dir/$(basename "$item")"
  done
}

# ---------------------------------------------------------------------------
# Claude Code / Codex install
# ---------------------------------------------------------------------------

df_ai_config_install_claude() {
  local home base dest
  home="$(df_ai_config_home)"
  base="$(df_ai_config_root)/claude/settings.base.json"
  dest="$(df_ai_config_claude_settings)"

  if [[ -f "$base" ]]; then
    df_json_merge "$dest" "$(cat "$base")"
  else
    log "skip claude settings (missing $base)"
  fi

  df_ai_place "$(df_ai_config_source_dir)/.claude/statusline-command.sh" "$home/.claude/statusline-command.sh"
  df_ai_config_link_children "$(df_ai_config_source_dir)/.claude/skills" "$home/.claude/skills"
  df_ai_config_link_children "$(df_ai_config_source_dir)/.claude/agents" "$home/.claude/agents"
  df_ai_config_link_children "$(df_ai_config_source_dir)/.claude/commands" "$home/.claude/commands"
}

df_ai_config_install_codex() {
  local home base dest filtered
  home="$(df_ai_config_home)"
  base="$(df_ai_config_root)/codex/config.base.toml"
  dest="$(df_ai_config_codex_config)"

  if [[ -f "$base" ]]; then
    if df_ai_config_nosandbox_on; then
      # --nosandbox owns approval_policy while it is in effect.
      filtered="$(mktemp)"
      grep -v '^[[:space:]]*approval_policy[[:space:]]*=' "$base" >"$filtered" || true
      df_toml_merge_file "$dest" "$filtered"
      rm -f "$filtered"
    else
      df_toml_merge_file "$dest" "$base"
    fi
  else
    log "skip codex config (missing $base)"
  fi

  df_ai_config_link_children "$(df_ai_config_source_dir)/.codex/prompts" "$home/.codex/prompts"
  df_ai_config_link_children "$(df_ai_config_source_dir)/.codex/skills" "$home/.codex/skills"
}

# ---------------------------------------------------------------------------
# Sandbox and approvals: --nosandbox / --sandbox. Independent of sudo.
#   --nosandbox  Claude sandbox off + bypassPermissions, Codex full access +
#                approval_policy "never". Remembered (journal patch nosandbox),
#                so later runs without a flag, e.g. dotfiles update, keep it.
#   --sandbox    Put both back. No flag leaves the current state alone.
# ---------------------------------------------------------------------------

# True while --nosandbox is in effect. agent-sudo-no-approvals is the marker
# that older ai-sudo runs left behind.
df_ai_config_nosandbox_on() {
  df_journal_has patch nosandbox || df_journal_has patch agent-sudo-no-approvals
}

df_ai_config_nosandbox_claude_fragment() {
  printf '%s' '{"sandbox":{"enabled":false},"permissions":{"defaultMode":"bypassPermissions"},"skipDangerousModePermissionPrompt":true}'
}

df_ai_config_nosandbox_apply() {
  local claude codex
  claude="$(df_ai_config_claude_settings)"
  codex="$(df_ai_config_codex_config)"

  if command -v jq >/dev/null 2>&1; then
    df_json_merge "$claude" "$(df_ai_config_nosandbox_claude_fragment)"
  else
    log "skip $claude (jq missing)"
  fi
  df_toml_set "$codex" "" sandbox_mode '"danger-full-access"'
  df_toml_set "$codex" "" approval_policy '"never"'
  df_journal_once patch nosandbox "ai-config --nosandbox"
}

# Remove the keys --nosandbox set and forget the marker (no base re-merge).
df_ai_config_sandbox_unset() {
  local claude codex
  claude="$(df_ai_config_claude_settings)"
  codex="$(df_ai_config_codex_config)"

  if command -v jq >/dev/null 2>&1; then
    df_json_unmerge "$claude" "$(df_ai_config_nosandbox_claude_fragment)"
  fi
  df_toml_unset "$codex" "" sandbox_mode
  df_toml_unset "$codex" "" approval_policy
  df_journal_remove_kind_path patch nosandbox
  df_journal_remove_kind_path patch agent-sudo-no-approvals
}

df_ai_config_sandbox_restore() {
  df_ai_config_sandbox_unset
  # The base file's approval_policy comes back.
  df_ai_config_install_codex
}

# DF_AI_SANDBOX_ACTION is set by --nosandbox (off) / --sandbox (on); unset = leave as is.
df_ai_config_apply_sandbox_choice() {
  case "${DF_AI_SANDBOX_ACTION:-}" in
    off) df_ai_config_nosandbox_apply ;;
    on) df_ai_config_sandbox_restore ;;
  esac
  return 0
}

df_ai_config_install_all() {
  df_ai_config_install_claude
  df_ai_config_install_codex
  df_ai_config_apply_sandbox_choice
}

# Uninstall: drop the keys we merged (links are reverted from the journal).
df_ai_config_unmerge_all() {
  local base

  if df_ai_config_nosandbox_on; then
    df_ai_config_sandbox_unset
  fi
  base="$(df_ai_config_root)/claude/settings.base.json"
  [[ -f "$base" ]] && df_json_unmerge "$(df_ai_config_claude_settings)" "$(cat "$base")"
  base="$(df_ai_config_root)/codex/config.base.toml"
  [[ -f "$base" ]] && df_toml_unmerge_file "$(df_ai_config_codex_config)" "$base"
  return 0
}

# ---------------------------------------------------------------------------
# Agent sudo: SUDO_ASKPASS via a tmux password popup (sudo only; the sandbox
# is --nosandbox above). Driven by ai-agent-sudo-install.sh; kept here so
# uninstall.sh can revert it.
# ---------------------------------------------------------------------------

df_agent_sudo_src_dir() {
  printf '%s/scripts/ai-agent-sudo' "${DOTFILES_DIR:-$DF_AI_CONFIG_REPO_ROOT}"
}

df_agent_sudo_askpass_path() {
  printf '%s/.local/bin/ai-askpass' "$(df_ai_config_home)"
}

df_agent_sudo_claude_fragment() {
  jq -n -c --arg askpass "$(df_agent_sudo_askpass_path)" '{env: {SUDO_ASKPASS: $askpass}}'
}

df_agent_sudo_merge() {
  local claude codex
  claude="$(df_ai_config_claude_settings)"
  codex="$(df_ai_config_codex_config)"

  if command -v jq >/dev/null 2>&1; then
    df_json_merge "$claude" "$(df_agent_sudo_claude_fragment)"
  else
    log "skip $claude (jq missing)"
  fi
  df_toml_env_set "$codex" shell_environment_policy set SUDO_ASKPASS "$(df_agent_sudo_askpass_path)"
}

df_agent_sudo_unmerge() {
  local claude codex
  claude="$(df_ai_config_claude_settings)"
  codex="$(df_ai_config_codex_config)"

  if command -v jq >/dev/null 2>&1; then
    df_json_unmerge "$claude" "$(df_agent_sudo_claude_fragment)"
    # Value written before tmux-askpass became ai-askpass.
    df_json_unmerge "$claude" "$(jq -n -c --arg a "$(df_ai_config_home)/.local/bin/tmux-askpass" '{env: {SUDO_ASKPASS: $a}}')"
  fi
  df_toml_env_unset "$codex" shell_environment_policy set SUDO_ASKPASS
  df_journal_remove_kind_path patch agent-sudo
}
