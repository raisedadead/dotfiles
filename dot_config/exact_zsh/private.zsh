# You should not save any sensitive keys directly in this file, because it is stored in Git. Instead use https://www.doppler.com or https://1password.com for storing keys, and passwords.

#----------------------------
# Source 1Password Shell
#----------------------------
if [[ -f ~/.config/op/plugins.sh ]] && [[ "$OP_BETA_OK" = true ]]; then
  source ~/.config/op/plugins.sh
fi

