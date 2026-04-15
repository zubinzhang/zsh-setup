#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

STAMP="${1:-}"

resolve_backup_dir() {
	local stamp="$1"
	if [[ -z "${stamp}" ]]; then
		stamp="$(latest_backup_stamp || true)"
	fi
	[[ -n "${stamp}" ]] || die "no backups found under $(backup_root)"
	printf '%s\n' "$(backup_root)/${stamp}"
}

restore_backup() {
	local dir cfg
	dir="$(resolve_backup_dir "${STAMP}")"
	cfg="$(config_home)"
	[[ -d "${dir}" ]] || die "backup does not exist: ${dir}"

	rm -rf "${cfg}/mise" "${cfg}/zsh"
	copy_if_exists "${dir}/dot_zshrc" "${HOME}/.zshrc"
	copy_if_exists "${dir}/dot_config/starship.toml" "${cfg}/starship.toml"
	copy_if_exists "${dir}/dot_config/shell/secrets.zsh" "${cfg}/shell/secrets.zsh"
	copy_dir_if_exists "${dir}/dot_config/mise" "${cfg}/mise"
	copy_dir_if_exists "${dir}/dot_config/zsh" "${cfg}/zsh"
}

main() {
	if [[ -x "${SCRIPT_DIR}/uninstall.sh" ]]; then
		ZSH_SETUP_PRESERVE_BACKUPS=1 "${SCRIPT_DIR}/uninstall.sh"
	fi
	restore_backup
}

main "$@"
