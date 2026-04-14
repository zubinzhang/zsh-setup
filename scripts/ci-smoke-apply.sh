#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX}"' EXIT

export HOME="${SANDBOX}/home"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.cache"

mkdir -p "${HOME}"
chezmoi apply --source="${ROOT}/home"

test -f "${HOME}/.zshrc"
test -f "${XDG_CONFIG_HOME}/starship.toml"
test -x "${HOME}/.local/bin/zsh-setup-kube-prompt"
test -x "${HOME}/.local/bin/zsh-setup-check-updates"
test -x "${HOME}/.local/bin/zsh-setup-sync"

zsh -n "${HOME}/.zshrc"
zsh -n "${XDG_CONFIG_HOME}/zsh/zshrc.d/"*.zsh
bash -n "${HOME}/.local/bin/zsh-setup-kube-prompt" "${HOME}/.local/bin/zsh-setup-check-updates" "${HOME}/.local/bin/zsh-setup-sync"
