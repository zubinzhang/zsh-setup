#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
    local zsh_path
    zsh_path="$(command -v zsh 2>/dev/null)" || return 0

    case "${SHELL:-}" in
        *zsh) return 0 ;;
    esac

    if ! command_exists chsh; then
        warn "chsh not found; to set zsh as your default shell, run: chsh -s ${zsh_path}"
        return 0
    fi

    if chsh -s "${zsh_path}"; then
        log "Default shell set to zsh"
    else
        warn "Could not set default shell automatically"
        warn "  Run: chsh -s ${zsh_path}"
    fi
}

main "$@"
