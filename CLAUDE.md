# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

`mise` is the only task runner. All tasks are defined in `mise.toml`.

```bash
mise run test          # run shell regression tests
mise run syntax        # bash -n / zsh -n syntax checks
mise run lint          # shellcheck + shfmt -d formatting checks
mise run smoke-apply   # render home/ into a tmpdir via chezmoi
mise run ci            # full local CI suite (test + smoke-apply)
bash scripts/benchmark-shell.sh 10  # measure shell startup time
```

Single test file: run it directly — `bash tests/test_shell_env.sh`.

Local lifecycle:
- `./install.sh` — install or migrate (prompts before touching existing config)
- `./install.sh --yes` — non-interactive install
- `./rollback.sh` — restore most recent backup
- `./uninstall.sh` — remove managed files

## Architecture

This is a **chezmoi-driven dotfiles project**. `home/` is the chezmoi source directory; chezmoi renders it into `$HOME`.

### Install / lifecycle flow

Root wrappers (`install.sh`, `rollback.sh`, `sync.sh`, `uninstall.sh`) are raw-friendly bootstrap shims. Each wrapper resolves to a real implementation in this order: local checkout → `$ZSH_SETUP_HOME` (installed copy) → download from GitHub archive.

The real implementations live in `scripts/`:
- `scripts/install-managed.sh` — detects existing shell state, backs it up, then calls `scripts/bootstrap.sh`
- `scripts/bootstrap.sh` — installs chezmoi and mise, then runs `chezmoi apply`
- `scripts/migrate.sh` — compatibility wrapper that delegates to the unified install flow
- `scripts/sync.sh` — pulls latest and re-applies via chezmoi
- `scripts/rollback.sh` / `scripts/uninstall.sh` — restore backup or remove managed files

**Shared library:** `scripts/lib/common.sh` is sourced by every script. It provides logging (`log`/`warn`/`die`), XDG path helpers (`config_home`, `data_home`, `state_home`), managed-state detection (`is_managed_install`, `has_existing_shell_state`), backup helpers, and tool installers (`install_chezmoi`, `install_mise`).

### Shell startup

`home/dot_zshrc` is minimal: it exports a few env vars and sources every `*.zsh` file from `~/.config/zsh/zshrc.d/` in order. Modules follow a numeric prefix scheme:

| File | Purpose |
|------|---------|
| `00-options.zsh` | zsh setopt flags |
| `10-completion.zsh` | completion initialization |
| `20-integrations.zsh` | tool activations (mise, etc.) |
| `25-updates.zsh` | background update check |
| `30-kube.zsh` | kubectl prompt helpers |
| `40-aliases.zsh` | shell aliases |
| `50-local.zsh` | sources `~/.config/zsh/local/*.zsh` |
| `60-prompt.zsh` | starship prompt init |

User-private overrides (secrets, machine-local config) go in `~/.config/zsh/local/*.zsh` — never in `home/`.

### State layout

| Path | Purpose |
|------|---------|
| `~/.local/share/zsh-setup/` | chezmoi source + installed copy |
| `~/.local/state/zsh-setup/backups/` | timestamped pre-migration backups |
| `~/.local/state/zsh-setup/updates/` | update check cache |

### Testing

Tests live in `tests/test_*.sh` and use helpers from `tests/helpers/testlib.sh` (`assert_file_exists`, `assert_equals`, `assert_contains`, `run_test`, etc.). Prefer end-to-end behavior tests; mock external tools (`chezmoi`, `kubectl`) only when needed. CI runs on both macOS and Linux.

## Conventions

- Default to POSIX-friendly Bash unless a file's purpose requires Zsh.
- 2-space indentation in `home/` Zsh modules; 4-space elsewhere — don't mix within a file.
- Validate with `shellcheck` and `shfmt -d` before committing.
- New shell modules get a numeric prefix matching their load order.
- New helper scripts use verb-oriented names (e.g., `scripts/register-sync-task.sh`).
- Every behavior change in repo scripts needs a test added or updated first.
