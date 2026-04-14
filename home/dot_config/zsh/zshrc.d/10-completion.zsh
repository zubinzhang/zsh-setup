mkdir -p "${ZSH_SETUP_CACHE_HOME}" "${ZSH_SETUP_CACHE_HOME}/completions"
fpath=("${ZSH_SETUP_CACHE_HOME}/completions" $fpath)

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
