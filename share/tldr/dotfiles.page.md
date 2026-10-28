# dotfiles

> Dotfiles CLI for devbox, desktop, and server profiles

- Show profile, tools, and versions:

`dotfiles status`

- Pull repo and refresh configs (software if older than 30 days):

`dotfiles update`

- Full reinstall (discards repo changes, ignores 30-day skip):

`dotfiles update --force`

- Configs only:

`dotfiles update --config-only`

- Install LazyVim:

`dotfiles install lazyvim`

- Install LazyVim lite (no Mason/LSP):

`dotfiles install lazyvim-lite`

- Install fastfetch banner:

`dotfiles install fetch`

- Install AI agent rules and Claude/Codex settings (server; update does it on devbox/desktop):

`dotfiles install ai-config`

- Turn Claude/Codex sandboxes and approval prompts off (remembered across updates):

`dotfiles install ai-config --nosandbox`

- Put the sandboxes and approvals back:

`dotfiles install ai-config --sandbox`

- Let agents use sudo through a tmux popup or desktop dialog (opt-in per machine):

`dotfiles install ai-sudo`

- Remove agent sudo setup:

`dotfiles uninstall ai-sudo`

- Sync LazyVim plugins to lazy-lock.json (after git pull):

`dotfiles sync lazyvim`

- Sync LazyVim lite plugins:

`dotfiles sync lazyvim-lite`

- Remove LazyVim data; switch nvim to plain config:

`dotfiles uninstall lazyvim`

- Remove one managed tool:

`dotfiles uninstall lazygit`

- List uninstallable tools:

`dotfiles uninstall --list`

- Undo full dotfiles install (interactive):

`dotfiles uninstall`

- First-time install (from clone):

`./devbox.sh`

`./desktop.sh`

`./server.sh`

- Upgrade one tool directly:

`./scripts/<tool>-install-update.sh`

- Fuzzy tldr page picker:

`ftldr`

(or bare `tldr`)
