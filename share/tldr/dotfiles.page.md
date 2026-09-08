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
