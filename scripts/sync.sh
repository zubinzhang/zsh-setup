#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
	local source_dir dirty
	command_exists chezmoi || die "chezmoi is required"
	command_exists git || die "git is required"

	source_dir="$(chezmoi source-path)"
	[[ -d "${source_dir}" ]] || die "chezmoi source path does not exist: ${source_dir}"

	dirty="$(git -C "${source_dir}" status --porcelain --untracked-files=normal)"
	if [[ -n "${dirty}" ]]; then
		die "chezmoi source has local changes; refusing to sync"
	fi

	chezmoi update --apply
}

main "$@"
