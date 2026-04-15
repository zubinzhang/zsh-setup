#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

failures=0

check_command() {
	local cmd="$1"
	if command_exists "${cmd}"; then
		log "ok: found ${cmd}"
	else
		warn "missing command: ${cmd}"
		failures=$((failures + 1))
	fi
}

check_path() {
	local path="$1"
	if [[ -e "${path}" ]]; then
		log "ok: found ${path}"
	else
		warn "missing path: ${path}"
		failures=$((failures + 1))
	fi
}

check_managed_zshrc() {
	local marker
	marker="$(managed_zshrc_marker)"
	if has_managed_zshrc_marker; then
		log "ok: found managed zshrc marker"
	else
		warn "missing managed zshrc marker (${marker}) in ${HOME}/.zshrc"
		failures=$((failures + 1))
	fi
}

main() {
	check_command zsh
	check_command git
	check_command chezmoi
	check_command mise
	check_command starship
	check_command eza

	check_managed_zshrc
	check_path "$(font_home)"
	check_path "$(config_home)/starship.toml"
	check_path "$(config_home)/zsh/zshrc.d"
	check_path "$(config_home)/zsh/zshrc.d/10-core.zsh"
	check_path "$(config_home)/zsh/local"
	check_path "${HOME}/.local/bin/zsh-setup-check-updates"
	check_path "${HOME}/.local/bin/zsh-setup-sync"
	check_path "$(update_state_dir)"
	check_path "$(backup_root)"

	if [[ "${failures}" -ne 0 ]]; then
		die "doctor found ${failures} issue(s)"
	fi
}

main "$@"
