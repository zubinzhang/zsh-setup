#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

remove_managed_files() {
	local cfg zsh_dir
	cfg="$(config_home)"
	zsh_dir="${cfg}/zsh"

	rm -f "${HOME}/.zshrc"
	rm -f "${cfg}/starship.toml"
	rm -rf "${cfg}/mise"
	rm -rf "${zsh_dir}/zshrc.d"

	if [[ -d "${zsh_dir}" && ! -d "${zsh_dir}/local" ]]; then
		rmdir "${zsh_dir}" >/dev/null 2>&1 || true
	fi

	rm -f \
		"${HOME}/.local/bin/zsh-setup-kube-prompt" \
		"${HOME}/.local/bin/zsh-setup-check-updates" \
		"${HOME}/.local/bin/zsh-setup-sync"
	rm -rf "$(update_state_dir)"
}

main() {
	if [[ -x "${SCRIPT_DIR}/unregister-sync-task.sh" ]]; then
		"${SCRIPT_DIR}/unregister-sync-task.sh" || warn "failed to remove sync task"
	fi

	remove_managed_files
	log "managed dotfiles removed; local overlay and backups were preserved"
}

main "$@"
