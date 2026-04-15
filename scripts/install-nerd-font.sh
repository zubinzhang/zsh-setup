#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

font_is_installed() {
	managed_nerd_font_exists
}

main() {
	local font_dir tmpdir archive
	font_dir="$(font_home)"
	mkdir -p "${font_dir}"

	if font_is_installed; then
		log "Nerd Font already present in ${font_dir}"
		return 0
	fi

	command_exists curl || die "curl is required to install the managed Nerd Font"
	command_exists unzip || die "unzip is required to install the managed Nerd Font"

	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir:-}"' EXIT
	archive="${tmpdir}/JetBrainsMono.zip"

	curl -fsSL "$(nerd_font_archive_url)" -o "${archive}"
	unzip -oq "${archive}" -d "${font_dir}"

	if command_exists fc-cache; then
		fc-cache -f "${font_dir}" >/dev/null 2>&1 || true
	fi

	log "installed $(nerd_font_family) into ${font_dir}"
}

main "$@"
