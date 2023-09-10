# 1password cli completions
if can_haz op; then
  eval "$(op completion zsh)"
  compdef _op op
fi

# gh cli completions
if can_haz gh; then
  eval "$(gh completion -s zsh)"
  compdef _gh gh
fi

# akamai
source ./akamai.sh

# docker
source ./docker.sh
