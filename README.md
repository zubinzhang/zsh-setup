# zsh-setup

Fast, reproducible shell environment built around `chezmoi`, `mise`, `Starship`, and plain `zsh`.

## What this repo manages

- `home/`: `chezmoi` source for `~/.zshrc`, `~/.config/zsh`, `~/.config/mise`, `~/.config/starship.toml`, and stable `~/.local/bin` helpers.
- `scripts/`: bootstrap, migrate, sync, doctor, completion refresh, and CI smoke checks.
- `tests/`: shell regression tests for migration, sync safety, and K8s prompt classification.
- `.github/workflows/ci.yml`: macOS + Linux validation for syntax, tests, and `chezmoi` apply idempotency.

## Install

Fresh machine restore works either from a local clone or directly from `raw.githubusercontent.com`.

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/install.sh | bash
```

The raw installer downloads the repo into `~/.local/share/zsh-setup/` and then runs the normal bootstrap flow. If you prefer a full clone first:

```bash
git clone https://github.com/zubinzhang/zsh-setup.git ~/.local/share/zsh-setup
~/.local/share/zsh-setup/install.sh
```

`install.sh` installs `chezmoi` and `mise` if needed, applies `home/`, refreshes completions, removes any legacy background sync task, and seeds a startup update check cache.

## Migrate

For an existing machine with hand-managed dotfiles:

```bash
~/.local/share/zsh-setup/scripts/migrate.sh
```

This creates timestamped backups under `~/.local/state/zsh-setup/backups/`, including the current `~/.zshrc`, `~/.config/starship.toml`, `~/.config/mise/`, `~/.config/zsh/`, and `~/.config/shell/secrets.zsh`. It also copies `~/.config/shell/secrets.zsh` into `~/.config/zsh/local/secrets.zsh`, then applies the managed dotfiles. Re-running it is safe.

## Rollback

Rollback removes the managed shell entrypoints and restores a backup created by `scripts/migrate.sh`.

```bash
ls ~/.local/state/zsh-setup/backups
~/.local/share/zsh-setup/scripts/rollback.sh
~/.local/share/zsh-setup/scripts/rollback.sh 20260415T000000Z
```

Without an argument, rollback restores the latest backup. With a timestamp, it restores that exact snapshot, including the previous `mise` and `zsh` config directories when they were backed up.

## Uninstall

To stop managing the shell with this repo but keep backups and local overlays:

```bash
~/.local/share/zsh-setup/scripts/uninstall.sh
```

This removes the managed `~/.zshrc`, `~/.config/zsh/zshrc.d`, `~/.config/mise`, `~/.config/starship.toml`, update-check wrappers, sync wrappers, and any legacy background sync task. It keeps `~/.config/zsh/local/` and `~/.local/state/zsh-setup/backups/`. If you also want to remove the checkout itself:

```bash
rm -rf ~/.local/share/zsh-setup
```

## Day-2 commands

```bash
mise run test
mise run syntax
mise run lint
bash scripts/benchmark-shell.sh 10
```

Manual apply still uses `scripts/sync.sh` or `~/.local/bin/zsh-setup-sync`. Update detection now runs during shell startup through `~/.local/bin/zsh-setup-check-updates`: if the local `chezmoi` source is behind its upstream, the next shell startup asks whether to upgrade now. Nothing is auto-applied without confirmation, and dirty source trees still block the upgrade path.

## Local-only secrets and overrides

Put private files in `~/.config/zsh/local/*.zsh`. The repo never syncs that directory to GitHub. `scripts/migrate.sh` seeds it from the existing `~/.config/shell/secrets.zsh`.
