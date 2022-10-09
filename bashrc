source "$HOME/.dotfiles/bash/oh-my-bash.sh"

# add paths to PATH
source "$HOME/.dotfiles/bash/path.sh"

# Manage ssh agent and stuff
source "$HOME/.dotfiles/bash/ssh.sh"

# add some git stuff
source "$HOME/.dotfiles/bash/git.sh"

# Program-specific tweaks
source "$HOME/.dotfiles/bash/rust.sh"
source "$HOME/.dotfiles/bash/nvm.sh"

# Completion and keybindings
source "$HOME/.dotfiles/bash/completion.sh"
source "$HOME/.dotfiles/bash/keybinding.sh"

# User defined aliases
source "$HOME/.dotfiles/bash/aliases.sh"
. "$HOME/.cargo/env"

set -o vi
bind -m vi-command ".":insert-last-argument
bind -m vi-insert "\C-l.":clear-screen
bind -m vi-insert "\C-w.":backward-kill-word

[ -f "/home/taz/.ghcup/env" ] && source "/home/taz/.ghcup/env" # ghcup-env