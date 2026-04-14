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

test_uninstall_removes_managed_files_and_preserves_local_overlay() {
	local sandbox home overlay_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	overlay_dir="${home}/.config/zsh/local"
	mkdir -p \
		"${overlay_dir}" \
		"${home}/.config/zsh/zshrc.d" \
		"${home}/.config/mise" \
		"${home}/.local/bin" \
		"${home}/Library/LaunchAgents"

	printf 'managed\n' >"${home}/.zshrc"
	printf 'managed-starship\n' >"${home}/.config/starship.toml"
	printf 'export PRIVATE=1\n' >"${overlay_dir}/secrets.zsh"
	printf 'echo managed\n' >"${home}/.config/zsh/zshrc.d/10-managed.zsh"
	printf 'managed-mise\n' >"${home}/.config/mise/config.toml"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-kube-prompt"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
	printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
	printf 'plist\n' >"${home}/Library/LaunchAgents/com.zubin.zsh-setup.sync.plist"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		ZSH_SETUP_FORCE_OS="darwin" \
		"${ROOT}/scripts/uninstall.sh"

	assert_not_exists "${home}/.zshrc"
	assert_not_exists "${home}/.config/starship.toml"
	assert_not_exists "${home}/.config/zsh/zshrc.d"
	assert_not_exists "${home}/.config/mise"
	assert_file_exists "${overlay_dir}/secrets.zsh"
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
if [[ "\$1" == "apply" && "\$2" == "--source=${ROOT}/home" ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  printf 'managed-starship\n' >"${home}/.config/starship.toml"
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

	PATH="${bin_dir}:$PATH" HOME="${home}" XDG_CONFIG_HOME="${home}/.config" XDG_STATE_HOME="${home}/.local/state" "${ROOT}/scripts/bootstrap.sh"

	assert_contains "$(cat "${log_file}")" "apply --source=${ROOT}/home"
	if grep -Fq 'init --apply' "${log_file}"; then
		fail "expected bootstrap to use chezmoi apply for the local home source"
	fi
}

test_managed_mise_config_excludes_chezmoi_and_gh() {
	local config
	config="$(cat "${ROOT}/home/dot_config/mise/config.toml")"
	if [[ "${config}" == *'chezmoi'* ]]; then
		fail "expected managed mise config to exclude chezmoi"
	fi
	if [[ "${config}" == *$'\ngh = '* || "${config}" == *$'\r\ngh = '* ]]; then
		fail "expected managed mise config to exclude gh"
	fi
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
	local sandbox bin_dir install_home home
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
if [[ "\$1" == "apply" && "\$2" == "--source=${install_home}/home" ]]; then
  touch "${sandbox}/update-ran"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	HOME="${home}" ZSH_SETUP_HOME="${install_home}" PATH="${bin_dir}:$PATH" "${ROOT}/scripts/sync.sh"

	assert_file_exists "${sandbox}/update-ran"
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
elif [[ "\$1" == "apply" && "\$2" == "--source=${install_home}/home" ]]; then
  touch "${sandbox}/apply-ran"
else
  printf 'unexpected chezmoi args: %s\n' "\$*" >&2
  exit 1
fi
EOF
	chmod +x "${bin_dir}/chezmoi"

	HOME="${home}" \
		ZSH_SETUP_HOME="${install_home}" \
		PATH="${bin_dir}:$PATH" \
		"${ROOT}/scripts/sync.sh"

	assert_file_exists "${sandbox}/apply-ran"
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

	for cmd in zsh git chezmoi mise starship; do
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
run_test "migrate backs up files and copies secrets overlay" test_migrate_backs_up_files_and_copies_secrets_overlay
run_test "rollback restores latest backup and original files" test_rollback_restores_latest_backup_and_original_files
run_test "uninstall removes managed files and preserves local overlay" test_uninstall_removes_managed_files_and_preserves_local_overlay
run_test "check-updates detects remote update" test_check_updates_detects_remote_update
run_test "check-updates reports up-to-date state" test_check_updates_reports_up_to_date
run_test "install-managed prompts before migrating existing config" test_install_managed_flow_prompts_before_migrating_existing_config
run_test "install-managed runs backup after confirmation" test_install_managed_flow_runs_backup_after_confirmation
run_test "install-managed removes stale targets before bootstrap" test_install_managed_flow_removes_stale_targets_before_bootstrap
run_test "install-managed skips prompt for managed state" test_install_managed_flow_skips_prompt_for_managed_state
run_test "install-managed treats partial state as unmanaged" test_install_managed_flow_treats_partial_state_as_unmanaged
run_test "bootstrap uses apply for local home source" test_bootstrap_uses_apply_for_local_home_source
run_test "managed mise config excludes chezmoi and gh" test_managed_mise_config_excludes_chezmoi_and_gh
run_test "install supports standalone archive managed install" test_install_supports_standalone_archive_managed_install
run_test "install supports piped reinstall" test_install_supports_piped_reinstall
run_test "install prefers git clone when git is available" test_install_prefers_git_clone_when_git_is_available
run_test "check-updates uses installed repo without chezmoi source-path" test_check_updates_uses_installed_repo_without_chezmoi_source_path
run_test "raw rollback wrapper delegates to local script" test_raw_rollback_wrapper_delegates_to_local_script
run_test "raw uninstall wrapper delegates to local script" test_raw_uninstall_wrapper_delegates_to_local_script
run_test "sync refuses dirty source" test_sync_refuses_dirty_source
run_test "sync updates clean source" test_sync_updates_clean_source
run_test "sync uses installed repo without chezmoi source-path" test_sync_uses_installed_repo_without_chezmoi_source_path
run_test "doctor requires managed zshrc marker" test_doctor_requires_managed_zshrc_marker
