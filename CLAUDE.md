# dotfiles

Personal dotfiles and installers for three profiles: `devbox.sh` (Debian/Ubuntu/Fedora,
symlinks), `desktop.sh` (same, desktop defaults) and `server.sh` (copies, no symlinks).
`dotfiles` (`scripts/dotfiles`) wraps them: `update`, `status`, `install`, `uninstall`.
This machine may be any profile; check `~/.local/share/dotfiles/profile`.

## Layout

- `home/` configs that get linked or copied into `$HOME`
- `scripts/` per-tool `*-install-update.sh`, `ai-*.sh`, and `scripts/lib/` shared helpers
- `lazyvim/`, `lazyvim-lite/`, `server/` profile-specific installers
- `.cursor/rules/*.mdc` are the masters for repo rules; `.claude/rules/*.md` are generated
  from them with `./scripts/ai-repo-rules-sync.sh` (never edit by hand)

## Working here

- Conventions load from `.claude/rules/` when you touch matching files: no install or
  uninstall without being asked, journal every side effect, bash `local` rules, script
  header + `--help`, how AI config is managed, tldr page.
- Do not run installers or `dotfiles update` to test a change. Use `--dry-run`, `--help`,
  or a throwaway `HOME`.
- Check shell changes with `bash -n` (CI runs shellcheck at error severity).
