#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

run_required_script() {
	local label="$1"
	local script="$2"
	[[ -x "${script}" ]] || die "${label} script is not executable: ${script}"
	"${script}" || die "${label} failed"
}

main() {
	local source_dir repo_dir dirty upstream
	command_exists chezmoi || die "chezmoi is required"
	command_exists git || die "git is required"

	source_dir="$(managed_source_dir)"
	[[ -d "${source_dir}" ]] || die "managed source path does not exist: ${source_dir}"

	repo_dir="$(managed_repo_dir || true)"
	if [[ -n "${repo_dir}" ]]; then
		dirty="$(git -C "${repo_dir}" status --porcelain --untracked-files=normal)"
		if [[ -n "${dirty}" ]]; then
			die "managed repo has local changes; refusing to sync"
		fi

		upstream="$(git -C "${repo_dir}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
		if [[ -n "${upstream}" ]]; then
			git -C "${repo_dir}" pull --ff-only --quiet >/dev/null 2>&1 || die "failed to fast-forward managed repo; resolve manually"
		fi
	fi

	chezmoi apply --force --source="${source_dir}"
	if [[ -x "${SCRIPT_DIR}/prune-zsh-modules.sh" ]]; then
		"${SCRIPT_DIR}/prune-zsh-modules.sh"
	fi

	run_required_script "shell dependency installation" "${ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT:-${SCRIPT_DIR}/install-shell-deps.sh}"
	run_required_script "Nerd Font installation" "${ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT:-${SCRIPT_DIR}/install-nerd-font.sh}"
	run_required_script "zsh permission repair" "${ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT:-${SCRIPT_DIR}/fix-zsh-permissions.sh}"
	run_required_script "iTerm2 font setup" "${ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT:-${SCRIPT_DIR}/configure-iterm2-font.sh}"
	run_required_script "doctor" "${ZSH_SETUP_DOCTOR_SCRIPT:-${SCRIPT_DIR}/doctor.sh}"
}

main "$@"
