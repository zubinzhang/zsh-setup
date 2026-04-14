# Migrate Clean Targets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove stale managed target files during migration so `chezmoi apply` no longer blocks on overwrite prompts.

**Architecture:** Keep migration flow unchanged except for one extra cleanup phase between backup/overlay seeding and bootstrap. Limit cleanup strictly to repo-managed target paths so local overlays and unrelated user files remain untouched.

**Tech Stack:** Bash, chezmoi, shell regression tests

---

### Task 1: Lock The Regression

**Files:**
- Modify: `tests/test_shell_env.sh`

- [ ] **Step 1: Write the failing test**

Add a test proving migration removes stale managed targets before bootstrap:

```bash
test_install_managed_flow_removes_stale_targets_before_bootstrap
```

- [ ] **Step 2: Run the test suite to verify red**

Run: `bash tests/run.sh`
Expected: the new test fails because legacy managed targets still exist when bootstrap runs.

### Task 2: Implement Target Cleanup

**Files:**
- Modify: `scripts/install-managed.sh`
- Modify: `scripts/lib/common.sh`

- [ ] **Step 1: Add a helper that removes only repo-managed target paths**

Implement cleanup for the managed zsh entrypoint, managed starship config, managed mise dir, managed zsh module dir, and managed wrapper binaries.

- [ ] **Step 2: Call the cleanup helper after backup succeeds and before bootstrap**

Keep backup and overlay seeding behavior unchanged.

- [ ] **Step 3: Run tests to verify green**

Run: `bash tests/run.sh`
Expected: migration no longer leaves stale managed targets in place.

### Task 3: Verify And Close

**Files:**
- None beyond previous files

- [ ] **Step 1: Run final verification**

Run:

```bash
bash tests/run.sh
bash -n install.sh rollback.sh uninstall.sh sync.sh scripts/*.sh scripts/lib/*.sh tests/*.sh tests/helpers/*.sh home/dot_local/bin/executable_zsh-setup-kube-prompt home/dot_local/bin/executable_zsh-setup-check-updates home/dot_local/bin/executable_zsh-setup-sync
PATH="$HOME/.local/share/mise/installs/chezmoi/latest:$PATH" bash scripts/ci-smoke-apply.sh
```

Expected: all commands succeed.
