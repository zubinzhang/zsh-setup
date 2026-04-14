# zsh-setup

Fast, reproducible shell environment built around `chezmoi`, `mise`, `Starship`, and plain `zsh`.

## What this repo manages

- `home/`: `chezmoi` source for `~/.zshrc`, `~/.config/zsh`, `~/.config/mise`, `~/.config/starship.toml`, and stable `~/.local/bin` helpers.
- `scripts/`: bootstrap, migrate, sync, doctor, completion refresh, and CI smoke checks.
- root wrappers: `install.sh`, `rollback.sh`, `uninstall.sh`, and `sync.sh` for direct `raw.githubusercontent.com` entrypoints.
- `tests/`: shell regression tests for migration, sync safety, and K8s prompt classification.
- `.github/workflows/ci.yml`: macOS + Linux validation for syntax, tests, and `chezmoi` apply idempotency.

## Install And Migrate

Fresh restore and migration now use the same entrypoint:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/install.sh | bash
```

The raw installer prefers a shallow `git clone` into `~/.local/share/zsh-setup/` when `git` is available, then runs the managed install flow. If `git` is unavailable or you explicitly provide `ZSH_SETUP_ARCHIVE_URL`, it falls back to the source archive path. If it detects an existing `~/.zshrc`, `~/.config/starship.toml`, `~/.config/mise/`, `~/.config/zsh/`, or `~/.config/shell/secrets.zsh`, it prints the backup target and asks before migrating. Existing managed installs skip that prompt.

For non-interactive migration, pass `--yes`:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/install.sh | bash -s -- --yes
```

Backups live under `~/.local/state/zsh-setup/backups/`. The compatibility alias `scripts/migrate.sh` still exists inside the local checkout, but `install.sh` is the primary interface.

## Rollback

Rollback removes the managed shell entrypoints and restores a backup created during install-time migration.

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/rollback.sh | bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/rollback.sh | bash -s -- 20260415T000000Z
```

Without an argument, rollback restores the latest backup. With a timestamp, it restores that exact snapshot, including the previous `mise` and `zsh` config directories when they were backed up.

## Uninstall

To stop managing the shell with this repo but keep backups and local overlays:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/uninstall.sh | bash
```

This removes the managed `~/.zshrc`, `~/.config/zsh/zshrc.d`, `~/.config/mise`, `~/.config/starship.toml`, update-check wrappers, sync wrappers, and any legacy background sync task. It keeps `~/.config/zsh/local/` and `~/.local/state/zsh-setup/backups/`. If you also want to remove the checkout itself, delete `~/.local/share/zsh-setup` after uninstall finishes.

## Manual Sync

If you want to apply the latest upstream dotfiles on demand instead of waiting for the next shell-start prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/sync.sh | bash
```

## Day-2 commands

```bash
mise run test
mise run syntax
mise run lint
bash scripts/benchmark-shell.sh 10
```

Update detection runs during shell startup through `~/.local/bin/zsh-setup-check-updates`: if the local `chezmoi` source is behind its upstream, the next shell startup asks whether to upgrade now. Nothing is auto-applied without confirmation, and dirty source trees still block the upgrade path.

Bootstrap installs `chezmoi` itself. User-level `mise` config in this repo manages `starship`, `kubectl`, and `helm`; it does not manage `chezmoi` or `gh`.

## Local-only secrets and overrides

Put private files in `~/.config/zsh/local/*.zsh`. The repo never syncs that directory to GitHub. Install-time migration seeds it from the existing `~/.config/shell/secrets.zsh`.
