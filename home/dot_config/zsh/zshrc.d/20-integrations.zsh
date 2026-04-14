[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
