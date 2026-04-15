# zsh-setup

Fast, reproducible shell environment built around `chezmoi`, `mise`, `Starship`, and plain `zsh`.

## What this repo manages

- `home/`: `chezmoi` source for `~/.zshrc`, `~/.config/zsh`, `~/.config/starship.toml`, and stable `~/.local/bin` helpers.
- `scripts/`: bootstrap, migrate, sync, doctor, completion refresh, and CI smoke checks.
- root wrappers: `install.sh`, `rollback.sh`, `uninstall.sh`, and `sync.sh` for direct `raw.githubusercontent.com` entrypoints.
- `tests/`: shell regression tests for migration, sync safety, and K8s prompt classification.
- `.github/workflows/ci.yml`: macOS + Linux validation for syntax, tests, and `chezmoi` apply idempotency.

Managed zsh runtime enhancements include `zsh-autosuggestions`, `zsh-syntax-highlighting`, and `vivid`-generated `LS_COLORS` when those tools are available. `scripts/install-shell-deps.sh` prefers Homebrew or the system package manager for shell tooling, then falls back to release binaries or shallow clones under `~/.local/share` where needed.

## Install And Migrate

Fresh restore and migration now use the same entrypoint:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/install.sh | bash
```

The raw installer prefers a shallow `git clone` into `~/.local/share/zsh-setup/` when `git` is available, then runs the managed install flow. If `git` is unavailable or you explicitly provide `ZSH_SETUP_ARCHIVE_URL`, it falls back to the source archive path. If it detects an existing `~/.zshrc`, `~/.config/starship.toml`, `~/.config/mise/`, `~/.config/zsh/`, or `~/.config/shell/secrets.zsh`, it prints the backup target and asks before migrating. Existing managed installs skip that prompt.

Fresh bootstrap now installs `mise`, `starship`, `eza`, `vivid`, managed zsh plugins, and the managed `JetBrainsMono Nerd Font Mono` family for prompt glyphs. On first install it also seeds `~/.config/mise/config.toml` from the repository root `mise.toml` so the managed toolset is available from `~` immediately, while preserving later user edits to that file. On macOS and Linux, the installer also repairs common completion-directory permission issues so first-run `compinit` does not stop at an interactive security prompt. If you want macOS iTerm2 font wiring during install, run `install.sh` with `ZSH_SETUP_CONFIGURE_ITERM2_FONT=1`.

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

This removes the managed `~/.zshrc`, `~/.config/zsh/zshrc.d`, `~/.config/mise`, `~/.config/starship.toml`, update-check wrappers, sync wrappers, any legacy background sync task, the managed checkout under `~/.local/share/zsh-setup`, zsh cache/state directories, fallback plugin clones under `~/.local/share`, and the repo-managed JetBrainsMono Nerd Font Mono files. It preserves `~/.config/zsh/local/` so local secrets and overrides survive uninstall. `rollback.sh` still preserves backups internally so restore continues to work.

## Manual Sync

If you want to apply the latest upstream dotfiles on demand instead of waiting for the next shell-start prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/zubinzhang/zsh-setup/main/sync.sh | bash
```

`sync.sh` is a convergence command: after fast-forwarding the managed repo and applying dotfiles, it re-runs shell dependency install, managed font install, permission repair, and `doctor`. If one of those required steps fails, `sync.sh` exits non-zero.

## Day-2 commands

```bash
mise run test
mise run syntax
mise run lint
bash scripts/benchmark-shell.sh 10
```

Update detection runs during shell startup through `~/.local/bin/zsh-setup-check-updates`: if the local `chezmoi` source is behind its upstream, the next shell startup asks whether to upgrade now. Nothing is auto-applied without confirmation, and dirty source trees still block the upgrade path.

Bootstrap installs `chezmoi` itself. On first install, bootstrap copies the repository root `mise.toml` to `~/.config/mise/config.toml` when that file does not already exist, so `bun`, `go`, `node`, `python`, `yarn`, `helm`, `kubectl`, and `starship` resolve globally through `mise`. Later user edits are preserved, and the seeded toolset does not include `chezmoi` or `gh`. Runtime directory colors are generated with `vivid generate tokyonight-night`, and `eza` uses that environment when present.

## Local-only secrets and overrides

Put private files in `~/.config/zsh/local/*.zsh`. The repo never syncs that directory to GitHub. Install-time migration seeds it from the existing `~/.config/shell/secrets.zsh`.
