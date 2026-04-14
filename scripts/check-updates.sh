#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

MODE="refresh"

for arg in "$@"; do
	case "${arg}" in
	--refresh) MODE="refresh" ;;
	--cache) MODE="cache" ;;
	*)
		die "unsupported argument: ${arg}"
		;;
	esac
done

print_kv() {
	local key="$1"
	local value="$2"
	printf '%s=%q\n' "${key}" "${value}"
}

print_defaults() {
	print_kv "ZSH_SETUP_UPDATE_STATUS" "unknown"
	print_kv "ZSH_SETUP_UPDATE_BRANCH" ""
	print_kv "ZSH_SETUP_UPDATE_LOCAL_REV" ""
	print_kv "ZSH_SETUP_UPDATE_REMOTE_REV" ""
	print_kv "ZSH_SETUP_UPDATE_CHECKED_AT" "0"
}

emit_cache() {
	local cache_file
	cache_file="$(update_cache_file)"
	if [[ -f "${cache_file}" ]]; then
		cat "${cache_file}"
	else
		print_defaults
	fi
}

source_dir() {
	if [[ -n "${ZSH_SETUP_CHEZMOI_SOURCE_PATH:-}" ]]; then
		printf '%s\n' "${ZSH_SETUP_CHEZMOI_SOURCE_PATH}"
		return 0
	fi
	chezmoi source-path
}

refresh_cache() {
	local state_dir cache_file repo_dir branch upstream remote remote_branch
	local local_rev remote_rev checked_at status

	state_dir="$(update_state_dir)"
	cache_file="$(update_cache_file)"
	mkdir -p "${state_dir}"

	checked_at="$(date +%s)"
	status="unknown"
	branch=""
	local_rev=""
	remote_rev=""

	command_exists git || die "git is required"
	command_exists chezmoi || die "chezmoi is required"

	repo_dir="$(source_dir)"
	[[ -d "${repo_dir}" ]] || die "chezmoi source path does not exist: ${repo_dir}"

	if [[ -n "$(git -C "${repo_dir}" status --porcelain --untracked-files=normal)" ]]; then
		status="dirty"
	else
		branch="$(git -C "${repo_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
		upstream="$(git -C "${repo_dir}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
		local_rev="$(git -C "${repo_dir}" rev-parse HEAD 2>/dev/null || true)"

		if [[ -n "${upstream}" ]]; then
			remote="${upstream%%/*}"
			remote_branch="${upstream#*/}"
			git -C "${repo_dir}" fetch --quiet "${remote}" "${remote_branch}" >/dev/null 2>&1 || true
			remote_rev="$(git -C "${repo_dir}" rev-parse "${upstream}" 2>/dev/null || true)"
		fi

		if [[ -z "${upstream}" || -z "${remote_rev}" || -z "${local_rev}" ]]; then
			status="unknown"
		elif [[ "${local_rev}" == "${remote_rev}" ]]; then
			status="up_to_date"
		elif git -C "${repo_dir}" merge-base --is-ancestor HEAD "${upstream}" >/dev/null 2>&1; then
			status="available"
		else
			status="manual"
		fi
	fi

	{
		print_kv "ZSH_SETUP_UPDATE_STATUS" "${status}"
		print_kv "ZSH_SETUP_UPDATE_BRANCH" "${branch}"
		print_kv "ZSH_SETUP_UPDATE_LOCAL_REV" "${local_rev}"
		print_kv "ZSH_SETUP_UPDATE_REMOTE_REV" "${remote_rev}"
		print_kv "ZSH_SETUP_UPDATE_CHECKED_AT" "${checked_at}"
	} >"${cache_file}"

	cat "${cache_file}"
}

main() {
	case "${MODE}" in
	refresh) refresh_cache ;;
	cache) emit_cache ;;
	esac
}

main "$@"
