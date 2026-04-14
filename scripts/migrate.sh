#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NO_APPLY=0

for arg in "$@"; do
	case "${arg}" in
	--no-apply) NO_APPLY=1 ;;
	*)
		die "unsupported argument: ${arg}"
		;;
	esac
done

backup_current_files() {
	local cfg
	cfg="$(config_home)"

	backup_file "${HOME}/.zshrc" "dot_zshrc"
	backup_file "${cfg}/starship.toml" "dot_config/starship.toml"
	backup_file "${cfg}/shell/secrets.zsh" "dot_config/shell/secrets.zsh"
	backup_dir "${cfg}/mise" "dot_config/mise"
	backup_dir "${cfg}/zsh" "dot_config/zsh"
}

seed_local_overlay() {
	local cfg overlay_dir secrets_src
	cfg="$(config_home)"
	overlay_dir="${cfg}/zsh/local"
	secrets_src="${cfg}/shell/secrets.zsh"

	mkdir -p "${overlay_dir}"
	if [[ -f "${secrets_src}" ]]; then
		cp "${secrets_src}" "${overlay_dir}/secrets.zsh"
	fi
}

main() {
	backup_current_files
	seed_local_overlay

	if [[ "${NO_APPLY}" -eq 0 ]]; then
		"${SCRIPT_DIR}/bootstrap.sh"
	fi
}

main "$@"
