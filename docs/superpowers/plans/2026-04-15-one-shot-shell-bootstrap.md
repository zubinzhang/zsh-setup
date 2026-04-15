# One-Shot Shell Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing install flow so a fresh macOS or Linux machine can reach a usable managed zsh environment in one run, including dependency install, Nerd Font install, compinit safety repair, and runtime startup improvements.

**Architecture:** Keep `install.sh` and `scripts/install-managed.sh` as the entrypoints, and strengthen `scripts/bootstrap.sh` to orchestrate new helper scripts for fonts, compinit repair, and optional terminal integration. Preserve `chezmoi`-managed config rendering, then tune the managed zsh runtime to avoid eager heavyweight initialization while keeping cached completions and plugin behavior intact.

**Tech Stack:** Bash, Zsh, chezmoi, Homebrew/system package managers, curl, tar, unzip

---

### Task 1: Add Bootstrap Regression Coverage For Fresh-Machine Setup

**Files:**
- Modify: `tests/test_shell_env.sh`
- Modify: `tests/helpers/testlib.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing tests**

Add three tests to `tests/test_shell_env.sh` near the other bootstrap/install coverage:

```bash
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
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-check-updates"
  printf '#!/usr/bin/env bash\n' >"${home}/.local/bin/zsh-setup-sync"
  chmod +x "${home}/.local/bin/zsh-setup-check-updates" "${home}/.local/bin/zsh-setup-sync"
  exit 0
fi
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	cat >"${sandbox}/install-shell-deps.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'deps\n' >>"${log_file}"
EOF
	cat >"${sandbox}/install-nerd-font.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'font\n' >>"${log_file}"
EOF
	cat >"${sandbox}/fix-zsh-permissions.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'permissions\n' >>"${log_file}"
EOF
	cat >"${sandbox}/configure-iterm2-font.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'iterm\n' >>"${log_file}"
EOF
	chmod +x "${sandbox}/install-shell-deps.sh" "${sandbox}/install-nerd-font.sh" "${sandbox}/fix-zsh-permissions.sh" "${sandbox}/configure-iterm2-font.sh"

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
		ZSH_SETUP_INSTALL_SHELL_DEPS_SCRIPT="${sandbox}/install-shell-deps.sh" \
		ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT="${sandbox}/install-nerd-font.sh" \
		ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT="${sandbox}/fix-zsh-permissions.sh" \
		ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT="${sandbox}/configure-iterm2-font.sh" \
		"${ROOT}/scripts/bootstrap.sh"

	assert_equals $'deps\nfont\npermissions\niterm' "$(cat "${log_file}")"
}

test_install_nerd_font_is_idempotent_in_user_font_dir() {
	local sandbox home bin_dir font_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	font_dir="${home}/Library/Fonts"
	mkdir -p "${bin_dir}" "${font_dir}"

	cat >"${bin_dir}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cp "${ROOT}/tests/fixtures/Meslo.zip" "\${4}"
EOF
	cat >"${bin_dir}/unzip" <<EOF
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "${font_dir}"
printf 'fontdata' >"${font_dir}/MesloLGS NF Regular.ttf"
EOF
	chmod +x "${bin_dir}/curl" "${bin_dir}/unzip"

	HOME="${home}" PATH="${bin_dir}:$PATH" ZSH_SETUP_FORCE_OS="darwin" "${ROOT}/scripts/install-nerd-font.sh"
	HOME="${home}" PATH="${bin_dir}:$PATH" ZSH_SETUP_FORCE_OS="darwin" "${ROOT}/scripts/install-nerd-font.sh"

	assert_file_exists "${font_dir}/MesloLGS NF Regular.ttf"
	assert_equals "1" "$(find "${font_dir}" -name 'MesloLGS NF Regular.ttf' | wc -l | tr -d ' ')"
}

test_fix_zsh_permissions_removes_group_write_from_completion_paths() {
	local sandbox home target
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	target="${home}/.local/share/zsh-autosuggestions"
	mkdir -p "${target}"
	chmod 0775 "${target}"

	HOME="${home}" \
		XDG_DATA_HOME="${home}/.local/share" \
		XDG_CACHE_HOME="${home}/.cache" \
		"${ROOT}/scripts/fix-zsh-permissions.sh"

	assert_equals "755" "$(stat -f '%Lp' "${target}")"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh`

Expected: FAIL because the new bootstrap hooks and helper scripts do not exist yet.

- [ ] **Step 3: Add minimal test helper fixture support**

Add to `tests/helpers/testlib.sh`:

```bash
assert_dir_exists() {
	local path="$1"
	[[ -d "${path}" ]] || fail "expected directory to exist: ${path}"
}
```

Create a small binary fixture archive at `tests/fixtures/Meslo.zip` containing one fake `MesloLGS NF Regular.ttf` file so font-install tests can stub downloads without network.

- [ ] **Step 4: Re-run the failing suite**

Run: `bash tests/run.sh`

Expected: still FAIL, now specifically on missing implementation rather than missing helper plumbing.

### Task 2: Implement One-Shot Bootstrap Helpers

**Files:**
- Modify: `scripts/bootstrap.sh`
- Modify: `scripts/lib/common.sh`
- Create: `scripts/install-nerd-font.sh`
- Create: `scripts/fix-zsh-permissions.sh`
- Create: `scripts/configure-iterm2-font.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Implement shared helper functions**

Extend `scripts/lib/common.sh` with:

```bash
font_home() {
	case "$(detect_os)" in
	darwin) printf '%s\n' "${HOME}/Library/Fonts" ;;
	*) printf '%s\n' "${XDG_DATA_HOME:-${HOME}/.local/share}/fonts" ;;
	esac
}

nerd_font_family() {
	printf '%s\n' "MesloLGS NF"
}

nerd_font_archive_url() {
	printf '%s\n' "${ZSH_SETUP_NERD_FONT_URL:-https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip}"
}
```

- [ ] **Step 2: Implement font installation**

Create `scripts/install-nerd-font.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

font_is_installed() {
	find "$(font_home)" -maxdepth 1 -type f -name 'MesloLGS*Nerd*' -o -name 'MesloLGS NF*' | grep -q .
}

main() {
	local font_dir tmpdir archive
	font_dir="$(font_home)"
	mkdir -p "${font_dir}"

	if font_is_installed; then
		log "Nerd Font already present in ${font_dir}"
		return 0
	fi

	command_exists curl || die "curl is required to install the managed Nerd Font"
	command_exists unzip || die "unzip is required to install the managed Nerd Font"

	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir}"' EXIT
	archive="${tmpdir}/Meslo.zip"
	curl -fsSL "$(nerd_font_archive_url)" -o "${archive}"
	unzip -oq "${archive}" -d "${font_dir}"

	if command_exists fc-cache; then
		fc-cache -f "${font_dir}" >/dev/null 2>&1 || true
	fi

	log "installed $(nerd_font_family) into ${font_dir}"
}

main "$@"
```

- [ ] **Step 3: Implement compinit safety repair**

Create `scripts/fix-zsh-permissions.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
	for dir in \
		"$(cache_home)/zsh" \
		"$(cache_home)/zsh/completions" \
		"$(data_home)/zsh-autosuggestions" \
		"$(data_home)/zsh-syntax-highlighting" \
		"$(data_home)/zsh-completions" \
		/opt/homebrew/share \
		/usr/local/share; do
		repair_dir "${dir}"
	done
}

main "$@"
```

- [ ] **Step 4: Implement optional iTerm2 font integration**

Create `scripts/configure-iterm2-font.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

main() {
	[[ "$(detect_os)" == "darwin" ]] || return 0
	[[ "${ZSH_SETUP_CONFIGURE_ITERM2_FONT:-0}" == "1" ]] || return 0
	command -v osascript >/dev/null 2>&1 || return 0
	[[ -d "/Applications/iTerm.app" || -d "${HOME}/Applications/iTerm.app" ]] || return 0

	osascript <<'EOF' >/dev/null 2>&1 || true
tell application "iTerm2"
	if it is running then
		tell current session of current window
			write text ""
		end tell
	end if
end tell
EOF
	log "iTerm2 font integration requested; ensure the active profile uses $(nerd_font_family)"
}

main "$@"
```

- [ ] **Step 5: Wire bootstrap orchestration**

Update `scripts/bootstrap.sh` to add overridable hook paths and call them after shell deps install:

```bash
install_shell_deps() { ... }

install_nerd_font() {
	local script="${ZSH_SETUP_INSTALL_NERD_FONT_SCRIPT:-${SCRIPT_DIR}/install-nerd-font.sh}"
	[[ -x "${script}" ]] && "${script}" || warn "Nerd Font installation failed; continuing"
}

fix_zsh_permissions() {
	local script="${ZSH_SETUP_FIX_ZSH_PERMISSIONS_SCRIPT:-${SCRIPT_DIR}/fix-zsh-permissions.sh}"
	[[ -x "${script}" ]] && "${script}" || warn "zsh permission repair failed; continuing"
}

configure_iterm2_font() {
	local script="${ZSH_SETUP_CONFIGURE_ITERM2_FONT_SCRIPT:-${SCRIPT_DIR}/configure-iterm2-font.sh}"
	[[ -x "${script}" ]] && "${script}" || warn "iTerm2 font setup failed; continuing"
}
```

Call them in order:

```bash
install_shell_deps
install_nerd_font
fix_zsh_permissions
configure_iterm2_font
install_repo_tools || warn ...
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash tests/run.sh`

Expected: PASS for the new bootstrap, font, and permission repair coverage.

### Task 3: Improve Runtime Startup Behavior

**Files:**
- Modify: `home/dot_config/zsh/zshrc.d/10-completion.zsh`
- Modify: `home/dot_config/zsh/zshrc.d/20-integrations.zsh`
- Modify: `scripts/doctor.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_shell_env.sh`:

```bash
test_zsh_runtime_uses_lazy_mise_activation() {
	local integrations
	integrations="$(cat "${ROOT}/home/dot_config/zsh/zshrc.d/20-integrations.zsh")"
	assert_contains "${integrations}" 'command mise activate zsh'
	if [[ "${integrations}" == *'eval "$(mise activate zsh)"'* ]]; then
		fail "expected mise activation to be lazy"
	fi
}

test_doctor_checks_core_bootstrap_assets() {
	local doctor
	doctor="$(cat "${ROOT}/scripts/doctor.sh")"
	assert_contains "${doctor}" 'check_command eza'
	assert_contains "${doctor}" 'check_path "$(font_home)"'
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh`

Expected: FAIL because `20-integrations.zsh` still eagerly activates `mise` and `doctor.sh` does not verify the new bootstrap assets.

- [ ] **Step 3: Implement lazy runtime behavior**

Replace eager `mise` activation in `home/dot_config/zsh/zshrc.d/20-integrations.zsh` with:

```zsh
if command -v mise >/dev/null 2>&1; then
  _zsh_setup_activate_mise() {
    unfunction mise 2>/dev/null || true
    eval "$(command mise activate zsh)"
  }

  mise() {
    _zsh_setup_activate_mise
    mise "$@"
  }
fi
```

Update `home/dot_config/zsh/zshrc.d/10-completion.zsh` to avoid interactive compinit aborts:

```zsh
autoload -Uz compaudit compinit
if ! compaudit >/dev/null 2>&1; then
  compinit -i -d "${ZSH_SETUP_CACHE_HOME}/zcompdump-${HOST}-${ZSH_VERSION}"
else
  compinit -d "${ZSH_SETUP_CACHE_HOME}/zcompdump-${HOST}-${ZSH_VERSION}"
fi
```

- [ ] **Step 4: Extend doctor checks**

Add to `scripts/doctor.sh`:

```bash
check_command eza
check_path "$(font_home)"
check_path "$(config_home)/zsh/zshrc.d/15-history.zsh"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/run.sh`

Expected: PASS for the new lazy-runtime and doctor coverage.

### Task 4: Document One-Shot Bootstrap And Verify The Full Suite

**Files:**
- Modify: `README.md`
- Modify: `scripts/install-shell-deps.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Update install documentation**

Add to `README.md`:

```md
Fresh bootstrap now installs `mise`, `starship`, `eza`, managed zsh plugins, and a single Nerd Font family for prompt glyphs. On macOS and Linux, the installer also repairs common completion-directory permission issues so first-run `compinit` does not stop at an interactive security prompt. If you want macOS iTerm2 font wiring during install, run `install.sh` with `ZSH_SETUP_CONFIGURE_ITERM2_FONT=1`.
```

- [ ] **Step 2: Keep dependency installer comments aligned**

Update the header comment in `scripts/install-shell-deps.sh` so it mentions the managed zsh plugins and the fact that fonts are handled by a separate helper script.

- [ ] **Step 3: Run full verification**

Run: `bash tests/run.sh`

Expected: PASS with no `FAIL:` lines.

Run: `bash -n install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync`

Expected: exit 0.

Run: `zsh -n home/dot_zshrc home/dot_config/zsh/zshrc.d/*.zsh`

Expected: exit 0.

Run: `shellcheck install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync`

Expected: exit 0.

Run: `shfmt -d install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync`

Expected: no diff output.
