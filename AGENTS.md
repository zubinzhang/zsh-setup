# Repository Guidelines

## Project Structure & Module Organization

This repo is a `chezmoi`-driven dotfiles project. Put managed home files in `home/`, operational scripts in `scripts/`, and regression tests in `tests/`. Shell startup is split under `home/dot_config/zsh/zshrc.d/`; keep modules small and single-purpose. Stable user helpers live in `home/dot_local/bin/`. CI definitions belong in `.github/workflows/`.

## Build, Test, and Development Commands

Use `mise` as the only task runner.

- `mise run test`: runs shell regression tests in `tests/`
- `mise run syntax`: checks Bash and Zsh syntax for repo scripts and rendered shell modules
- `mise run lint`: runs `shellcheck` and `shfmt -d`
- `mise run smoke-apply`: renders `home/` into a temporary `$HOME` with `chezmoi`
- `bash scripts/benchmark-shell.sh 10`: measures interactive shell startup

For local recovery flows, use `./install.sh` on a fresh machine and `./scripts/migrate.sh` on an existing machine.

## Coding Style & Naming Conventions

Write portable shell first. Default to POSIX-friendly Bash constructs unless Zsh is required by the file’s purpose. Use 2-space or 4-space indentation consistently within a file; do not mix styles. Name shell modules with ordered prefixes such as `30-kube.zsh` and keep helper scripts verb-oriented, for example `scripts/register-sync-task.sh`. Validate formatting with `shfmt` and correctness with `shellcheck`.

## Testing Guidelines

Every behavior change in repo scripts should add or update a shell test before implementation. Keep tests in `tests/test_*.sh` and use the lightweight helpers in `tests/helpers/testlib.sh`. Prefer end-to-end behavior checks over mocks, except when simulating external tools like `chezmoi` or `kubectl`. CI should stay green on both macOS and Linux.

## Commit & Pull Request Guidelines

Use short imperative commit messages. This repo started with `Initial commit`; keep follow-up commits equally direct, for example `feat: add chezmoi bootstrap flow` or `fix: stop sync on dirty source`. PRs should describe user-visible changes, migration impact, and verification commands run. Include screenshots only when prompt visuals materially change.

## Security & Configuration Tips

Do not commit secrets. Private overrides belong in `~/.config/zsh/local/*.zsh`, not in `home/`. Keep background sync fail-safe: local changes must block auto-apply instead of being overwritten.
