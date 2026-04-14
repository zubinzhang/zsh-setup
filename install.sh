#!/usr/bin/env bash

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
ROOT=""
INSTALL_HOME="${ZSH_SETUP_HOME:-${HOME}/.local/share/zsh-setup}"
DEFAULT_REPO_URL="https://github.com/zubinzhang/zsh-setup.git"
DEFAULT_ARCHIVE_URL="https://github.com/zubinzhang/zsh-setup/archive/refs/heads/main.tar.gz"
REPO_URL="${ZSH_SETUP_REPO_URL:-${DEFAULT_REPO_URL}}"
ARCHIVE_URL="${ZSH_SETUP_ARCHIVE_URL:-${DEFAULT_ARCHIVE_URL}}"
ARCHIVE_URL_EXPLICIT=0

if [[ -n "${ZSH_SETUP_ARCHIVE_URL+set}" ]]; then
	ARCHIVE_URL_EXPLICIT=1
fi

case "${SCRIPT_SOURCE}" in
*/install.sh | install.sh)
	if [[ -f "${SCRIPT_SOURCE}" ]]; then
		ROOT="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
	fi
	;;
esac

run_local_bootstrap() {
	local base="$1"
	shift
	exec "${base}/scripts/install-managed.sh" "$@"
}

install_from_git_clone() {
	command -v git >/dev/null 2>&1 || return 1
	if [[ -e "${INSTALL_HOME}" ]]; then
		printf '[zsh-setup] ERROR: %s already exists and is not a managed checkout\n' "${INSTALL_HOME}" >&2
		exit 1
	fi

	mkdir -p "$(dirname "${INSTALL_HOME}")"
	if ! git clone --depth 1 "${REPO_URL}" "${INSTALL_HOME}" >/dev/null 2>&1; then
		rm -rf "${INSTALL_HOME}"
		return 1
	fi

	exec "${INSTALL_HOME}/scripts/install-managed.sh" "$@"
}

install_from_archive() {
	local tmpdir archive extracted
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir}"' EXIT

	command -v curl >/dev/null 2>&1 || {
		printf '[zsh-setup] ERROR: curl is required for raw install\n' >&2
		exit 1
	}
	command -v tar >/dev/null 2>&1 || {
		printf '[zsh-setup] ERROR: tar is required for raw install\n' >&2
		exit 1
	}

	archive="${tmpdir}/zsh-setup.tar.gz"
	curl -fsSL "${ARCHIVE_URL}" -o "${archive}"
	tar -xzf "${archive}" -C "${tmpdir}"
	extracted="$(find "${tmpdir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
	[[ -n "${extracted}" ]] || {
		printf '[zsh-setup] ERROR: failed to extract archive from %s\n' "${ARCHIVE_URL}" >&2
		exit 1
	}

	if [[ -e "${INSTALL_HOME}" ]]; then
		printf '[zsh-setup] ERROR: %s already exists and is not a managed checkout\n' "${INSTALL_HOME}" >&2
		exit 1
	fi

	mkdir -p "$(dirname "${INSTALL_HOME}")"
	cp -R "${extracted}" "${INSTALL_HOME}"
	exec "${INSTALL_HOME}/scripts/install-managed.sh" "$@"
}

if [[ -n "${ROOT}" && -x "${ROOT}/scripts/install-managed.sh" ]]; then
	run_local_bootstrap "${ROOT}" "$@"
fi

if [[ -x "${INSTALL_HOME}/scripts/install-managed.sh" ]]; then
	if git -C "${INSTALL_HOME}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${INSTALL_HOME}" pull --ff-only --quiet >/dev/null 2>&1 || true
	fi
	run_local_bootstrap "${INSTALL_HOME}" "$@"
fi

if [[ "${ARCHIVE_URL_EXPLICIT}" -eq 0 ]] && install_from_git_clone "$@"; then
	exit 0
fi

install_from_archive "$@"
