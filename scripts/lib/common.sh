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

zsh_setup_install_home() {
	printf '%s\n' "${ZSH_SETUP_HOME:-$(data_home)/zsh-setup}"
}

managed_source_dir() {
	printf '%s\n' "$(zsh_setup_install_home)/home"
}

managed_zshrc_marker() {
	printf '%s\n' '# zsh entrypoint managed by chezmoi'
}

has_managed_zshrc_marker() {
	local marker
	marker="$(managed_zshrc_marker)"
	[[ -f "${HOME}/.zshrc" ]] && grep -Fqx "${marker}" "${HOME}/.zshrc"
}

managed_repo_dir() {
	local install_home source_dir
	install_home="$(zsh_setup_install_home)"
	source_dir="$(managed_source_dir)"

	if git -C "${install_home}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		printf '%s\n' "${install_home}"
		return 0
	fi

	if git -C "${source_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		printf '%s\n' "${source_dir}"
		return 0
	fi

	return 1
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

dir_has_entries() {
	local dir="$1"
	[[ -d "${dir}" ]] || return 1
	find "${dir}" -mindepth 1 -print -quit | grep -q .
}

dir_has_unmanaged_zsh_entries() {
	local dir="$1"
	[[ -d "${dir}" ]] || return 1
	find "${dir}" -mindepth 1 -maxdepth 1 ! -name local -print -quit | grep -q .
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

legacy_shell_state_paths() {
	local cfg
	cfg="$(config_home)"

	[[ -f "${HOME}/.zshrc" ]] && printf '%s\n' "${HOME}/.zshrc"
	[[ -f "${cfg}/starship.toml" ]] && printf '%s\n' "${cfg}/starship.toml"
	[[ -f "${cfg}/shell/secrets.zsh" ]] && printf '%s\n' "${cfg}/shell/secrets.zsh"
	dir_has_entries "${cfg}/mise" && printf '%s\n' "${cfg}/mise"
	dir_has_unmanaged_zsh_entries "${cfg}/zsh" && printf '%s\n' "${cfg}/zsh"
}

has_existing_shell_state() {
	[[ -n "$(legacy_shell_state_paths)" ]]
}

is_managed_install() {
	has_managed_zshrc_marker
}

backup_current_shell_state() {
	local cfg
	cfg="$(config_home)"

	backup_file "${HOME}/.zshrc" "dot_zshrc"
	backup_file "${cfg}/starship.toml" "dot_config/starship.toml"
	backup_file "${cfg}/shell/secrets.zsh" "dot_config/shell/secrets.zsh"
	backup_dir "${cfg}/mise" "dot_config/mise"
	backup_dir "${cfg}/zsh" "dot_config/zsh"
}

seed_local_overlay_from_legacy_secrets() {
	local cfg overlay_dir secrets_src
	cfg="$(config_home)"
	overlay_dir="${cfg}/zsh/local"
	secrets_src="${cfg}/shell/secrets.zsh"

	mkdir -p "${overlay_dir}"
	if [[ -f "${secrets_src}" ]]; then
		cp "${secrets_src}" "${overlay_dir}/secrets.zsh"
	fi
}

remove_managed_target_paths() {
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
}

confirm_with_tty() {
	local prompt="$1"
	local reply=""

	if [[ -n "${ZSH_SETUP_CONFIRM_RESPONSE:-}" ]]; then
		reply="${ZSH_SETUP_CONFIRM_RESPONSE}"
	elif [[ -r /dev/tty && -w /dev/tty ]]; then
		printf '%s' "${prompt}" >/dev/tty
		IFS= read -r reply </dev/tty || true
		printf '\n' >/dev/tty
	else
		die "confirmation required but no interactive tty is available; rerun with --yes if you want to continue"
	fi

	case "${reply}" in
	Y | y | YES | Yes | yes) return 0 ;;
	*) return 1 ;;
	esac
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
