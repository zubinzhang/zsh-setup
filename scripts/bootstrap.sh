#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DEFAULT_REMOTE_REPO="${CHEZMOI_REPO:-https://github.com/zubinzhang/zsh-setup.git}"

ensure_runtime_dirs() {
	mkdir -p \
		"${HOME}/.local/bin" \
		"$(config_home)/zsh/local" \
		"$(cache_home)/zsh/completions" \
		"$(state_home)/zsh-setup" \
		"$(backup_root)"
}

apply_dotfiles() {
	# Clear chezmoi's entry state so files modified by other tools (e.g. mise)
	# since the last apply don't trigger an interactive conflict prompt.
	chezmoi state delete-bucket --bucket=entryState >/dev/null 2>&1 || true

	if [[ -d "${ZSH_SETUP_REPO_ROOT}/home" ]]; then
		log "Applying dotfiles from local source"
		chezmoi apply --force --source="${ZSH_SETUP_REPO_ROOT}/home"
	else
		log "Applying dotfiles from ${DEFAULT_REMOTE_REPO}"
		chezmoi init --apply --force "${DEFAULT_REMOTE_REPO}"
	fi
}

install_shell_deps() {
	local script="${ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT:-${SCRIPT_DIR}/install-shell-deps.sh}"
	if [[ -x "$script" ]]; then
		"$script" || warn "shell dependency installation failed; continuing"
	fi
}

install_nerd_font() {
	local script="${ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT:-${SCRIPT_DIR}/install-nerd-font.sh}"
	if [[ -x "${script}" ]]; then
		"${script}" || warn "Nerd Font installation failed; continuing"
	fi
}

fix_zsh_permissions() {
	local script="${ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT:-${SCRIPT_DIR}/fix-zsh-permissions.sh}"
	if [[ -x "${script}" ]]; then
		"${script}" || warn "zsh permission repair failed; continuing"
	fi
}

configure_iterm2_font() {
	local script="${ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT:-${SCRIPT_DIR}/configure-iterm2-font.sh}"
	if [[ -x "${script}" ]]; then
		"${script}" || warn "iTerm2 font setup failed; continuing"
	fi
}

prune_zsh_modules() {
	local script="${ZSH_SETUP_PRUNE_ZSH_MODULES_SCRIPT:-${SCRIPT_DIR}/prune-zsh-modules.sh}"
	if [[ -x "${script}" ]]; then
		"${script}" || warn "zsh module cleanup failed; continuing"
	fi
}

seed_global_mise_config() {
	local source_file target_file
	source_file="$(repo_mise_config_file)"
	target_file="$(mise_config_file)"

	[[ -f "${source_file}" ]] || return 0
	[[ -f "${target_file}" ]] && return 0

	mkdir -p "$(dirname "${target_file}")"
	cp "${source_file}" "${target_file}"
}

install_repo_tools() {
	if ! command_exists mise; then
		return 0
	fi

	if [[ ! -f "${ZSH_SETUP_REPO_ROOT}/mise.toml" ]]; then
		return 0
	fi

	(
		cd "${ZSH_SETUP_REPO_ROOT}"
		mise trust --yes >/dev/null 2>&1 || true
		mise install
	)
}

main() {
	ensure_local_bin_on_path
	ensure_runtime_dirs
	install_chezmoi
	apply_dotfiles
	install_mise
	seed_global_mise_config
	install_shell_deps
	install_nerd_font
	fix_zsh_permissions
	configure_iterm2_font
	install_repo_tools || warn "mise install failed; continuing with rendered dotfiles"
	prune_zsh_modules

	if [[ -x "${ZSH_SETUP_REPO_ROOT}/scripts/unregister-sync-task.sh" ]]; then
		"${ZSH_SETUP_REPO_ROOT}/scripts/unregister-sync-task.sh" || warn "legacy sync task cleanup failed"
	fi
	if [[ -x "${ZSH_SETUP_REPO_ROOT}/scripts/completions.sh" ]]; then
		"${ZSH_SETUP_REPO_ROOT}/scripts/completions.sh" || warn "completion refresh failed"
	fi
	if [[ -x "${ZSH_SETUP_REPO_ROOT}/scripts/check-updates.sh" ]]; then
		"${ZSH_SETUP_REPO_ROOT}/scripts/check-updates.sh" --refresh >/dev/null 2>&1 || warn "startup update cache refresh failed"
	fi
	if [[ -x "${ZSH_SETUP_REPO_ROOT}/scripts/doctor.sh" ]]; then
		"${ZSH_SETUP_REPO_ROOT}/scripts/doctor.sh"
	fi
}

main "$@"
