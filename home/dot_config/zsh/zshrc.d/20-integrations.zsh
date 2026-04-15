[[ -r "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# zsh-autosuggestions
for _f in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  [[ -f "$_f" ]] && { source "$_f"; break; }
done

# zsh-syntax-highlighting (must be sourced after zsh-autosuggestions)
for _f in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [[ -f "$_f" ]] && { source "$_f"; break; }
done
unset _f

# fzf — fuzzy completion and key bindings (Ctrl+R, Ctrl+T, Alt+C)
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi
