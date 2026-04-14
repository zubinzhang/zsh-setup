#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

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

	chezmoi apply --source="${source_dir}"
}

main "$@"
