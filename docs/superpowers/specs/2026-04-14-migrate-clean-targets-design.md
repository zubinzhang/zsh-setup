# Migrate Clean Targets Design

## Goal

Prevent install-time migration from blocking on `chezmoi` overwrite prompts after the user confirms migration.

## Problem

Today `scripts/install-managed.sh` backs up legacy shell files and then immediately runs bootstrap. If any target file that will be managed by the repo still exists in the destination tree, `chezmoi apply` can stop in interactive conflict resolution. A common example is `~/.config/mise/config.toml`, which was backed up but left in place.

## Design

After migration is confirmed and backups are written, remove only the paths that this repo is about to manage directly:

- `~/.zshrc`
- `~/.config/starship.toml`
- `~/.config/mise`
- `~/.config/zsh/zshrc.d`
- `~/.local/bin/zsh-setup-check-updates`
- `~/.local/bin/zsh-setup-sync`
- `~/.local/bin/zsh-setup-kube-prompt`

Do not remove `~/.config/zsh/local`, backups, or other user-owned files outside the managed surface.

## Testing

Add a regression test where migration runs with pre-existing managed targets and a fake `chezmoi` executable that fails if the stale targets are still present when bootstrap executes. The test should fail before the fix and pass after it.
