#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

remove_launchd() {
	local plist
	plist="${HOME}/Library/LaunchAgents/com.zubin.zsh-setup.sync.plist"

	if command_exists launchctl && [[ -f "${plist}" ]]; then
		launchctl unload "${plist}" >/dev/null 2>&1 || true
	fi
	rm -f "${plist}"
}

remove_systemd_user() {
	local unit_dir service_file timer_file
	unit_dir="$(config_home)/systemd/user"
	service_file="${unit_dir}/zsh-setup-sync.service"
	timer_file="${unit_dir}/zsh-setup-sync.timer"

	if command_exists systemctl; then
		systemctl --user disable --now zsh-setup-sync.timer >/dev/null 2>&1 || true
		systemctl --user disable zsh-setup-sync.service >/dev/null 2>&1 || true
		systemctl --user daemon-reload >/dev/null 2>&1 || true
	fi
	rm -f "${service_file}" "${timer_file}"
}

main() {
	case "$(detect_os)" in
	darwin) remove_launchd ;;
	linux) remove_systemd_user ;;
	*) warn "unsupported OS for sync task removal: $(detect_os)" ;;
	esac
}

main "$@"
