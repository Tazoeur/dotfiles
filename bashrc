source "$HOME/.dotfiles/bash/oh-my-bash.sh"

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-bash libs,
# plugins, and themes. Aliases can be placed here, though oh-my-bash
# users are encouraged to define aliases within the OSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias bashconfig="mate ~/.bashrc"
# alias ohmybash="mate ~/.oh-my-bash"

# add paths to PATH
source "$HOME/.dotfiles/bash/path.sh"

source "$HOME/.dotfiles/bash/ssh.sh"
source "$HOME/.dotfiles/bash/rust.sh"
source "$HOME/.dotfiles/bash/nvm.sh"

source "$HOME/.dotfiles/bash/completion.sh"
source "$HOME/.dotfiles/bash/keybinding.sh"

source "$HOME/.dotfiles/bash/aliases.sh"
