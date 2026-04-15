#!/usr/bin/env bash
# Install shell tool dependencies: fzf, eza, starship, and managed zsh plugins.
# The repo-managed Nerd Font is installed by scripts/install-nerd-font.sh.
# Strategy: brew (macOS/Linux) > system package manager > official install scripts / git clone

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
LOCAL_BIN="${HOME}/.local/bin"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_brew_install() {
	command_exists brew || return 1
	log "Installing $1 via Homebrew"
	brew install "$1"
}

_apt_install() {
	command_exists apt-get || return 1
	log "Installing $1 via apt-get"
	sudo apt-get install -y "$1"
}

_dnf_install() {
	command_exists dnf || return 1
	log "Installing $1 via dnf"
	sudo dnf install -y "$1"
}

_pacman_install() {
	command_exists pacman || return 1
	log "Installing $1 via pacman"
	sudo pacman -S --noconfirm "$1"
}

_sys_install() {
	local pkg="$1"
	local apt_pkg="${2:-$1}"
	_apt_install "$apt_pkg" || _dnf_install "$pkg" || _pacman_install "$pkg" || return 1
}

_git_clone_tool() {
	local name="$1"
	local url="$2"
	local dest="${DATA_HOME}/${name}"
	if [[ -d "$dest" ]]; then
		log "$name already cloned at $dest"
		return 0
	fi
	log "Cloning $name to $dest"
	git clone --depth 1 "$url" "$dest"
}

# ---------------------------------------------------------------------------
# Tool installers
# ---------------------------------------------------------------------------

install_fzf() {
	command_exists fzf && return 0
	log "Installing fzf..."
	_brew_install fzf && return 0
	_sys_install fzf && return 0
	# Fallback: clone + install binary to ~/.local/bin
	local fzf_dir="${DATA_HOME}/fzf"
	_git_clone_tool fzf https://github.com/junegunn/fzf.git
	mkdir -p "$LOCAL_BIN"
	bash "${fzf_dir}/install" --bin
	ln -sf "${fzf_dir}/bin/fzf" "${LOCAL_BIN}/fzf"
}

install_eza() {
	command_exists eza && return 0
	log "Installing eza..."
	_brew_install eza && return 0
	_sys_install eza && return 0
	# Fallback: download release binary to ~/.local/bin
	local os arch
	os="$(detect_os)"
	arch="$(uname -m)"
	case "$arch" in
	arm64 | aarch64) arch="aarch64" ;;
	*) arch="x86_64" ;;
	esac
	local tag
	tag="$(curl -fsSL https://api.github.com/repos/eza-community/eza/releases/latest |
		grep '"tag_name"' | head -1 | cut -d'"' -f4)"
	if [[ -z "$tag" ]]; then
		warn "eza: could not fetch latest release tag; skipping"
		return 0
	fi
	local tarball="eza_${arch}-unknown-linux-musl.tar.gz"
	if [[ "$os" == "darwin" ]]; then
		tarball="eza_${arch}-apple-darwin.tar.gz"
	fi
	local tmp
	tmp="$(mktemp -d)"
	curl -fsSL "https://github.com/eza-community/eza/releases/download/${tag}/${tarball}" |
		tar -xz -C "$tmp"
	mkdir -p "$LOCAL_BIN"
	mv "$tmp/eza" "${LOCAL_BIN}/eza"
	rm -rf "$tmp"
	log "eza installed to ${LOCAL_BIN}/eza"
}

install_starship() {
	command_exists starship && return 0
	log "Installing starship..."
	_brew_install starship && return 0
	_sys_install starship && return 0
	# Fallback: official install script
	if command_exists curl; then
		mkdir -p "$LOCAL_BIN"
		curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN"
		return 0
	fi
	warn "starship: could not install; prompt may be unavailable"
}

install_vivid() {
	command_exists vivid && return 0
	log "Installing vivid..."
	_brew_install vivid && return 0
	_sys_install vivid && return 0
	local os arch tag tarball tmp version
	os="$(detect_os)"
	arch="$(uname -m)"
	case "$arch" in
	arm64 | aarch64) arch="aarch64" ;;
	*) arch="x86_64" ;;
	esac
	tag="$(curl -fsSL https://api.github.com/repos/sharkdp/vivid/releases/latest |
		grep '"tag_name"' | head -1 | cut -d'"' -f4)"
	if [[ -z "$tag" ]]; then
		warn "vivid: could not fetch latest release tag; skipping"
		return 0
	fi
	version="${tag#v}"
	tarball="vivid-${tag}-${arch}-unknown-linux-musl.tar.gz"
	if [[ "$os" == "darwin" ]]; then
		tarball="vivid-${tag}-${arch}-apple-darwin.tar.gz"
	fi
	tmp="$(mktemp -d)"
	curl -fsSL "https://github.com/sharkdp/vivid/releases/download/${tag}/${tarball}" |
		tar -xz -C "$tmp"
	mkdir -p "$LOCAL_BIN"
	mv "$tmp/vivid" "${LOCAL_BIN}/vivid"
	rm -rf "$tmp"
	log "vivid ${version} installed to ${LOCAL_BIN}/vivid"
}

install_zsh_autosuggestions() {
	# Already installed if sourced by any of the known paths
	for _p in \
		/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
		/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
		/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
		"${DATA_HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
		[[ -f "$_p" ]] && return 0
	done
	log "Installing zsh-autosuggestions..."
	_brew_install zsh-autosuggestions && return 0
	_sys_install zsh-autosuggestions && return 0
	_git_clone_tool zsh-autosuggestions \
		https://github.com/zsh-users/zsh-autosuggestions.git
}

install_zsh_syntax_highlighting() {
	for _p in \
		/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
		/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
		/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
		"${DATA_HOME}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
		[[ -f "$_p" ]] && return 0
	done
	log "Installing zsh-syntax-highlighting..."
	_brew_install zsh-syntax-highlighting && return 0
	_sys_install zsh-syntax-highlighting && return 0
	_git_clone_tool zsh-syntax-highlighting \
		https://github.com/zsh-users/zsh-syntax-highlighting.git
}

install_zsh_completions() {
	for _d in \
		/opt/homebrew/share/zsh-completions \
		/usr/local/share/zsh-completions \
		/usr/share/zsh/vendor-completions \
		"${DATA_HOME}/zsh-completions"; do
		[[ -d "$_d" ]] && return 0
	done
	log "Installing zsh-completions..."
	_brew_install zsh-completions && return 0
	_sys_install zsh-completions && return 0
	_git_clone_tool zsh-completions \
		https://github.com/zsh-users/zsh-completions.git
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
	install_fzf || warn "fzf installation failed; skipping"
	install_eza || warn "eza installation failed; skipping"
	install_starship || warn "starship installation failed; skipping"
	install_vivid || warn "vivid installation failed; skipping"
	install_zsh_autosuggestions || warn "zsh-autosuggestions installation failed; skipping"
	install_zsh_syntax_highlighting || warn "zsh-syntax-highlighting installation failed; skipping"
	install_zsh_completions || warn "zsh-completions installation failed; skipping"
	log "Shell dependency installation complete."
}

main "$@"
