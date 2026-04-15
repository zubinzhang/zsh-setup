#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
	[[ "$(detect_os)" == "darwin" ]] || return 0
	[[ "${ZSH_SETUP_CONFIGURE_ITERM2_FONT:-0}" == "1" ]] || return 0
	command_exists osascript || return 0

	if [[ ! -d "/Applications/iTerm.app" && ! -d "${HOME}/Applications/iTerm.app" ]]; then
		return 0
	fi

	log "iTerm2 font integration requested; ensure the active profile uses $(nerd_font_family)"
}

main "$@"
