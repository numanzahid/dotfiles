---
paths:
  - "scripts/ai-*.sh"
  - "scripts/lib/ai-*.sh"
  - "scripts/ai-agent-sudo/**"
  - "home/.config/dotfiles/ai-config/**"
  - "home/.config/dotfiles/ai-rules/**"
  - "home/.claude/**"
  - "home/.codex/**"
  - ".cursor/rules/**"
  - ".claude/rules/**"
---
<!-- Generated from .cursor/rules/ai-config-managed.mdc by scripts/ai-repo-rules-sync.sh. Edit the .mdc, then re-run. -->

# AI agent config

## Layout

| What | Source in repo | Target | How |
|---|---|---|---|
| Rules (git, trash-cli) | `home/.config/dotfiles/ai-rules/cursor/*.mdc` (masters) | `~/.cursor/rules` (symlinks; copies on server), `~/.codex/AGENTS.md` (merged), `~/.claude/rules/*.md` | `scripts/lib/ai-rules.sh` via `scripts/ai-rules-install.sh`; runs in `devbox.sh`, `desktop.sh` and `dotfiles update` |
| Claude settings | `home/.config/dotfiles/ai-config/claude/settings.base.json` | `~/.claude/settings.json` | `jq` recursive merge, repo keys win |
| Codex settings | `home/.config/dotfiles/ai-config/codex/config.base.toml` | `~/.codex/config.toml` | per-key line edit, re-parsed with `tomllib` before writing |
| Statusline, skills, agents, commands, prompts | `home/.claude/`, `home/.codex/` | `~/.claude/`, `~/.codex/` | symlink per item (copy on server), never the parent dir |
| Sudo askpass + unrestricted agents | `scripts/ai-agent-sudo/`, `ai-rules/optional/sudo.mdc` | `~/.local/bin`, Claude/Codex settings, `~/.cursor/rules/sudo.mdc` | `scripts/ai-agent-sudo-install.sh`, opt-in, not run by devbox/desktop/update; applies the base settings first |

CLI: `dotfiles install ai-config` (runs `ai-rules-install.sh`; meant for servers, since `server.sh`
does not run it), `dotfiles install ai-sudo`, `dotfiles uninstall ai-sudo`. There is no `ai-config`
step to run by hand on devbox/desktop: `dotfiles update` already does it.

All logic lives in `scripts/lib/ai-config.sh` (merge helpers, agent sudo) and `scripts/lib/ai-rules.sh` (rules).

## Principles

- Claude and Codex rewrite their config at runtime (trust entries, UI counters, approvals).
  Never symlink or template the whole file; merge only the keys dotfiles owns.
- Machine state stays out of the repo: `auth.json`, `.credentials.json`, history, sessions,
  sqlite, `[projects.*]` trust, `[tui.model_availability_nux]`.
- To roll out a setting, add the key to the base file. Single-line TOML values only.
- Sandbox, approvals and `SUDO_ASKPASS` belong to `ai-agent-sudo-install.sh`, not the base
  files. It is unrestricted by default; `--keep-approvals` keeps prompts. While approvals
  are disabled (journal `patch agent-sudo-no-approvals`) the base merge skips `approval_policy`.
- Servers get real copies, not symlinks (the clone may be deleted). Use `df_ai_place`, never `df_link_path`,
  for anything the AI scripts install; it copies when `df_ai_copy_mode` is true (server profile, or `--copy`).
- Keep merges idempotent and journaled (`patch`); every write is validated and a pre-merge
  copy goes to `~/.local/share/dotfiles/backups/ai-config/`.
- Keep Cursor, Codex and Claude rule content identical: the `.mdc` is the master.

## This repo's own rules

`.cursor/rules/*.mdc` are the masters for working on this repo. `.claude/rules/*.md` are
generated and committed; never edit them by hand.

```bash
./scripts/ai-repo-rules-sync.sh          # regenerate after editing a .mdc
./scripts/ai-repo-rules-sync.sh --check  # CI: fails when out of date
```

## Testing

Do not run the AI installers against the real home to test. Use `--dry-run`, or run them
with a throwaway `HOME`/`XDG_DATA_HOME` seeded with copies of `settings.json` and
`config.toml` and check idempotency (second run reports no change), `--uninstall`, and
that `config.toml` still parses.
