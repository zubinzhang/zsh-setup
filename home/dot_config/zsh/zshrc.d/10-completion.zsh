mkdir -p "${ZSH_SETUP_CACHE_HOME}" "${ZSH_SETUP_CACHE_HOME}/completions"
fpath=("${ZSH_SETUP_CACHE_HOME}/completions" $fpath)

# zsh-completions (must be added to fpath before compinit)
for _d in \
  /opt/homebrew/share/zsh-completions \
  /usr/local/share/zsh-completions \
  /usr/share/zsh/vendor-completions \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-completions/src"; do
  [[ -d "$_d" ]] && fpath=("$_d" $fpath)
done
unset _d

autoload -Uz compinit
compinit -d "${ZSH_SETUP_CACHE_HOME}/zcompdump-${HOST}-${ZSH_VERSION}"

if command -v kubectl >/dev/null 2>&1; then
  [[ -f "${ZSH_SETUP_CACHE_HOME}/completions/_kubectl" ]] || \
    kubectl completion zsh > "${ZSH_SETUP_CACHE_HOME}/completions/_kubectl"
fi

if command -v helm >/dev/null 2>&1; then
  [[ -f "${ZSH_SETUP_CACHE_HOME}/completions/_helm" ]] || \
    helm completion zsh > "${ZSH_SETUP_CACHE_HOME}/completions/_helm"
fi
