#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
	local zshrcd file
	zshrcd="$(config_home)/zsh/zshrc.d"
	[[ -d "${zshrcd}" ]] || return 0

	for file in \
		00-options.zsh \
		10-completion.zsh \
		15-history.zsh \
		20-integrations.zsh \
		25-updates.zsh \
		30-kube.zsh \
		50-local.zsh \
		60-prompt.zsh; do
		rm -f "${zshrcd}/${file}"
	done
}

main "$@"
