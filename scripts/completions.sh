#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
	local dir
	dir="$(cache_home)/zsh/completions"
	mkdir -p "${dir}"

	if command_exists kubectl; then
		kubectl completion zsh >"${dir}/_kubectl"
		log "refreshed kubectl completion"
	fi
	if command_exists helm; then
		helm completion zsh >"${dir}/_helm"
		log "refreshed helm completion"
	fi
}

main "$@"
