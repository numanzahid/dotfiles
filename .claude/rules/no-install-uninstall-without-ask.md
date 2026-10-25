<!-- Generated from .cursor/rules/no-install-uninstall-without-ask.mdc by scripts/ai-repo-rules-sync.sh. Edit the .mdc, then re-run. -->

# No install or uninstall without explicit user request

This machine may be devbox, desktop, or server. Never assume which profile to use.

## Do not run unless the user explicitly asks

- `./devbox.sh`, `./desktop.sh`, `./server.sh`, `./server/install.sh`
- `./uninstall.sh`, `dotfiles uninstall`, `dotfiles uninstall --purge`
- `dotfiles update` in any form (it runs `devbox.sh`/`desktop.sh`), including `--force` and `--config-only`
- `./install-*.sh` (including `./scripts/ai-rules-install.sh`), `./scripts/*-install-update.sh`, `./lazyvim/**/install*.sh`
- AI config installers: `./scripts/ai-config-install.sh`, `./scripts/ai-agent-sudo-install.sh`, and `dotfiles install ai-config` / `dotfiles install ai-sudo` / `dotfiles uninstall ai-sudo` (they rewrite Claude/Codex settings and sandbox/approval keys; a running agent session is affected)
- Uninstall variants: `--uninstall`, `dotfiles uninstall <software>`, lazyvim uninstall scripts
- Package steps inside installers: apt/dnf install, git clone into `$HOME`, `sudo` for tool binaries

## Allowed without asking

- Read files, `git status`, `git diff`, `git log`
- `dotfiles status` (read-only)
- `./scripts/ai-repo-rules-sync.sh` (writes only `.claude/rules/` in the repo, never `$HOME`)
- `--help` on any script (must print usage and exit before any side effect)
- Dry-run only when debugging an install/uninstall bug the user reported:
  - `DOTFILES_UNINSTALL_MODE=dry-run ./uninstall.sh`
  - `./devbox.sh --dry-run` (or equivalent flags)
  - `--dry-run` on the AI config installers
- Exercising installer logic against a throwaway home, never the real one:
  `env HOME=<scratch>/home XDG_DATA_HOME=<scratch>/home/.local/share PATH=<stubs>:/usr/bin:/bin ./script.sh`
  where `<stubs>` holds fake `sudo`/`apt`/`dnf`/`curl`/`git` that print BLOCKED and exit non-zero.
  Seed `<scratch>/home` with copies of the config files under test.

## When the user asks to install or uninstall

- Confirm profile if unclear (devbox vs desktop vs server)
- Prefer the profile they name; do not run `server.sh` on devbox or `devbox.sh` on server
- For uninstall, confirm uninstall vs purge if they did not say
- Do not chain install after uninstall unless they ask
- `ai-agent-sudo-install.sh` is opt-in per machine and unrestricted by default; say what it will change before running it

## Mistakes to avoid

- Do not "verify a fix" by running a real install or purge on the user's machine
- Do not run installers to "test" after editing install scripts; use dry-run, a throwaway home, or describe steps
- Investigation on a live host is read-only unless the user says run it
