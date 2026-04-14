for file in "${ZSH_SETUP_CONFIG_HOME}"/local/*.zsh(.N); do
  source "${file}"
done
