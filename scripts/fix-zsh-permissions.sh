#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

repair_dir() {
	local dir="$1"
	[[ -d "${dir}" ]] || return 0

	if [[ -w "${dir}" || -O "${dir}" ]]; then
		chmod go-w "${dir}" >/dev/null 2>&1 || true
	fi
}

main() {
	local dir

	mkdir -p "$(cache_home)/zsh/completions"

	for dir in \
		"$(cache_home)/zsh" \
		"$(cache_home)/zsh/completions" \
		"$(data_home)/zsh-autosuggestions" \
		"$(data_home)/zsh-syntax-highlighting" \
		"$(data_home)/zsh-completions" \
		"$(font_home)" \
		/opt/homebrew/share \
		/usr/local/share; do
		repair_dir "${dir}"
	done
}

main "$@"
