# Global Mise Seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seed `~/.config/mise/config.toml` from the repo root `mise.toml` on first install only, so `mise`-managed tools resolve globally after install without overwriting later user edits.

**Architecture:** Move global `mise` config creation out of the chezmoi `run_onchange` hook and into bootstrap. Bootstrap will read the repo root `mise.toml`, copy only the `[tools]` table into `~/.config/mise/config.toml` when the target file does not exist, then continue with the existing `mise install` step for repo-local installs.

**Tech Stack:** Bash, chezmoi bootstrap flow, `mise`, shell regression tests

---

### Task 1: Lock The New Behavior With Failing Tests

**Files:**
- Modify: `tests/test_shell_env.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing bootstrap seed test**

Add a new test near the existing bootstrap tests that exercises a fresh bootstrap with no pre-existing `~/.config/mise/config.toml`:

```bash
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
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git eza; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
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
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
bash tests/run.sh "bootstrap seeds global mise config from repo tools"
```

Expected: FAIL because bootstrap does not currently create `~/.config/mise/config.toml` from the repo root `mise.toml`.

- [ ] **Step 3: Write the non-overwrite regression test**

Add a second test showing bootstrap preserves an existing user config:

```bash
test_bootstrap_preserves_existing_global_mise_config() {
	local sandbox home bin_dir
	sandbox="$(mk_test_tmpdir)"
	home="${sandbox}/home"
	bin_dir="${sandbox}/bin"
	mkdir -p "${home}/.config/mise" "${home}" "${bin_dir}"

	printf '[tools]\nnode = "20.19.5"\n' >"${home}/.config/mise/config.toml"

	cat >"${bin_dir}/chezmoi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$1" == "apply" ]]; then
  mkdir -p "${home}/.config/zsh/zshrc.d" "${home}/.config/zsh/local" "${home}/.local/bin" "${home}/.local/state/zsh-setup/updates" "${home}/.local/state/zsh-setup/backups"
  printf '# zsh entrypoint managed by chezmoi\n' >"${home}/.zshrc"
  exit 0
fi
printf 'unexpected chezmoi args: %s\n' "\$*" >&2
exit 1
EOF
	chmod +x "${bin_dir}/chezmoi"

	for cmd in mise starship zsh git eza; do
		cat >"${bin_dir}/${cmd}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
		chmod +x "${bin_dir}/${cmd}"
	done

	HOME="${home}" \
		XDG_CONFIG_HOME="${home}/.config" \
		XDG_STATE_HOME="${home}/.local/state" \
		PATH="${bin_dir}:$PATH" \
		"${ROOT}/scripts/bootstrap.sh"

	assert_equals $'[tools]\nnode = "20.19.5"' "$(cat "${home}/.config/mise/config.toml")"
}
```

- [ ] **Step 4: Run the second test to verify it fails or is unimplemented**

Run:

```bash
bash tests/run.sh "bootstrap preserves existing global mise config"
```

Expected: FAIL only if the implementation incorrectly overwrites the file during development. If it passes immediately, keep it as a guard and continue with the first failing test as the driving test.

- [ ] **Step 5: Replace the old source-structure test with the new seed-source assertion**

Update the existing `test_managed_mise_config_excludes_chezmoi_and_gh()` so it no longer checks the deleted `run_onchange` file. Instead, assert that the repo root `mise.toml` is the seed source and still excludes `chezmoi` and `gh`:

```bash
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
}
```

- [ ] **Step 6: Run the targeted test set**

Run:

```bash
bash tests/run.sh "bootstrap seeds global mise config from repo tools" \
  "bootstrap preserves existing global mise config" \
  "repo mise tools define global seed without chezmoi or gh"
```

Expected: At least the new bootstrap seed test fails before implementation.

### Task 2: Implement First-Install Global Mise Seeding

**Files:**
- Modify: `scripts/bootstrap.sh`
- Modify: `scripts/lib/common.sh`
- Delete: `home/run_onchange_before_setup-mise-config.sh`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Add path helpers for the global mise config and repo seed source**

Add small helpers to `scripts/lib/common.sh` so bootstrap does not hardcode these paths:

```bash
mise_config_dir() {
	printf '%s\n' "$(config_home)/mise"
}

mise_config_file() {
	printf '%s\n' "$(mise_config_dir)/config.toml"
}

repo_mise_config_file() {
	printf '%s\n' "${ZSH_SETUP_REPO_ROOT}/mise.toml"
}
```

- [ ] **Step 2: Add a bootstrap helper that seeds the file only when missing**

Add a focused function to `scripts/bootstrap.sh`:

```bash
seed_global_mise_config() {
	local source_file target_file
	source_file="$(repo_mise_config_file)"
	target_file="$(mise_config_file)"

	[[ -f "${source_file}" ]] || return 0
	[[ -f "${target_file}" ]] && return 0

	mkdir -p "$(dirname "${target_file}")"
	cp "${source_file}" "${target_file}"
}
```

This intentionally copies the repo root `mise.toml` as-is, preserving the exact `[tools]` versions declared by the repo.

- [ ] **Step 3: Call the seed helper in bootstrap before `mise install`**

In `main()` inside `scripts/bootstrap.sh`, insert the new seed step after `install_mise` and before `install_repo_tools`:

```bash
	install_mise
	seed_global_mise_config
	install_shell_deps
	install_nerd_font
```

If you prefer tighter sequencing with `mise install`, this is also acceptable:

```bash
	install_mise
	seed_global_mise_config
	install_repo_tools || warn "mise install failed; continuing with rendered dotfiles"
```

Use the first form only if it keeps the existing dependency installation ordering intact. The key constraint is that seeding must happen before bootstrap exits, and it must not overwrite an existing file.

- [ ] **Step 4: Delete the chezmoi `run_onchange` writer**

Remove `home/run_onchange_before_setup-mise-config.sh` entirely so later `chezmoi apply` runs do not keep rewriting `~/.config/mise/config.toml`.

- [ ] **Step 5: Run the targeted tests to verify the new behavior**

Run:

```bash
bash tests/run.sh "bootstrap seeds global mise config from repo tools" \
  "bootstrap preserves existing global mise config" \
  "repo mise tools define global seed without chezmoi or gh"
```

Expected: PASS for all three named tests.

### Task 3: Update Docs And Run Repository Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-04-15-global-mise-seed-design.md`
- Test: `tests/test_shell_env.sh`

- [ ] **Step 1: Update README wording so install behavior matches reality**

Adjust the bootstrap description in `README.md` to reflect the new first-install global seeding behavior. Update the runtime section so it does not claim that only `starship`, `kubectl`, and `helm` are managed globally.

Use wording like:

```markdown
Bootstrap installs `chezmoi` itself. On first install, bootstrap also seeds `~/.config/mise/config.toml` from the repository `mise.toml` so the managed toolset is available globally. Later user edits to that file are preserved.
```

- [ ] **Step 2: Update the spec if needed to reflect implementation details**

If the final implementation copied the entire repo `mise.toml` instead of extracting only `[tools]`, update the design doc to say that explicitly so the written design matches code.

- [ ] **Step 3: Run the focused shell test suite**

Run:

```bash
bash tests/run.sh
```

Expected: PASS with all shell regression tests green.

- [ ] **Step 4: Run syntax verification**

Run:

```bash
mise run syntax
```

Expected: PASS with no Bash or zsh syntax errors.

- [ ] **Step 5: Run lint verification**

Run:

```bash
mise run lint
```

Expected: PASS with no `shellcheck` or `shfmt -d` failures.

- [ ] **Step 6: Commit**

```bash
git add README.md scripts/bootstrap.sh scripts/lib/common.sh tests/test_shell_env.sh docs/superpowers/specs/2026-04-15-global-mise-seed-design.md docs/superpowers/plans/2026-04-15-global-mise-seed.md
git rm home/run_onchange_before_setup-mise-config.sh
git commit -m "feat: seed global mise config on install"
```
