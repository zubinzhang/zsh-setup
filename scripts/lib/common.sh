#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2034
ZSH_SETUP_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() {
	printf '[zsh-setup] %s\n' "$*"
}

warn() {
	printf '[zsh-setup] WARN: %s\n' "$*" >&2
}

die() {
	printf '[zsh-setup] ERROR: %s\n' "$*" >&2
	exit 1
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

ensure_local_bin_on_path() {
	export PATH="${HOME}/.local/bin:${PATH}"
}

config_home() {
	printf '%s\n' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

cache_home() {
	printf '%s\n' "${XDG_CACHE_HOME:-${HOME}/.cache}"
}

state_home() {
	printf '%s\n' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

zsh_setup_state_root() {
	printf '%s\n' "${ZSH_SETUP_STATE_HOME:-$(state_home)/zsh-setup}"
}

data_home() {
	printf '%s\n' "${XDG_DATA_HOME:-${HOME}/.local/share}"
}

detect_os() {
	if [[ -n "${ZSH_SETUP_FORCE_OS:-}" ]]; then
		printf '%s\n' "${ZSH_SETUP_FORCE_OS}"
		return 0
	fi

	local kernel
	kernel="$(uname -s)"
	case "${kernel}" in
	Darwin) printf 'darwin\n' ;;
	Linux) printf 'linux\n' ;;
	*) printf '%s\n' "${kernel}" | tr '[:upper:]' '[:lower:]' ;;
	esac
}

backup_stamp() {
	if [[ -n "${ZSH_SETUP_EFFECTIVE_BACKUP_STAMP:-}" ]]; then
		printf '%s\n' "${ZSH_SETUP_EFFECTIVE_BACKUP_STAMP}"
		return 0
	fi

	if [[ -n "${ZSH_SETUP_BACKUP_STAMP:-}" ]]; then
		ZSH_SETUP_EFFECTIVE_BACKUP_STAMP="${ZSH_SETUP_BACKUP_STAMP}"
	else
		ZSH_SETUP_EFFECTIVE_BACKUP_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
	fi

	printf '%s\n' "${ZSH_SETUP_EFFECTIVE_BACKUP_STAMP}"
}

backup_root() {
	printf '%s\n' "$(zsh_setup_state_root)/backups"
}

update_state_dir() {
	printf '%s\n' "$(zsh_setup_state_root)/updates"
}

update_cache_file() {
	printf '%s\n' "$(update_state_dir)/status.env"
}

update_prompt_file() {
	printf '%s\n' "$(update_state_dir)/last-prompted-rev"
}

latest_backup_stamp() {
	local root
	root="$(backup_root)"
	[[ -d "${root}" ]] || return 1

	find "${root}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tail -n 1
}

copy_if_exists() {
	local src="$1"
	local dest="$2"

	if [[ -f "${src}" ]]; then
		mkdir -p "$(dirname "${dest}")"
		cp "${src}" "${dest}"
	fi
}

copy_dir_if_exists() {
	local src="$1"
	local dest="$2"

	if [[ -d "${src}" ]]; then
		mkdir -p "${dest}"
		cp -R "${src}/." "${dest}"
	fi
}

backup_file() {
	local src="$1"
	local rel="$2"
	local dest
	dest="$(backup_root)/$(backup_stamp)/${rel}"
	copy_if_exists "${src}" "${dest}"
}

backup_dir() {
	local src="$1"
	local rel="$2"
	local dest
	dest="$(backup_root)/$(backup_stamp)/${rel}"
	copy_dir_if_exists "${src}" "${dest}"
}

install_chezmoi() {
	if command_exists chezmoi; then
		return 0
	fi

	ensure_local_bin_on_path
	if command_exists brew; then
		log "Installing chezmoi with Homebrew"
		brew install chezmoi
		return 0
	fi

	if command_exists curl; then
		log "Installing chezmoi into ${HOME}/.local/bin"
		mkdir -p "${HOME}/.local/bin"
		sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${HOME}/.local/bin"
		return 0
	fi

	die "chezmoi is required and neither brew nor curl is available"
}

install_mise() {
	if command_exists mise; then
		return 0
	fi

	ensure_local_bin_on_path
	if command_exists brew; then
		log "Installing mise with Homebrew"
		brew install mise
		return 0
	fi

	if command_exists curl; then
		log "Installing mise into ${HOME}/.local/bin"
		mkdir -p "${HOME}/.local/bin"
		curl https://mise.run | sh
		return 0
	fi

	die "mise is required and neither brew nor curl is available"
}
