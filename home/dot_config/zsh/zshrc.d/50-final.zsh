for file in "${ZSH_SETUP_CONFIG_HOME}"/local/*.zsh(.N); do
  source "${file}"
done

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
