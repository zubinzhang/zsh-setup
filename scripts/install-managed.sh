#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ASSUME_YES=0
NO_APPLY=0
BOOTSTRAP_SCRIPT="${ZSH_SETUP_BOOTSTRAP_SCRIPT:-${SCRIPT_DIR}/bootstrap.sh}"

summarize_existing_shell_state() {
	local path
	while IFS= read -r path; do
		[[ -n "${path}" ]] || continue
		printf ' - %s\n' "${path}"
	done < <(legacy_shell_state_paths)
}

confirm_migration() {
	log "Existing shell config detected. zsh-setup will back up the current files before applying managed dotfiles."
	printf '%s\n' "Backup target: $(backup_root)/$(backup_stamp)"
	summarize_existing_shell_state
	confirm_with_tty '[zsh-setup] Continue and migrate this machine? [y/N] '
}

run_bootstrap() {
	[[ -x "${BOOTSTRAP_SCRIPT}" ]] || die "bootstrap script is not executable: ${BOOTSTRAP_SCRIPT}"
	"${BOOTSTRAP_SCRIPT}"
}

maybe_migrate_existing_state() {
	if is_managed_install; then
		return 0
	fi

	if ! has_existing_shell_state; then
		return 0
	fi

	if [[ "${ASSUME_YES}" -ne 1 ]] && ! confirm_migration; then
		log "installation cancelled; existing shell config was left untouched"
		exit 0
	fi

	backup_current_shell_state
	seed_local_overlay_from_legacy_secrets
	remove_managed_target_paths
	log "backup created at $(backup_root)/$(backup_stamp)"
}

main() {
	local arg
	for arg in "$@"; do
		case "${arg}" in
		--yes) ASSUME_YES=1 ;;
		--no-apply) NO_APPLY=1 ;;
		*)
			die "unsupported argument: ${arg}"
			;;
		esac
	done

	maybe_migrate_existing_state

	if [[ "${NO_APPLY}" -eq 0 ]]; then
		run_bootstrap
	fi
}

main "$@"
