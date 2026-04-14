#!/usr/bin/env bash

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
ROOT=""
INSTALL_HOME="${ZSH_SETUP_HOME:-${HOME}/.local/share/zsh-setup}"
ARCHIVE_URL="${ZSH_SETUP_ARCHIVE_URL:-https://github.com/zubinzhang/zsh-setup/archive/refs/heads/main.tar.gz}"
TARGET_SCRIPT="scripts/rollback.sh"

case "${SCRIPT_SOURCE}" in
*/rollback.sh | rollback.sh)
	if [[ -f "${SCRIPT_SOURCE}" ]]; then
		ROOT="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
	fi
	;;
esac

run_local_target() {
	local base="$1"
	shift
	exec "${base}/${TARGET_SCRIPT}" "$@"
}

run_from_archive() {
	local tmpdir archive extracted
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir}"' EXIT

	command -v curl >/dev/null 2>&1 || {
		printf '[zsh-setup] ERROR: curl is required for raw rollback\n' >&2
		exit 1
	}
	command -v tar >/dev/null 2>&1 || {
		printf '[zsh-setup] ERROR: tar is required for raw rollback\n' >&2
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

	exec "${extracted}/${TARGET_SCRIPT}" "$@"
}

if [[ -n "${ROOT}" && -x "${ROOT}/${TARGET_SCRIPT}" ]]; then
	run_local_target "${ROOT}" "$@"
fi

if [[ -x "${INSTALL_HOME}/${TARGET_SCRIPT}" ]]; then
	run_local_target "${INSTALL_HOME}" "$@"
fi

run_from_archive "$@"
