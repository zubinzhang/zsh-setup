#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/helpers/testlib.sh
source "${ROOT}/tests/helpers/testlib.sh"

test_kube_prompt_marks_prod_context() {
	local sandbox bin_dir output
	sandbox="$(mk_test_tmpdir)"
	bin_dir="${sandbox}/bin"
	mkdir -p "${bin_dir}"

	cat >"${bin_dir}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == "config current-context" ]]; then
  printf 'prod-cluster\n'
elif [[ "$*" == "config view --minify --output jsonpath={..namespace}" ]]; then
  printf 'payments'
else
  printf 'unexpected kubectl args: %s\n' "$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/kubectl"

	output="$(
		PATH="${bin_dir}:$PATH" \
			"${ROOT}/scripts/kube-prompt.sh"
	)"

	assert_contains "${output}" 'ZSH_SETUP_KUBE_PROMPT=prod-cluster/payments'
	assert_contains "${output}" 'ZSH_SETUP_KUBE_STYLE=danger'
}

test_zsh_integrations_configure_optional_plugins_in_order() {
	local integrations
	integrations="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/20-runtime.zsh")"

	assert_contains "${integrations}" "ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'"
	assert_contains "${integrations}" 'ZSH_AUTOSUGGEST_USE_ASYNC'
	assert_contains "${integrations}" 'zsh-autosuggestions/zsh-autosuggestions.zsh'
	assert_contains "${integrations}" 'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'

	if [[ "${integrations}" != *'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE'*'zsh-autosuggestions/zsh-autosuggestions.zsh'* ]]; then
		fail "expected autosuggestion defaults before plugin source"
	fi

	if [[ "${integrations}" != *'zsh-autosuggestions/zsh-autosuggestions.zsh'*'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'* ]]; then
		fail "expected syntax highlighting to load after autosuggestions"
	fi
}

test_install_shell_deps_keeps_plugin_fallback_paths_aligned() {
	local installer
	installer="$(cat "${ROOT}/scripts/install-shell-deps.sh")"

	assert_contains "${installer}" 'install_vivid'
	assert_contains "${installer}" 'Installing vivid...'
	assert_contains "${installer}" "\${DATA_HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"
	assert_contains "${installer}" "\${DATA_HOME}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
}

test_bootstrap_runs_font_install_compinit_repair_and_iterm_setup() {
	local sandbox home bin_dir log_file
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	log_file="${sandbox}/bootstrap.log"
	mkdir -p "${home}" "${bin_dir}"

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  printf 'managed-starship\n' >"${home}/.config/starship.toml"
  printf 'bindkey test\n' >"${home}/.config/zsh/zshrc.d/10-core.zsh"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
  chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git eza vivid; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font; do
		cat >"${sandbox}/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${script_name}" == "install-nerd-font" ]]; then
  mkdir -p "${home}/Library/Fonts"
  printf 'fontdata' >"${home}/Library/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf"
fi
printf '%s\n' "${script_name}" >>"${log_file}"
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		"${ROOT}/scripts/bootstrap.sh"

	assert_equals $'install-shell-deps\ninstall-nerd-font\nfix-zsh-permissions\nconfigure-iterm2-font' "$(cat "${log_file}")"
}

test_bootstrap_seeds_global_mise_config_from_repo_tools() {
	local sandbox home bin_dir config
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	mkdir -p "${home}" "${bin_dir}"

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  printf 'managed-starship\n' >"${home}/.config/starship.toml"
  printf 'bindkey test\n' >"${home}/.config/zsh/zshrc.d/10-core.zsh"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
  chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git eza vivid; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font; do
		cat >"${sandbox}/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${script_name}" == "install-nerd-font" ]]; then
  mkdir -p "${home}/Library/Fonts"
  printf 'fontdata' >"${home}/Library/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf"
fi
exit 0
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		"${ROOT}/scripts/bootstrap.sh"

	config="$(cat "${home}/.config/mise/config.toml")"
	assert_contains "${config}" 'bun = "1.3.12"'
	assert_contains "${config}" 'go = "1.26.2"'
	assert_contains "${config}" 'node = "24.14.0"'
	assert_contains "${config}" 'python = "3.14.4"'
	assert_contains "${config}" 'yarn = "1.22.22"'
	assert_contains "${config}" 'helm = "latest"'
	assert_contains "${config}" 'kubectl = "latest"'
	assert_contains "${config}" 'starship = "latest"'
}

test_bootstrap_preserves_existing_global_mise_config() {
	local sandbox home bin_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	mkdir -p "${home}" "${home}/.config/mise" "${bin_dir}"

	printf '[tools]\nnode = "20.19.5"\n' >"${home}/.config/mise/config.toml"

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  printf 'managed-starship\n' >"${home}/.config/starship.toml"
  printf 'bindkey test\n' >"${home}/.config/zsh/zshrc.d/10-core.zsh"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
  chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git eza vivid; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font; do
		cat >"${sandbox}/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${script_name}" == "install-nerd-font" ]]; then
  mkdir -p "${home}/Library/Fonts"
  printf 'fontdata' >"${home}/Library/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf"
fi
exit 0
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		"${ROOT}/scripts/bootstrap.sh"

	assert_equals $'[tools]\nnode = "20.19.5"' "$(cat "${home}/.config/mise/config.toml")"
}

test_install_nerd_font_is_idempotent_in_user_font_dir() {
	local sandbox home bin_dir font_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	font_dir="${home}/Library/Fonts"
	mkdir -p "${bin_dir}" "${font_dir}"

	cat >"${bin_dir}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  -o)
    out="$2"
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done
printf 'zipdata' >"${out}"
EOF
	chmod +x "${bin_dir}/curl"

	cat >"${bin_dir}/unzip" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'fontdata' >"${font_dir}/JetBrainsMonoNerdFontMono-Regular.ttf"
EOF
	chmod +x "${bin_dir}/unzip"

	cat >"${bin_dir}/fc-cache" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
	chmod +x "${bin_dir}/fc-cache"

	HOME="${home}" PATH="${bin_dir}:$PATH" ZSH_SETUP_FORCE_OS="darwin" "${ROOT}/scripts/install-nerd-font.sh"
	HOME="${home}" PATH="${bin_dir}:$PATH" ZSH_SETUP_FORCE_OS="darwin" "${ROOT}/scripts/install-nerd-font.sh"

	assert_dir_exists "${font_dir}"
	assert_file_exists "${font_dir}/JetBrainsMonoNerdFontMono-Regular.ttf"
	assert_equals "1" "$(find "${font_dir}" -name 'JetBrainsMonoNerdFontMono-Regular.ttf' | wc -l | tr -d ' ')"
}

test_fix_zsh_permissions_removes_group_write_from_completion_paths() {
	local sandbox home target mode
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	target="${home}/.local/share/zsh-autosuggestions"
	mkdir -p "${target}"
	chmod 0775 "${target}"

	HOME="${home}" \
		XDG_DATA_HOME="${home}/.local/share" \
		XDG_CACHE_HOME="${home}/.cache" \
		"${ROOT}/scripts/fix-zsh-permissions.sh"

	if stat -f '%Lp' "${target}" >/dev/null 2>&1; then
		mode="$(stat -f '%Lp' "${target}")"
	else
		mode="$(stat -c '%a' "${target}")"
	fi

	assert_equals "755" "${mode}"
}

test_prune_zsh_modules_removes_legacy_files() {
	local sandbox home zshrcd
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	zshrcd="${home}/.config/zsh/zshrc.d"
	mkdir -p "${zshrcd}"

	printf 'legacy\n' >"${zshrcd}/00-options.zsh"
	printf 'legacy\n' >"${zshrcd}/10-completion.zsh"
	printf 'core\n' >"${zshrcd}/10-core.zsh"
	printf 'runtime\n' >"${zshrcd}/20-runtime.zsh"
	printf 'state\n' >"${zshrcd}/30-state.zsh"
	printf 'aliases\n' >"${zshrcd}/40-aliases.zsh"
	printf 'final\n' >"${zshrcd}/50-final.zsh"

	HOME="${home}" XDG_CONFIG_HOME="${home}/.config" "${ROOT}/scripts/prune-zsh-modules.sh"

	assert_not_exists "${zshrcd}/00-options.zsh"
	assert_not_exists "${zshrcd}/10-completion.zsh"
	assert_file_exists "${zshrcd}/10-core.zsh"
	assert_file_exists "${zshrcd}/50-final.zsh"
}

test_zsh_runtime_uses_lazy_mise_activation() {
	local integrations eager_activation
	integrations="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/20-runtime.zsh")"
	eager_activation="eval \"\$(mise activate zsh)\""

	assert_contains "${integrations}" 'command mise activate zsh'
	if [[ "${integrations}" == *"${eager_activation}"* ]]; then
		fail "expected mise activation to be lazy"
	fi
}

test_zsh_runtime_exports_ls_colors_with_vivid() {
	local integrations
	integrations="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/20-runtime.zsh")"

	assert_contains "${integrations}" 'command -v vivid'
	assert_contains "${integrations}" 'vivid generate tokyonight-night'
	assert_contains "${integrations}" "export LS_COLORS=\"\${_zsh_setup_ls_colors}\""
}

test_completion_runtime_handles_insecure_dirs_without_prompt() {
	local completion
	completion="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/10-core.zsh")"

	assert_contains "${completion}" 'autoload -Uz compaudit compinit'
	assert_contains "${completion}" 'zmodload zsh/stat'
	assert_contains "${completion}" 'compinit -C -d'
	assert_contains "${completion}" 'compinit -i -d'
}

test_update_check_runtime_refreshes_once_in_background() {
	local state_module
	state_module="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/30-state.zsh")"

	assert_contains "${state_module}" 'typeset -g ZSH_SETUP_UPDATE_REFRESH_SCHEDULED=0'
	assert_contains "${state_module}" '_zsh_setup_load_update_cache()'
	assert_contains "${state_module}" "source \"\${cache_file}\""
	assert_contains "${state_module}" '_zsh_setup_schedule_update_refresh()'
	assert_contains "${state_module}" 'if (( ZSH_SETUP_UPDATE_REFRESH_SCHEDULED != 0 )); then'
	assert_contains "${state_module}" 'ZSH_SETUP_UPDATE_REFRESH_SCHEDULED=1'
	assert_contains "${state_module}" '( zsh-setup-check-updates --refresh >/dev/null 2>&1 ) &!'
	if [[ "${state_module}" == *'zsh-setup-check-updates --cache'* ]]; then
		fail "expected startup update path to read cache file directly"
	fi
}

test_zsh_history_bindings_search_by_prefix() {
	local history_bindings
	history_bindings="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/10-core.zsh")"

	assert_contains "${history_bindings}" 'autoload -Uz up-line-or-beginning-search down-line-or-beginning-search'
	assert_contains "${history_bindings}" 'zle -N up-line-or-beginning-search'
	assert_contains "${history_bindings}" 'zle -N down-line-or-beginning-search'
	assert_contains "${history_bindings}" "bindkey '^[[A' up-line-or-beginning-search"
	assert_contains "${history_bindings}" "bindkey '^[[B' down-line-or-beginning-search"
	assert_contains "${history_bindings}" "bindkey '^[OA' up-line-or-beginning-search"
	assert_contains "${history_bindings}" "bindkey '^[OB' down-line-or-beginning-search"
	assert_contains "${history_bindings}" "bindkey -M viins '^[[A' up-line-or-beginning-search"
	assert_contains "${history_bindings}" "bindkey -M viins '^[[B' down-line-or-beginning-search"
}

test_zsh_modules_are_consolidated_to_five_files() {
	local modules
	modules="$(
		cd "${ROOT}/home/dot_config/zsh/zshrc.d"
		printf '%s\n' *.zsh
	)"

	assert_equals $'10-core.zsh\n20-runtime.zsh\n30-state.zsh\n40-aliases.zsh\n50-final.zsh' "${modules}"
}

test_migrate_backs_up_files_and_copies_secrets_overlay() {
	local sandbox home output_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p "${home}/.config/shell" "${home}/.config/mise" "${home}/.config/zsh"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	printf 'legacy-starship\n' >"${home}/.config/starship.toml"
	printf 'export API_TOKEN=secret\n' >"${home}/.config/shell/secrets.zsh"
	printf 'legacy-mise\n' >"${home}/.config/mise/config.toml"
	printf 'legacy-zsh-module\n' >"${home}/.config/zsh/legacy.zsh"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		ZSH_SETUP_BACKUP_STAMP="20260414T000000Z" \
		"${ROOT}/scripts/migrate.sh" --no-apply

	output_dir="${home}/.local/state/zsh-setup/backups/20260414T000000Z"
	assert_file_exists "${output_dir}/dot_zshrc"
	assert_file_exists "${output_dir}/dot_config/starship.toml"
	assert_file_exists "${output_dir}/dot_config/mise/config.toml"
	assert_file_exists "${output_dir}/dot_config/zsh/legacy.zsh"
	assert_file_exists "${home}/.config/zsh/local/secrets.zsh"
}

test_install_managed_flow_prompts_before_migrating_existing_config() {
	local sandbox home rc output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p "${home}/.config/mise"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	cat >"${sandbox}/bootstrap.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"${sandbox}/bootstrap-ran.marker"
EOF
	chmod +x "${sandbox}/bootstrap.sh"

	set +e
	output="$(
		HOME="${home}" \
			XDG_CONFIG_HOME="${home}/.config" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_CONFIRM_RESPONSE="n" \
			ZSH_SETUP_BOOTSTRAP_SCRIPT="${sandbox}/bootstrap.sh" \
			"${ROOT}/scripts/install-managed.sh" 2>&1
	)"
	rc=$?
	set -e

	[[ ${rc} -eq 0 ]] || fail "expected install-managed to exit cleanly when migration is declined"
	assert_contains "${output}" 'Existing shell config detected'
	assert_not_exists "${home}/bootstrap.marker"
	assert_not_exists "${home}/.local/state/zsh-setup/backups"
}

test_install_managed_flow_runs_backup_after_confirmation() {
	local sandbox home backup_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p "${home}/.config/shell" "${home}/.config/mise"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	printf 'export API_TOKEN=secret\n' >"${home}/.config/shell/secrets.zsh"
	printf 'legacy-mise\n' >"${home}/.config/mise/config.toml"
	cat >"${sandbox}/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"__SANDBOX__/bootstrap-ran.marker"
EOF
	sed -i.bak "s|__SANDBOX__|${sandbox}|g" "${sandbox}/bootstrap.sh"
	rm -f "${sandbox}/bootstrap.sh.bak"
	chmod +x "${sandbox}/bootstrap.sh"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		ZSH_SETUP_CONFIRM_RESPONSE="y" \
		ZSH_SETUP_BACKUP_STAMP="20260414T010203Z" \
		ZSH_SETUP_BOOTSTRAP_SCRIPT="${sandbox}/bootstrap.sh" \
		"${ROOT}/scripts/install-managed.sh"

	backup_dir="${home}/.local/state/zsh-setup/backups/20260414T010203Z"
	assert_file_exists "${backup_dir}/dot_zshrc"
	assert_file_exists "${backup_dir}/dot_config/mise/config.toml"
	assert_file_exists "${home}/.config/zsh/local/secrets.zsh"
	assert_file_exists "${sandbox}/bootstrap-ran.marker"
}

test_install_managed_flow_removes_stale_targets_before_bootstrap() {
	local sandbox home
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p \
		"${home}/.config/shell" \
		"${home}/.config/mise" \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/zsh/local" \
		"${home}/.local/bin"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	printf 'legacy-starship\n' >"${home}/.config/starship.toml"
	printf 'legacy-mise\n' >"${home}/.config/mise/config.toml"
	printf 'legacy-module\n' >"${home}/.config/zsh/zshrc.d/10-legacy.zsh"
	printf 'export API_TOKEN=secret\n' >"${home}/.config/shell/secrets.zsh"
	printf 'local-keep\n' >"${home}/.config/zsh/local/keep.zsh"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-kube-prompt"
	chmod +x \
		"${home}/.local/bin/zsh-setup-check-updates" \
		"${home}/.local/bin/zsh-setup-sync" \
		"${home}/.local/bin/zsh-setup-kube-prompt"

	cat >"${sandbox}/bootstrap.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[[ ! -e "${HOME}/.zshrc" ]]
[[ ! -e "${HOME}/.config/starship.toml" ]]
[[ ! -e "${HOME}/.config/mise" ]]
[[ ! -e "${HOME}/.config/zsh/zshrc.d" ]]
[[ ! -e "${HOME}/.local/bin/zsh-setup-check-updates" ]]
[[ ! -e "${HOME}/.local/bin/zsh-setup-sync" ]]
[[ ! -e "${HOME}/.local/bin/zsh-setup-kube-prompt" ]]
[[ -e "${HOME}/.config/zsh/local/keep.zsh" ]]
printf 'bootstrapped\n' >"${sandbox}/bootstrap-ran.marker"
EOF
	chmod +x "${sandbox}/bootstrap.sh"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		ZSH_SETUP_CONFIRM_RESPONSE="y" \
		ZSH_SETUP_BOOTSTRAP_SCRIPT="${sandbox}/bootstrap.sh" \
		"${ROOT}/scripts/install-managed.sh"

	assert_file_exists "${sandbox}/bootstrap-ran.marker"
}

test_install_managed_flow_skips_prompt_for_managed_state() {
	local sandbox home output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p "${home}"

	cat >"${home}/.zshrc" <<'EOF'
# zsh entrypoint managed by chezmoi
export PATH="$HOME/.local/bin:$PATH"
EOF
	cat >"${sandbox}/bootstrap.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"${sandbox}/bootstrap-ran.marker"
EOF
	chmod +x "${sandbox}/bootstrap.sh"

	output="$(
		HOME="${home}" \
			XDG_CONFIG_HOME="${home}/.config" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_CONFIRM_RESPONSE="n" \
			ZSH_SETUP_BOOTSTRAP_SCRIPT="${sandbox}/bootstrap.sh" \
			"${ROOT}/scripts/install-managed.sh"
	)"

	assert_file_exists "${sandbox}/bootstrap-ran.marker"
	if [[ -d "${home}/.local/state/zsh-setup/backups" ]]; then
		fail "expected managed install to skip migration backups"
	fi
	if [[ "${output}" == *"Existing shell config detected"* ]]; then
		fail "expected managed install to skip migration prompt"
	fi
}

test_install_managed_flow_treats_partial_state_as_unmanaged() {
	local sandbox home rc output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.local/bin"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	chmod +x "${home}/.local/bin/zsh-setup-check-updates"
	cat >"${sandbox}/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"${HOME}/bootstrap.marker"
EOF
	chmod +x "${sandbox}/bootstrap.sh"

	set +e
	output="$(
		HOME="${home}" \
			XDG_CONFIG_HOME="${home}/.config" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_CONFIRM_RESPONSE="n" \
			ZSH_SETUP_BOOTSTRAP_SCRIPT="${sandbox}/bootstrap.sh" \
			"${ROOT}/scripts/install-managed.sh" 2>&1
	)"
	rc=$?
	set -e

	[[ ${rc} -eq 0 ]] || fail "expected partial managed state to exit cleanly when migration is declined"
	assert_contains "${output}" 'Existing shell config detected'
	assert_not_exists "${home}/bootstrap.marker"
}

test_rollback_restores_latest_backup_and_original_files() {
	local sandbox home backup_root
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	backup_root="${home}/.local/state/zsh-setup/backups"
	mkdir -p \
		"${home}/.config/shell" \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/zsh" \
		"${home}/.config/mise" \
		"${home}/.local/bin" \
		"${backup_root}/20260414T000000Z/dot_config/shell" \
		"${backup_root}/20260415T000000Z/dot_config/shell" \
		"${backup_root}/20260415T000000Z/dot_config/mise" \
		"${backup_root}/20260415T000000Z/dot_config/zsh"

	printf 'managed\n' >"${home}/.zshrc"
	printf 'managed-starship\n' >"${home}/.config/starship.toml"
	printf 'echo managed\n' >"${home}/.config/zsh/zshrc.d/10-managed.zsh"
	printf 'managed-mise\n' >"${home}/.config/mise/config.toml"
	printf 'managed-local\n' >"${home}/.config/zsh/local-only.zsh"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	printf 'old-zshrc\n' >"${backup_root}/20260414T000000Z/dot_zshrc"
	printf 'new-zshrc\n' >"${backup_root}/20260415T000000Z/dot_zshrc"
	printf 'old-starship\n' >"${backup_root}/20260414T000000Z/dot_config/starship.toml"
	printf 'new-starship\n' >"${backup_root}/20260415T000000Z/dot_config/starship.toml"
	printf 'export OLD_SECRET=1\n' >"${backup_root}/20260415T000000Z/dot_config/shell/secrets.zsh"
	printf 'restored-mise\n' >"${backup_root}/20260415T000000Z/dot_config/mise/config.toml"
	printf 'restored-zsh\n' >"${backup_root}/20260415T000000Z/dot_config/zsh/legacy.zsh"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		ZSH_SETUP_FORCE_OS="darwin" \
		"${ROOT}/scripts/rollback.sh"

	assert_equals "new-zshrc" "$(cat "${home}/.zshrc")"
	assert_equals "new-starship" "$(cat "${home}/.config/starship.toml")"
	assert_equals "export OLD_SECRET=1" "$(cat "${home}/.config/shell/secrets.zsh")"
	assert_equals "restored-mise" "$(cat "${home}/.config/mise/config.toml")"
	assert_equals "restored-zsh" "$(cat "${home}/.config/zsh/legacy.zsh")"
	assert_not_exists "${home}/.config/zsh/local-only.zsh"
	assert_not_exists "${home}/.config/zsh/zshrc.d"
	assert_not_exists "${home}/.local/bin/zsh-setup-sync"
}

test_uninstall_removes_all_zsh_setup_directories_and_preserves_local_secrets() {
	local sandbox home overlay_dir install_home cache_root state_root font_dir data_root
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	overlay_dir="${home}/.config/zsh/local"
	install_home="${sandbox}/installed-repo"
	cache_root="${home}/.cache"
	state_root="${home}/.local/state"
	font_dir="${home}/Library/Fonts"
	data_root="${home}/.local/share"
	mkdir -p \
		"${overlay_dir}" \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/mise" \
		"${home}/.local/bin" \
		"${home}/Library/LaunchAgents" \
		"${install_home}" \
		"${cache_root}/zsh/completions" \
		"${state_root}/zsh-setup/backups" \
		"${font_dir}" \
		"${data_root}/zsh-autosuggestions" \
		"${data_root}/zsh-syntax-highlighting" \
		"${data_root}/zsh-completions" \
		"${data_root}/fzf"

	printf 'managed\n' >"${home}/.zshrc"
	printf 'managed-starship\n' >"${home}/.config/starship.toml"
	printf 'export PRIVATE=1\n' >"${overlay_dir}/secrets.zsh"
	printf 'echo managed\n' >"${home}/.config/zsh/zshrc.d/10-managed.zsh"
	printf 'managed-mise\n' >"${home}/.config/mise/config.toml"
	printf 'cache\n' >"${cache_root}/zsh/completions/_kubectl"
	printf 'backup\n' >"${state_root}/zsh-setup/backups/marker"
	printf 'repo\n' >"${install_home}/README.md"
	printf 'font\n' >"${font_dir}/JetBrainsMonoNerdFontMono-Regular.ttf"
	printf 'plugin\n' >"${data_root}/zsh-autosuggestions/zsh-autosuggestions.zsh"
	printf 'plugin\n' >"${data_root}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
	printf 'plugin\n' >"${data_root}/zsh-completions/_example"
	printf 'bin\n' >"${data_root}/fzf/README.md"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-kube-prompt"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	printf 'plist\n' >"${home}/Library/LaunchAgents/com.zubin.zsh-setup.sync.plist"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_CACHE_HOME="${cache_root}" \
		XDG_STATE_HOME="${state_root}" \
		XDG_DATA_HOME="${data_root}" \
		ZSH_SETUP_HOME="${install_home}" \
		ZSH_SETUP_FORCE_OS="darwin" \
		"${ROOT}/scripts/uninstall.sh"

	assert_not_exists "${home}/.zshrc"
	assert_not_exists "${home}/.config/starship.toml"
	assert_not_exists "${home}/.config/zsh/zshrc.d"
	assert_file_exists "${overlay_dir}/secrets.zsh"
	assert_not_exists "${home}/.config/mise"
	assert_not_exists "${install_home}"
	assert_not_exists "${cache_root}/zsh"
	assert_not_exists "${state_root}/zsh-setup"
	assert_not_exists "${font_dir}/JetBrainsMonoNerdFontMono-Regular.ttf"
	assert_not_exists "${data_root}/zsh-autosuggestions"
	assert_not_exists "${data_root}/zsh-syntax-highlighting"
	assert_not_exists "${data_root}/zsh-completions"
	assert_not_exists "${data_root}/fzf"
	assert_not_exists "${home}/.local/bin/zsh-setup-kube-prompt"
	assert_not_exists "${home}/.local/bin/zsh-setup-check-updates"
	assert_not_exists "${home}/.local/bin/zsh-setup-sync"
	assert_not_exists "${home}/Library/LaunchAgents/com.zubin.zsh-setup.sync.plist"
}

test_check_updates_detects_remote_update() {
	local sandbox home remote_dir install_home writer_dir output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	remote_dir="${sandbox}/remote.git"
	install_home="${sandbox}/installed-repo"
	writer_dir="${sandbox}/writer"
	mkdir -p "${home}"

	git init -q --bare "${remote_dir}"
	git clone -q "${remote_dir}" "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		git checkout -q -b main
		printf 'v1\n' >README.md
		git add README.md
		git commit -m init >/dev/null
		git push -u origin main >/dev/null
	)
	git --git-dir="${remote_dir}" symbolic-ref HEAD refs/heads/main

	git clone -q "${remote_dir}" "${writer_dir}"
	(
		cd "${writer_dir}"
		git config user.email test@example.com
		git config user.name test
		git checkout -q main
		printf 'v2\n' >>README.md
		git add README.md
		git commit -m update >/dev/null
		git push >/dev/null
	)

	output="$(
		HOME="${home}" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_HOME="${install_home}" \
			"${ROOT}/scripts/check-updates.sh" --refresh
	)"

	assert_contains "${output}" 'ZSH_SETUP_UPDATE_STATUS=available'
	assert_contains "${output}" 'ZSH_SETUP_UPDATE_BRANCH=main'
}

test_check_updates_reports_up_to_date() {
	local sandbox home remote_dir install_home output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	remote_dir="${sandbox}/remote.git"
	install_home="${sandbox}/installed-repo"
	mkdir -p "${home}"

	git init -q --bare "${remote_dir}"
	git clone -q "${remote_dir}" "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		git checkout -q -b main
		printf 'v1\n' >README.md
		git add README.md
		git commit -m init >/dev/null
		git push -u origin main >/dev/null
	)
	git --git-dir="${remote_dir}" symbolic-ref HEAD refs/heads/main

	output="$(
		HOME="${home}" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_HOME="${install_home}" \
			"${ROOT}/scripts/check-updates.sh" --refresh
	)"

	assert_contains "${output}" 'ZSH_SETUP_UPDATE_STATUS=up_to_date'
	assert_contains "${output}" 'ZSH_SETUP_UPDATE_BRANCH=main'
}

test_check_updates_uses_installed_repo_without_chezmoi_source_path() {
	local sandbox home install_home output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	install_home="${sandbox}/installed-repo"
	mkdir -p "${home}" "${install_home}/home"

	git init -q "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		printf 'v1\n' >README.md
		git add README.md
		git commit -m init >/dev/null
	)

	output="$(
		HOME="${home}" \
			XDG_STATE_HOME="${home}/.local/state" \
			ZSH_SETUP_HOME="${install_home}" \
			"${ROOT}/scripts/check-updates.sh" --refresh
	)"

	assert_contains "${output}" 'ZSH_SETUP_UPDATE_STATUS=unknown'
}

test_bootstrap_uses_apply_for_local_home_source() {
	local sandbox home bin_dir log_file
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	log_file="${sandbox}/chezmoi.log"
	mkdir -p "${home}" "${bin_dir}"

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"${log_file}"
if [[ "\$1" == "apply" && " \$* " == *" --source=${ROOT}/home "* ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  printf 'managed-starship\n' >"${home}/.config/starship.toml"
  printf 'bindkey test\n' >"${home}/.config/zsh/zshrc.d/10-core.zsh"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
  chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	cat >"${bin_dir}/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
	chmod +x "${bin_dir}/mise"

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font; do
		cat >"${sandbox}/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${script_name}" == "install-nerd-font" ]]; then
  mkdir -p "${home}/Library/Fonts"
  printf 'fontdata' >"${home}/Library/Fonts/JetBrainsMonoNerdFontMono-Regular.ttf"
fi
exit 0
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	PATH="${bin_dir}:$PATH" \
		HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		"${ROOT}/scripts/bootstrap.sh"

	assert_contains "$(cat "${log_file}")" "--source=${ROOT}/home"
	if grep -Fq 'init --apply' "${log_file}"; then
		fail "expected bootstrap to use chezmoi apply for the local home source"
	fi
}

test_repo_mise_tools_define_global_seed_without_chezmoi_or_gh() {
	local config
	config="$(cat "${ROOT}/mise.toml")"
	if [[ "${config}" == *$'\nchezmoi = '* || "${config}" == *$'\r\nchezmoi = '* ]]; then
		fail "expected repo mise config to exclude chezmoi"
	fi
	if [[ "${config}" == *$'\ngh = '* || "${config}" == *$'\r\ngh = '* ]]; then
		fail "expected repo mise config to exclude gh"
	fi
	assert_contains "${config}" 'bun = "1.3.12"'
	assert_contains "${config}" 'go = "1.26.2"'
	assert_contains "${config}" 'node = "24.14.0"'
	assert_contains "${config}" 'python = "3.14.4"'
	assert_contains "${config}" 'helm = "latest"'
	assert_contains "${config}" 'kubectl = "latest"'
	assert_contains "${config}" 'starship = "latest"'
}

test_install_supports_standalone_archive_managed_install() {
	local sandbox archive_src archive_file
	sandbox="$(mk_test_tmpdir)"
	archive_src="${sandbox}/zsh-setup-main"
	archive_file="${sandbox}/zsh-setup-main.tar.gz"
	mkdir -p "${archive_src}/scripts" "${sandbox}/bin" "${sandbox}/home"

	cat >"${archive_src}/scripts/install-managed.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"${HOME}/bootstrap.marker"
EOF
	chmod +x "${archive_src}/scripts/install-managed.sh"
	tar -czf "${archive_file}" -C "${sandbox}" "zsh-setup-main"

	cp "${ROOT}/install.sh" "${sandbox}/install.sh"
	chmod +x "${sandbox}/install.sh"

	HOME="${sandbox}/home" \
		ZSH_SETUP_HOME="${sandbox}/installed-repo" \
		ZSH_SETUP_ARCHIVE_URL="file://${archive_file}" \
		"${sandbox}/install.sh"

	assert_file_exists "${sandbox}/installed-repo/scripts/install-managed.sh"
	assert_file_exists "${sandbox}/home/bootstrap.marker"
}

test_install_supports_piped_reinstall() {
	local sandbox archive_src archive_file
	sandbox="$(mk_test_tmpdir)"
	archive_src="${sandbox}/zsh-setup-main"
	archive_file="${sandbox}/zsh-setup-main.tar.gz"
	mkdir -p "${archive_src}/scripts" "${sandbox}/home"

	cat >"${archive_src}/scripts/install-managed.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
counter_file="${HOME}/bootstrap.counter"
count=0
if [[ -f "${counter_file}" ]]; then
  count="$(cat "${counter_file}")"
fi
count=$((count + 1))
printf '%s\n' "${count}" >"${counter_file}"
EOF
	chmod +x "${archive_src}/scripts/install-managed.sh"
	tar -czf "${archive_file}" -C "${sandbox}" "zsh-setup-main"

	(
		cd "${sandbox}"
		HOME="${sandbox}/home" \
			ZSH_SETUP_HOME="${sandbox}/installed-repo" \
			ZSH_SETUP_ARCHIVE_URL="file://${archive_file}" \
			bash <"${ROOT}/install.sh"
	)

	(
		cd "${sandbox}"
		HOME="${sandbox}/home" \
			ZSH_SETUP_HOME="${sandbox}/installed-repo" \
			ZSH_SETUP_ARCHIVE_URL="file://${archive_file}" \
			bash <"${ROOT}/install.sh"
	)

	assert_equals "2" "$(cat "${sandbox}/home/bootstrap.counter")"
}

test_install_prefers_git_clone_when_git_is_available() {
	local sandbox bin_dir
	sandbox="$(mk_test_tmpdir)"
	bin_dir="${sandbox}/bin"
	mkdir -p "${bin_dir}" "${sandbox}/home"

	cat >"${bin_dir}/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "clone" ]]; then
  target="\${@: -1}"
  mkdir -p "\${target}/scripts"
  cat >"\${target}/scripts/install-managed.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrapped\n' >"\${HOME}/bootstrap.marker"
SCRIPT
  chmod +x "\${target}/scripts/install-managed.sh"
  exit 0
fi
printf 'unexpected git args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/git"

	cat >"${bin_dir}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl should not be called when git clone is available\n' >&2
exit 1
EOF
	chmod +x "${bin_dir}/curl"

	cp "${ROOT}/install.sh" "${sandbox}/install.sh"
	chmod +x "${sandbox}/install.sh"

	PATH="${bin_dir}:$PATH" \
		HOME="${sandbox}/home" \
		ZSH_SETUP_HOME="${sandbox}/installed-repo" \
		ZSH_SETUP_REPO_URL="https://example.invalid/zsh-setup.git" \
		"${sandbox}/install.sh"

	assert_file_exists "${sandbox}/installed-repo/scripts/install-managed.sh"
	assert_file_exists "${sandbox}/home/bootstrap.marker"
}

test_raw_rollback_wrapper_delegates_to_local_script() {
	local sandbox repo_home
	sandbox="$(mk_test_tmpdir)"
	repo_home="${sandbox}/installed-repo"
	mkdir -p "${repo_home}/scripts" "${sandbox}/home"

	cat >"${repo_home}/scripts/rollback.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'rolled-back\n' >"${HOME}/rollback.marker"
EOF
	chmod +x "${repo_home}/scripts/rollback.sh"

	cp "${ROOT}/rollback.sh" "${sandbox}/rollback.sh"
	chmod +x "${sandbox}/rollback.sh"

	HOME="${sandbox}/home" \
		ZSH_SETUP_HOME="${repo_home}" \
		"${sandbox}/rollback.sh"

	assert_equals "rolled-back" "$(cat "${sandbox}/home/rollback.marker")"
}

test_raw_uninstall_wrapper_delegates_to_local_script() {
	local sandbox repo_home
	sandbox="$(mk_test_tmpdir)"
	repo_home="${sandbox}/installed-repo"
	mkdir -p "${repo_home}/scripts" "${sandbox}/home"

	cat >"${repo_home}/scripts/uninstall.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uninstalled\n' >"${HOME}/uninstall.marker"
EOF
	chmod +x "${repo_home}/scripts/uninstall.sh"

	cp "${ROOT}/uninstall.sh" "${sandbox}/uninstall.sh"
	chmod +x "${sandbox}/uninstall.sh"

	HOME="${sandbox}/home" \
		ZSH_SETUP_HOME="${repo_home}" \
		"${sandbox}/uninstall.sh"

	assert_equals "uninstalled" "$(cat "${sandbox}/home/uninstall.marker")"
}

test_sync_refuses_dirty_source() {
	local sandbox bin_dir install_home home rc
	sandbox="$(mk_test_tmpdir)"
	bin_dir="${sandbox}/bin"
	install_home="${sandbox}/installed-repo"
	home="${sandbox}/home"
	mkdir -p "${bin_dir}" "${install_home}/home" "${home}"

	git init -q "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		printf 'tracked\n' >README.md
		git add README.md
		git commit -m init >/dev/null
		printf 'dirty\n' >DIRTY
	)

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" ]]; then
  touch "${sandbox}/unexpected-update"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	set +e
	HOME="${home}" ZSH_SETUP_HOME="${install_home}" PATH="${bin_dir}:$PATH" "${ROOT}/scripts/sync.sh"
	rc=$?
	set -e

	[[ ${rc} -ne 0 ]] || fail "expected sync to fail for dirty source"
	assert_not_exists "${sandbox}/unexpected-update"
}

test_sync_updates_clean_source() {
	local sandbox bin_dir install_home home log_file
	sandbox="$(mk_test_tmpdir)"
	bin_dir="${sandbox}/bin"
	install_home="${sandbox}/installed-repo"
	home="${sandbox}/home"
	log_file="${sandbox}/sync.log"
	mkdir -p "${bin_dir}" "${install_home}/home" "${home}"

	git init -q "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		printf 'tracked\n' >README.md
		git add README.md
		git commit -m init >/dev/null
	)

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" && " \$* " == *" --source=${install_home}/home "* ]]; then
  touch "${sandbox}/update-ran"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font doctor; do
		cat >"${sandbox}/${script_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${script_name}" >>"${log_file}"
exit 0
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	HOME="${home}" \
		ZSH_SETUP_HOME="${install_home}" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		ZSH_SETUP_DOCTOR_SCRIPT="${sandbox}/doctor.sh" \
		"${ROOT}/scripts/sync.sh"

	assert_file_exists "${sandbox}/update-ran"
	assert_equals $'install-shell-deps\ninstall-nerd-font\nfix-zsh-permissions\nconfigure-iterm2-font\ndoctor' "$(cat "${log_file}")"
}

test_sync_uses_installed_repo_without_chezmoi_source_path() {
	local sandbox home install_home bin_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	install_home="${sandbox}/installed-repo"
	bin_dir="${sandbox}/bin"
	mkdir -p "${install_home}/home" "${bin_dir}" "${home}"

	git init -q "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		printf 'tracked\n' >README.md
		git add README.md
		git commit -m init >/dev/null
	)

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "source-path" ]]; then
  printf 'source-path should not be called\n' >&2
  exit 1
elif [[ "\$1" == "apply" && " \$* " == *" --source=${install_home}/home "* ]]; then
  touch "${sandbox}/apply-ran"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	for script_name in install-shell-deps install-nerd-font fix-zsh-permissions configure-iterm2-font doctor; do
		cat >"${sandbox}/${script_name}.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${sandbox}/${script_name}.sh"
	done

	HOME="${home}" \
		ZSH_SETUP_HOME="${install_home}" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		ZSH_SETUP_DOCTOR_SCRIPT="${sandbox}/doctor.sh" \
		"${ROOT}/scripts/sync.sh"

	assert_file_exists "${sandbox}/apply-ran"
}

test_sync_fails_when_dependency_alignment_fails() {
	local sandbox bin_dir install_home home rc
	sandbox="$(mk_test_tmpdir)"
	bin_dir="${sandbox}/bin"
	install_home="${sandbox}/installed-repo"
	home="${sandbox}/home"
	mkdir -p "${bin_dir}" "${install_home}/home" "${home}"

	git init -q "${install_home}"
	(
		cd "${install_home}"
		git config user.email test@example.com
		git config user.name test
		printf 'tracked\n' >README.md
		git add README.md
		git commit -m init >/dev/null
	)

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" && " \$* " == *" --source=${install_home}/home "* ]]; then
  touch "${sandbox}/apply-ran"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	cat >"${sandbox}/install-shell-deps.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 1
EOF
	chmod +x "${sandbox}/install-shell-deps.sh"

	set +e
	HOME="${home}" \
		ZSH_SETUP_HOME="${install_home}" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		"${ROOT}/scripts/sync.sh"
	rc=$?
	set -e

	[[ ${rc} -ne 0 ]] || fail "expected sync to fail when dependency alignment fails"
	assert_file_exists "${sandbox}/apply-ran"
}

test_doctor_requires_vivid_and_managed_font_file() {
	local sandbox home rc output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/zsh/local" \
		"${home}/.local/bin" \
		"${home}/.local/state/zsh-setup/updates" \
		"${home}/.local/state/zsh-setup/backups" \
		"${home}/Library/Fonts" \
		"${sandbox}/bin"

	printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
	printf 'managed-starship\n' >"${home}/.config/starship.toml"
	printf 'managed\n' >"${home}/.config/zsh/zshrc.d/10-core.zsh"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"

	for cmd in zsh git chezmoi mise starship eza; do
		cat >"${sandbox}/bin/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${sandbox}/bin/${cmd}"
	done

	set +e
	output="$(
		HOME="${home}" \
			XDG_CONFIG_HOME="${home}/.config" \
			XDG_STATE_HOME="${home}/.local/state" \
			PATH="${sandbox}/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			ZSH_SETUP_FORCE_OS="darwin" \
			"${ROOT}/scripts/doctor.sh" 2>&1
	)"
	rc=$?
	set -e

	[[ ${rc} -ne 0 ]] || fail "expected doctor to fail when vivid and managed font file are missing"
	assert_contains "${output}" 'missing command: vivid'
	assert_contains "${output}" 'missing managed Nerd Font'
}

test_doctor_requires_managed_zshrc_marker() {
	local sandbox home rc output
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	mkdir -p \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/zsh/local" \
		"${home}/.local/bin" \
		"${home}/.local/state/zsh-setup/updates" \
		"${home}/.local/state/zsh-setup/backups" \
		"${sandbox}/bin"

	printf 'legacy-zshrc\n' >"${home}/.zshrc"
	printf 'managed-starship\n' >"${home}/.config/starship.toml"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"

	for cmd in zsh git chezmoi mise starship eza vivid; do
		cat >"${sandbox}/bin/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${sandbox}/bin/${cmd}"
	done

	set +e
	output="$(
		HOME="${home}" \
			XDG_CONFIG_HOME="${home}/.config" \
			XDG_STATE_HOME="${home}/.local/state" \
			PATH="${sandbox}/bin:$PATH" \
			"${ROOT}/scripts/doctor.sh" 2>&1
	)"
	rc=$?
	set -e

	[[ ${rc} -ne 0 ]] || fail "expected doctor to fail when the managed zshrc marker is missing"
	assert_contains "${output}" 'managed zshrc marker'
}

run_test "kube prompt marks prod context" test_kube_prompt_marks_prod_context
run_test "zsh integrations configure optional plugins in order" test_zsh_integrations_configure_optional_plugins_in_order
run_test "install-shell-deps keeps plugin fallback paths aligned" test_install_shell_deps_keeps_plugin_fallback_paths_aligned
run_test "bootstrap runs font install compinit repair and iterm setup" test_bootstrap_runs_font_install_compinit_repair_and_iterm_setup
run_test "bootstrap seeds global mise config from repo tools" test_bootstrap_seeds_global_mise_config_from_repo_tools
run_test "bootstrap preserves existing global mise config" test_bootstrap_preserves_existing_global_mise_config
run_test "install-nerd-font is idempotent in user font dir" test_install_nerd_font_is_idempotent_in_user_font_dir
run_test "fix-zsh-permissions removes group write from completion paths" test_fix_zsh_permissions_removes_group_write_from_completion_paths
run_test "prune-zsh-modules removes legacy files" test_prune_zsh_modules_removes_legacy_files
run_test "zsh runtime uses lazy mise activation" test_zsh_runtime_uses_lazy_mise_activation
run_test "zsh runtime exports LS_COLORS with vivid" test_zsh_runtime_exports_ls_colors_with_vivid
run_test "completion runtime handles insecure dirs without prompt" test_completion_runtime_handles_insecure_dirs_without_prompt
run_test "update check runtime refreshes once in background" test_update_check_runtime_refreshes_once_in_background
run_test "zsh history bindings search by prefix" test_zsh_history_bindings_search_by_prefix
run_test "zsh modules are consolidated to five files" test_zsh_modules_are_consolidated_to_five_files
run_test "migrate backs up files and copies secrets overlay" test_migrate_backs_up_files_and_copies_secrets_overlay
run_test "rollback restores latest backup and original files" test_rollback_restores_latest_backup_and_original_files
run_test "uninstall removes all zsh-setup directories and preserves local secrets" test_uninstall_removes_all_zsh_setup_directories_and_preserves_local_secrets
run_test "check-updates detects remote update" test_check_updates_detects_remote_update
run_test "check-updates reports up-to-date state" test_check_updates_reports_up_to_date
run_test "install-managed prompts before migrating existing config" test_install_managed_flow_prompts_before_migrating_existing_config
run_test "install-managed runs backup after confirmation" test_install_managed_flow_runs_backup_after_confirmation
run_test "install-managed removes stale targets before bootstrap" test_install_managed_flow_removes_stale_targets_before_bootstrap
run_test "install-managed skips prompt for managed state" test_install_managed_flow_skips_prompt_for_managed_state
run_test "install-managed treats partial state as unmanaged" test_install_managed_flow_treats_partial_state_as_unmanaged
run_test "bootstrap uses apply for local home source" test_bootstrap_uses_apply_for_local_home_source
run_test "repo mise tools define global seed without chezmoi or gh" test_repo_mise_tools_define_global_seed_without_chezmoi_or_gh
run_test "install supports standalone archive managed install" test_install_supports_standalone_archive_managed_install
run_test "install supports piped reinstall" test_install_supports_piped_reinstall
run_test "install prefers git clone when git is available" test_install_prefers_git_clone_when_git_is_available
run_test "check-updates uses installed repo without chezmoi source-path" test_check_updates_uses_installed_repo_without_chezmoi_source_path
run_test "raw rollback wrapper delegates to local script" test_raw_rollback_wrapper_delegates_to_local_script
run_test "raw uninstall wrapper delegates to local script" test_raw_uninstall_wrapper_delegates_to_local_script
run_test "sync refuses dirty source" test_sync_refuses_dirty_source
run_test "sync updates clean source" test_sync_updates_clean_source
run_test "sync uses installed repo without chezmoi source-path" test_sync_uses_installed_repo_without_chezmoi_source_path
run_test "sync fails when dependency alignment fails" test_sync_fails_when_dependency_alignment_fails
run_test "doctor requires vivid and managed font file" test_doctor_requires_vivid_and_managed_font_file
run_test "doctor requires managed zshrc marker" test_doctor_requires_managed_zshrc_marker
