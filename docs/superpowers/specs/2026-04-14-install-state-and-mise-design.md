# Install State And Mise Runtime Design

## Goal

Fix the repository's install flow so a local checkout installs a valid managed shell environment, user-level `mise` config does not try to install `chezmoi` or `gh`, and verification catches a partially applied shell setup.

## Problem Summary

The current local bootstrap path calls `chezmoi init --apply --source=<repo>/home`. `chezmoi init` is the wrong primitive for an already-materialized source tree: it mutates source state and leaves follow-up commands like update checks depending on an unstable `chezmoi source-path`. In practice this allows install logs to look successful while `~/.zshrc` and `~/.config/zsh` are not actually under the managed layout.

Separately, the managed `~/.config/mise/config.toml` includes `chezmoi` and `gh`. That causes duplicate `chezmoi` installation attempts and a failing `gh` plugin lookup during bootstrap, even though `chezmoi` is already handled by bootstrap and `gh` is not intended to be managed here.

## Design

### Install State

Treat `~/.local/share/zsh-setup/home` as the canonical rendered source for the installed repo checkout. Local bootstrap should apply that directory with `chezmoi apply --source=...` instead of `chezmoi init --apply --source=...`. Remote bootstrap may continue using `chezmoi init --apply <repo>` because it is initializing from a repo URL, not from a pre-existing source tree.

Update helpers that currently depend on `chezmoi source-path` to prefer the installed repo checkout directly. `sync` and startup update checks should resolve the managed source from `ZSH_SETUP_HOME` or the default install home and operate on `home/` there. This removes dependence on a global chezmoi source directory for the normal installed-repo path.

### Managed Runtime

Keep user runtime management in the managed `~/.config/mise/config.toml`, but limit it to `starship`, `kubectl`, and `helm`. `chezmoi` remains a bootstrap dependency only, and `gh` is not managed by this repo.

### Verification

Strengthen `doctor` so it verifies managed ownership, not just file existence. It should confirm that `~/.zshrc` contains the managed marker and that managed shell module directories exist. This makes failed handoff from old shell configs visible immediately.

## Testing

Add regression coverage for:

- local bootstrap applying from `home/` without mutating chezmoi source state assumptions
- `sync` and update checks resolving the installed repo `home/` path directly
- managed `mise` config excluding `chezmoi` and `gh`
- `doctor` failing when the managed marker is missing
