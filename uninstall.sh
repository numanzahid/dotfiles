#!/usr/bin/env bash
# Undo a dotfiles install using machine-local records:
#   ~/.local/share/dotfiles/managed-paths
#   dest.pre-dotfiles originals
#   ~/.local/share/dotfiles/install-journal.tsv
#
# Interactive uninstall. Prompts for dry-run, uninstall, or purge.
# Does not revert locale, does not apt autoremove, does not undo LazyVim / LazyVim-lite.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
TARGET_HOME="${HOME:?}"

# shellcheck source=scripts/lib/journal.sh
source "$SCRIPTS_DIR/lib/journal.sh"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPTS_DIR/lib/privilege.sh"
# shellcheck source=scripts/lib/pfetch-remove.sh
source "$SCRIPTS_DIR/lib/pfetch-remove.sh"
# shellcheck source=scripts/lib/gui-terminal.sh
source "$SCRIPTS_DIR/lib/gui-terminal.sh"

MODE=""
APPLY=0
PURGE=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh
       dotfiles uninstall

Undo ./devbox.sh, ./desktop.sh, or ./server.sh.
Prompts for dry-run, uninstall, or purge.

  Dry run     Show actions (+ lines), change nothing
  Uninstall   Restore originals (*.pre-dotfiles), remove journaled tools,
              clean legacy leftovers. Keeps ~/.dotfiles and install records.
  Purge       Uninstall plus trash ~/.dotfiles, ~/.local/share/dotfiles,
              and ~/.install-scripts/dotfiles-cli (server copy).

Pre-journal hosts: uninstall/purge auto-seeds the journal from detected
files before removing tools.

Does not undo LazyVim:
  ./lazyvim/install-lazyvim.sh
  ./lazyvim-lite/install-lazyvim-lite.sh
If ~/.config/nvim is a LazyVim profile, it is left untouched.

Non-interactive: set DOTFILES_UNINSTALL_MODE to dry-run, uninstall, or purge.

Records:
  ~/.local/share/dotfiles/managed-paths
  ~/.local/share/dotfiles/install-journal.tsv
  ~/.local/share/dotfiles/install.log
  dest.pre-dotfiles next to each replaced path

Uninstall reverts every journaled kind except skip, locale, hide-clone,
and backup (backup uses dest.pre-dotfiles on disk). See README "Install journal".

Not undone: LazyVim/lite, locale, skipped files (~/.ssh/config, a real
prompt.sh), ~/.cargo ~/.rustup, tmux *.log in $HOME, unrelated project dirs.

Options:
  -h, --help           Show this help
EOF
}

log() {
  printf '[uninstall] %s\n' "$*"
}

prompt_uninstall_mode() {
  local answer

  if [[ -n "${DOTFILES_UNINSTALL_MODE:-}" ]]; then
    MODE="$DOTFILES_UNINSTALL_MODE"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    MODE=dry-run
    log "not a TTY; defaulting to dry-run (set DOTFILES_UNINSTALL_MODE to uninstall or purge)"
    return 0
  fi

  cat <<'EOF'

Dotfiles uninstall

  1) Dry run (show actions, change nothing)
  2) Uninstall (restore configs, remove journaled tools)
  3) Purge (uninstall + remove clone and dotfiles state)

EOF
  printf 'Choice [1]: '
  read -r answer
  case "${answer:-1}" in
    1 | "" | dry-run | dry) MODE=dry-run ;;
    2 | uninstall) MODE=uninstall ;;
    3 | purge) MODE=purge ;;
    *)
      echo "Invalid choice: $answer" >&2
      exit 1
      ;;
  esac
}

journal_is_empty() {
  local file
  file="$(df_journal_file)"
  [[ ! -f "$file" ]] && return 0
  [[ ! -s "$file" ]]
}

auto_seed_if_needed() {
  if [[ "$APPLY" -eq 0 ]]; then
    if journal_is_empty; then
      log "no journal; on uninstall/purge will auto-seed from detected files"
    fi
    return 0
  fi
  if journal_is_empty; then
    log "no journal; auto-seeding from detected files"
    seed_workstation
  fi
}

# shellcheck source=scripts/lib/ai-rules.sh
source "$SCRIPTS_DIR/lib/ai-rules.sh"

run() {
  if [[ "$APPLY" -eq 0 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

df_original_backup_path() {
  printf '%s.pre-dotfiles' "$1"
}

df_managed_paths_file() {
  printf '%s/dotfiles/managed-paths' "${XDG_DATA_HOME:-$TARGET_HOME/.local/share}"
}

is_home_path() {
  local p="$1"
  [[ "$p" == "$TARGET_HOME" || "$p" == "$TARGET_HOME"/* ]]
}

# LazyVim / lite own ~/.config/nvim. Normal uninstall must not revert it.
is_lazyvim_owned() {
  local dest="$1"
  local nvim_dest="$TARGET_HOME/.config/nvim"
  local lazyvim_src="$DOTFILES_DIR/home/.config/nvim"
  local profile_file="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/nvim-profile"
  local profile real_dest real_src

  if [[ "$dest" == "$profile_file" ]]; then
    return 0
  fi
  if [[ "$dest" != "$nvim_dest" && "$dest" != "$nvim_dest"/* ]]; then
    return 1
  fi
  if [[ -f "$profile_file" ]]; then
    profile="$(tr -d '[:space:]' <"$profile_file")"
    case "$profile" in
      lazyvim | lazyvim-lite) return 0 ;;
    esac
  fi
  real_dest="$(readlink -f "$nvim_dest" 2>/dev/null || true)"
  real_src="$(readlink -f "$lazyvim_src" 2>/dev/null || true)"
  if [[ -n "$real_dest" && -n "$real_src" && ( "$real_dest" == "$real_src" || "$real_dest" == "$real_src"/* ) ]]; then
    return 0
  fi
  return 1
}

clone_dir() {
  local d
  d="$(readlink -f "$TARGET_HOME/.dotfiles" 2>/dev/null || true)"
  if [[ -n "$d" && -d "$d" ]]; then
    printf '%s' "$d"
    return 0
  fi
  d="$(readlink -f "$DOTFILES_DIR" 2>/dev/null || true)"
  printf '%s' "$d"
}

# True when dest is a real file/dir inside the clone (via a parent symlink).
# Removing it would delete repo files. A symlink at dest itself is OK to rm.
resolves_inside_clone() {
  local dest="$1"
  local clone real
  [[ -L "$dest" ]] && return 1
  clone="$(clone_dir)"
  [[ -n "$clone" ]] || return 1
  real="$(readlink -f "$dest" 2>/dev/null || true)"
  [[ -n "$real" ]] || return 1
  [[ "$real" == "$clone" || "$real" == "$clone"/* ]]
}

needs_sudo_for_tools() {
  local journal p
  if df_legacy_pfetch_system_present; then
    return 0
  fi
  journal="$(df_journal_file)"
  [[ -f "$journal" ]] || return 1
  while IFS=$'\t' read -r _ts kind p _extra; do
    case "$kind" in
      binary | symlink | opt-tree | package-new | system-dropin)
        if [[ -n "$p" ]] && ! is_home_path "$p"; then
          return 0
        fi
        if [[ "$kind" == "package-new" ]]; then
          return 0
        fi
        ;;
    esac
  done <"$journal"
  return 1
}

remove_home_path() {
  local dest="$1"

  if [[ "$dest" == "$TARGET_HOME" || "$dest" == "/" ]]; then
    log "refusing to remove: $dest"
    return 1
  fi

  if resolves_inside_clone "$dest"; then
    log "skip (inside clone, not a home symlink): $dest -> $(readlink -f "$dest")"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    run rm -f "$dest"
    return 0
  fi
  if [[ ! -e "$dest" ]]; then
    return 0
  fi
  if command -v trash-put >/dev/null 2>&1; then
    run trash-put "$dest"
  elif [[ -d "$dest" ]]; then
    run rm -rf "$dest"
  else
    run rm -f "$dest"
  fi
}

remove_system_path() {
  local dest="$1"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    log "already gone: $dest"
    return 0
  fi
  if [[ -d "$dest" && ! -L "$dest" ]]; then
    run df_run_privileged rm -rf "$dest"
  else
    run df_run_privileged rm -f "$dest"
  fi
}

restore_skel() {
  local dest="$1"
  local base
  base="$(basename "$dest")"
  case "$base" in
    .bashrc | .profile | .bash_logout)
      if [[ -f "/etc/skel/$base" ]]; then
        log "no original backup; restore from /etc/skel: $dest"
        run cp "/etc/skel/$base" "$dest"
        return 0
      fi
      ;;
  esac
  return 1
}

restore_dest() {
  local dest="$1"
  local backup
  backup="$(df_original_backup_path "$dest")"

  if resolves_inside_clone "$dest"; then
    log "skip restore (would delete clone file): $dest"
    return 0
  fi

  if [[ ! -e "$dest" && ! -L "$dest" && ! -e "$backup" && ! -L "$backup" ]]; then
    log "nothing to undo: $dest"
    return 0
  fi

  if [[ -e "$backup" || -L "$backup" ]]; then
    log "restore original: $backup -> $dest"
    if [[ -e "$dest" || -L "$dest" ]]; then
      remove_home_path "$dest"
    fi
    run mv "$backup" "$dest"
    return 0
  fi

  log "no original backup; remove ours: $dest"
  if [[ -e "$dest" || -L "$dest" ]]; then
    remove_home_path "$dest"
  fi
  restore_skel "$dest" || true
}

collect_home_dests() {
  local file p
  local -A seen=()

  file="$(df_managed_paths_file)"
  if [[ -f "$file" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      is_home_path "$p" || continue
      seen["$p"]=1
    done <"$file"
  fi

  file="$(df_journal_file)"
  if [[ -f "$file" ]]; then
    while IFS=$'\t' read -r _ts kind p _extra; do
      case "$kind" in
        backup | link | copy | binary)
          [[ -n "$p" ]] || continue
          is_home_path "$p" || continue
          seen["$p"]=1
          ;;
      esac
    done <"$file"
  fi

  if ((${#seen[@]} == 0)); then
    return 0
  fi
  printf '%s\n' "${!seen[@]}" | awk '{ print length, $0 }' | sort -nr | cut -d' ' -f2-
}

seed_if_new() {
  local kind="$1"
  local path="$2"
  local extra="${3:-seed-workstation}"

  if df_journal_has "$kind" "$path"; then
    log "journal already has: $kind $path"
    return 0
  fi
  log "seed: $kind $path"
  if [[ "$APPLY" -eq 1 ]]; then
    df_journal_append "$kind" "$path" "$extra"
  fi
}

seed_if_exists() {
  local kind="$1"
  local path="$2"
  if [[ -e "$path" || -L "$path" ]]; then
    seed_if_new "$kind" "$path"
  fi
}

seed_workstation() {
  local b p target pkg

  log "seed journal for a pre-journal full install"
  log "packages: only typical new ones (ripgrep, trash-cli, gh), not git/tmux/bash"

  for b in bat fd zoxide eza lazygit btop nvim fastfetch starship pfetch tldr; do
    seed_if_exists binary "/usr/local/bin/$b"
  done
  seed_if_exists binary "$TARGET_HOME/.local/bin/alacritty"
  seed_if_exists binary "$TARGET_HOME/.local/kitty.app"
  seed_if_exists link "$TARGET_HOME/.local/bin/kitty"
  seed_if_exists link "$TARGET_HOME/.local/bin/kitten"
  if df_pfetch_is_our_opt; then
    seed_if_new opt-tree /opt/pfetch
  fi

  if [[ -L /opt/nvim || -e /opt/nvim ]]; then
    seed_if_new symlink /opt/nvim
  fi
  target="$(readlink -f /opt/nvim 2>/dev/null || true)"
  if [[ -n "$target" && "$target" == /opt/nvim-* && -d "$target" ]]; then
    seed_if_new opt-tree "$target"
  fi
  shopt -s nullglob
  for p in /opt/nvim-*; do
    [[ -d "$p" && ! -L "$p" ]] || continue
    seed_if_new opt-tree "$p"
  done
  shopt -u nullglob

  seed_if_exists git-clone "$TARGET_HOME/.fzf"
  seed_if_exists copy "$TARGET_HOME/.fzf.bash"
  seed_if_exists git-clone "$TARGET_HOME/.tmux/plugins/tpm"
  if [[ -L "$TARGET_HOME/.gitconfig" ]]; then
    seed_if_new link "$TARGET_HOME/.gitconfig"
  fi
  seed_if_exists copy "$TARGET_HOME/pfetch-install-update.sh"
  seed_if_exists copy "$TARGET_HOME/pfetch-install-update.lib.sh"
  seed_if_exists copy "$TARGET_HOME/.config/pfetch/pfetchrc"

  for pkg in ripgrep trash-cli gh; do
    if df_pkg_is_installed "$pkg"; then
      seed_if_new package-new "$pkg"
    fi
  done

  if [[ -d "$TARGET_HOME/.install-scripts" ]]; then
    seed_if_exists copy "$TARGET_HOME/.install-scripts/neovim-install-update.sh"
    seed_if_exists copy "$TARGET_HOME/.install-scripts/fastfetch-install-update.sh"
    seed_if_exists copy "$TARGET_HOME/.install-scripts/lib/github-release.sh"
    seed_if_exists copy "$TARGET_HOME/.install-scripts/lib/journal.sh"
  fi

  if [[ "$APPLY" -eq 1 ]]; then
    log "journal: $(df_journal_file)"
    log "human log: $(df_install_log_file)"
  fi
}

uninstall_configs() {
  local dest
  local -a dests=()

  while IFS= read -r dest; do
    [[ -n "$dest" ]] && dests+=("$dest")
  done < <(collect_home_dests)

  if ((${#dests[@]} == 0)); then
    log "no managed home paths found (check ~/.local/share/dotfiles/managed-paths)"
    return 0
  fi

  for dest in "${dests[@]}"; do
    if is_lazyvim_owned "$dest"; then
      log "leave LazyVim: $dest"
      continue
    fi
    restore_dest "$dest"
  done

  df_strip_ai_rules
}

# True when a symlink still points at the old unhidden clone path
# ~/dotfiles (before hide-clone renamed it to ~/.dotfiles).
# Do not match ~/.dotfiles: those are live workstation install links.
symlink_points_at_old_clone() {
  local dest="$1"
  local tgt parent

  [[ -L "$dest" ]] || return 1
  tgt="$(readlink "$dest")"
  [[ -n "$tgt" ]] || return 1
  case "$tgt" in
    /*) ;;
    *)
      parent="$(cd "$(dirname "$dest")" && pwd)"
      tgt="${parent}/${tgt}"
      ;;
  esac
  case "$tgt" in
    "$TARGET_HOME/dotfiles" | "$TARGET_HOME/dotfiles"/*) return 0 ;;
  esac
  return 1
}

# Copy-install writes real files. A remaining clone symlink is leftover.
is_copy_install_home() {
  [[ -f "$TARGET_HOME/.bashrc" && ! -L "$TARGET_HOME/.bashrc" ]]
}

remove_stale_clone_symlinks_in() {
  local dir="$1"
  local dest

  [[ -d "$dir" ]] || return 0
  shopt -s nullglob
  for dest in "$dir"/.[!.]* "$dir"/*; do
    if [[ "$dest" == "$TARGET_HOME/.dotfiles" || "$dest" == "$TARGET_HOME/dotfiles" ]]; then
      continue
    fi
    if symlink_points_at_old_clone "$dest"; then
      log "remove stale clone symlink: $dest -> $(readlink "$dest")"
      remove_home_path "$dest"
    fi
  done
  shopt -u nullglob
}

# Leftovers from pre-journal / pre-hide-clone installs. Not in managed-paths.
# Never deletes live workstation links into ~/.dotfiles.
remove_legacy_home_artifacts() {
  local f dest
  local -a stamped=()

  remove_stale_clone_symlinks_in "$TARGET_HOME"
  remove_stale_clone_symlinks_in "$TARGET_HOME/.config"
  remove_stale_clone_symlinks_in "$TARGET_HOME/.config/tmux"
  remove_stale_clone_symlinks_in "$TARGET_HOME/.config/dotfiles"

  dest="$TARGET_HOME/old.fzf.bash"
  if [[ -e "$dest" || -L "$dest" ]]; then
    log "remove leftover: $dest"
    remove_home_path "$dest"
  fi

  shopt -s nullglob
  stamped=("$TARGET_HOME"/*.pre-dotfiles-* "$TARGET_HOME"/.[!.]*.pre-dotfiles-*)
  shopt -u nullglob
  for f in "${stamped[@]}"; do
    [[ -e "$f" || -L "$f" ]] || continue
    log "remove timestamped leftover backup: $f"
    remove_home_path "$f"
  done

  # Light hosts do not use gitconfig/fzf/tpm. If bashrc is a real file,
  # drop those workstation leftovers. Do not do this on a symlink install.
  if is_copy_install_home; then
    dest="$TARGET_HOME/.gitconfig"
    if [[ -L "$dest" ]]; then
      log "remove leftover gitconfig symlink (copy-install does not use it): $dest -> $(readlink "$dest")"
      remove_home_path "$dest"
    fi
    dest="$TARGET_HOME/.fzf"
    if [[ -d "$dest" && ( -x "$dest/install" || -d "$dest/.git" ) ]]; then
      log "remove leftover fzf clone: $dest"
      remove_home_path "$dest"
    fi
    dest="$TARGET_HOME/.fzf.bash"
    if [[ -e "$dest" || -L "$dest" ]]; then
      log "remove leftover fzf bash hook: $dest"
      remove_home_path "$dest"
    fi
    dest="$TARGET_HOME/.tmux/plugins/tpm"
    if [[ -e "$dest" || -L "$dest" ]]; then
      log "remove leftover tpm: $dest"
      remove_home_path "$dest"
    fi
  fi
}

journal_kinds() {
  df_journal_paths_for_kind "$1"
}

uninstall_gsettings_keys() {
  local binding_id

  while IFS= read -r binding_id; do
    [[ -n "$binding_id" ]] || continue
    log "remove GNOME keybinding: $binding_id"
    if [[ "$APPLY" -eq 0 ]]; then
      continue
    fi
    df_gnome_unbind_custom_keybinding "$binding_id"
  done < <(journal_kinds gsettings-key)
}

uninstall_tools() {
  local p pkg file

  df_remove_legacy_pfetch

  file="$(df_journal_file)"
  if [[ ! -f "$file" ]]; then
    log "no journal; skipping packages/binaries/clones"
    return 0
  fi

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    log "remove git clone: $p"
    remove_home_path "$p"
  done < <(journal_kinds git-clone)

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if is_home_path "$p"; then
      continue
    fi
    log "remove binary: $p"
    remove_system_path "$p"
  done < <(journal_kinds binary)

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    log "remove symlink: $p"
    remove_system_path "$p"
  done < <(journal_kinds symlink)

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    log "remove opt tree: $p"
    remove_system_path "$p"
  done < <(journal_kinds opt-tree)

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    log "remove system drop-in: $p"
    remove_system_path "$p"
  done < <(journal_kinds system-dropin)

  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    if ! df_pkg_is_installed "$pkg"; then
      log "package already gone: $pkg"
      continue
    fi
    log "remove package we installed: $pkg"
    if command -v apt-get >/dev/null 2>&1; then
      run df_run_privileged apt-get remove -y "$pkg"
    elif command -v dnf >/dev/null 2>&1; then
      run df_run_privileged dnf remove -y "$pkg"
    else
      log "WARN: cannot remove package $pkg (no apt/dnf)"
    fi
  done < <(journal_kinds package-new)

  uninstall_gsettings_keys
}

journal_audit_unhandled() {
  local file kind p
  local -A seen=()

  file="$(df_journal_file)"
  [[ -f "$file" ]] || return 0
  while IFS=$'\t' read -r _ts kind p _extra; do
    [[ -n "$kind" ]] || continue
    if df_journal_is_skip_kind "$kind"; then
      continue
    fi
    case "$kind" in
      link | copy | binary)
        is_home_path "$p" && continue
        ;;
    esac
    if [[ -z "${seen[$kind]:-}" ]]; then
      seen["$kind"]=1
    fi
  done <"$file"

  for kind in "${!seen[@]}"; do
    case "$kind" in
      backup | link | copy | skip | patch | package-new | binary | symlink | opt-tree | git-clone | hide-clone | locale | gsettings-key | system-dropin) ;;
      *)
        log "WARN: journal kind has no uninstall handler: $kind"
        ;;
    esac
  done
}

clear_managed_paths() {
  local file bak p
  local -a keep=()
  file="$(df_managed_paths_file)"
  [[ -f "$file" ]] || return 0

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if is_lazyvim_owned "$p"; then
      keep+=("$p")
    fi
  done <"$file"

  bak="${file}.uninstalled-$(date -u +%Y%m%dT%H%M%SZ)"
  log "archive managed-paths -> $bak"
  if [[ "$APPLY" -eq 0 ]]; then
    return 0
  fi
  mv "$file" "$bak"
  if ((${#keep[@]} > 0)); then
    printf '%s\n' "${keep[@]}" >"$file"
    log "kept LazyVim paths in managed-paths"
  fi
}

purge_dotfiles_trace() {
  local local_clone state_dir standalone_cli dest

  local_clone="$(clone_dir)"
  if [[ -n "$local_clone" && -d "$local_clone" ]]; then
    log "purge clone: $local_clone"
    remove_home_path "$local_clone"
  fi

  standalone_cli="$TARGET_HOME/.install-scripts/dotfiles-cli"
  if [[ -e "$standalone_cli" || -L "$standalone_cli" ]]; then
    log "purge standalone CLI copy: $standalone_cli"
    remove_home_path "$standalone_cli"
  fi

  dest="$TARGET_HOME/.local/bin/dotfiles"
  if [[ -e "$dest" || -L "$dest" ]]; then
    log "purge dotfiles command: $dest"
    remove_home_path "$dest"
  fi

  state_dir="$(df_journal_dir)"
  if [[ -d "$state_dir" ]]; then
    log "purge dotfiles state: $state_dir"
    remove_home_path "$state_dir"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

prompt_uninstall_mode

case "$MODE" in
  dry-run) APPLY=0 ;;
  uninstall) APPLY=1 ;;
  purge) APPLY=1; PURGE=1 ;;
  *)
    echo "Invalid DOTFILES_UNINSTALL_MODE: $MODE (use dry-run, uninstall, or purge)" >&2
    exit 1
    ;;
esac

if [[ "$APPLY" -eq 1 ]]; then
  export DRY_RUN=0
  log "mode: $MODE"
else
  export DRY_RUN=1
  log "mode: dry-run"
fi

auto_seed_if_needed

if [[ "$APPLY" -eq 1 ]] && needs_sudo_for_tools; then
  df_ensure_sudo
fi

uninstall_configs
remove_legacy_home_artifacts
uninstall_tools

if [[ "$PURGE" -eq 1 ]]; then
  purge_dotfiles_trace
elif [[ "$APPLY" -eq 1 ]]; then
  clear_managed_paths
fi

if [[ "$APPLY" -eq 0 ]]; then
  journal_audit_unhandled
  log "dry-run complete. run again and choose uninstall or purge to apply"
else
  if [[ "$PURGE" -eq 1 ]]; then
    log "purge complete. dotfiles clone and state removed"
  else
    log "uninstall complete. journal kept at $(df_journal_file)"
  fi
  log "open a new shell (or reconnect SSH) so the restored bashrc loads"
fi
