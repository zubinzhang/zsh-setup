#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

remove_managed_files() {
	local cfg zsh_dir path
	cfg="$(config_home)"
	zsh_dir="${cfg}/zsh"

	rm -f "${HOME}/.zshrc"
	rm -f "${cfg}/starship.toml"
	rm -rf "${cfg}/mise"
	rm -rf "${zsh_dir}/zshrc.d"
	if [[ -d "${zsh_dir}" ]]; then
		for path in "${zsh_dir}"/*; do
			[[ -e "${path}" ]] || continue
			[[ "$(basename "${path}")" == "local" ]] && continue
			rm -rf "${path}"
		done
		if [[ ! -d "${zsh_dir}/local" ]]; then
			rmdir "${zsh_dir}" >/dev/null 2>&1 || true
		fi
	fi

	rm -f \
		"${HOME}/.local/bin/zsh-setup-kube-prompt" \
		"${HOME}/.local/bin/zsh-setup-check-updates" \
		"${HOME}/.local/bin/zsh-setup-sync"
	if [[ "${ZSH_SETUP_PRESERVE_BACKUPS:-0}" == "1" ]]; then
		rm -rf "$(update_state_dir)"
	else
		rm -rf "$(zsh_setup_state_root)"
	fi

	rm -rf \
		"$(zsh_setup_install_home)" \
		"$(cache_home)/zsh" \
		"$(data_home)/zsh-autosuggestions" \
		"$(data_home)/zsh-syntax-highlighting" \
		"$(data_home)/zsh-completions" \
		"$(data_home)/fzf"

	find "$(font_home)" -maxdepth 1 -type f \( -name 'MesloLGS NF*' -o -name 'MesloLGSNerdFont*' \) -delete 2>/dev/null || true
}

main() {
	if [[ -x "${SCRIPT_DIR}/unregister-sync-task.sh" ]]; then
		"${SCRIPT_DIR}/unregister-sync-task.sh" || warn "failed to remove sync task"
	fi

	remove_managed_files
	log "removed zsh-setup config, install home, state, cache, and related helper directories"
}

main "$@"
