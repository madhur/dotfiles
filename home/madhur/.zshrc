# zmodload zsh/datetime
# setopt PROMPT_SUBST
# PS4='+$EPOCHREALTIME %N:%i> '

# logfile=$(mktemp zsh_profile.XXXXXXXX)
# echo "Logging to $logfile"
# exec 3>&2 2>$logfile

# setopt XTRACE

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="madhur"

#autoload -Uz compinit
#compinit

plugins=(zsh-autosuggestions autojump autoswitch_virtualenv fzf-tab)

source $ZSH/oh-my-zsh.sh

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$HOME/scripts:$HOME/company:$PATH"
fi
PATH="$PATH:$HOME/maven/bin:$HOME/gradle/bin"
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
export SYSTEMD_PAGER=

# User specific aliases and functions
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

[ -z "$PS1" ] && return

export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH=$ANDROID_HOME/platform-tools/bin:$PATHexport PATH=$ANDROID_HOME/tools:$PATH
export PATH=$ANDROID_HOME/tools/bin:$PATHexport PATH=$ANDROID_HOME/build-tools/32.0.0:$PATH
export PATH=$ANDROID_HOME/build-tools/32.0.0/bin:$PATH

export KUBECONFIG=~/.kube/config:~/.kube/eks-pt:~/.kube/eks-prod

export PATH=$ANDROID_HOME/bundle-tool:$PATH

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

export NODE_ENV=development
export GLOBAL_AGENT_HTTP_PROXY=http://127.0.0.1:8888
export ZK_URL=localhost:2181
export startuser=100000
export incrementuser=10000
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin:$HOME/go/bin:$HOME/.cabal/bin"
export PATH=/usr/bin:$PATH:/usr/local/go/bin:$HOME/.cargo/bin
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/share/pkgconfig:/usr/share/wayland-protocols:/usr/local/include:/usr/local/include/libbamf3:/usr/local/share:/usr/local/share/vala/vapi

#[ -f "~/.ghcup/env" ] && source "~/.ghcup/env" # ghcup-env

export PATH=$HOME/etcd:/usr/local/vitess/bin:${PATH}
export _JAVA_AWT_WM_NONREPARENTING=1


export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig

[ -f "$HOME/company/passwords.env" ] && source ~/company/passwords.env

[[ -s /home/madhur/.autojump/etc/profile.d/autojump.sh ]] && source /home/madhur/.autojump/etc/profile.d/autojump.sh

#autoload -U compinit && compinit -u

eval "$(starship init zsh)"

# Import colorscheme from 'wal' asynchronously
# &   # Run the process in the background.
# ( ) # Hide shell job control messages.
# Not supported in the "fish" shell.
if [[ $TERM == "xterm-256color" ]]
then
(cat ~/.cache/wal/sequences &)
fi

source ~/.aliases
source ~/.functions

[ -f "/home/madhur/.ghcup/env" ] && source "/home/madhur/.ghcup/env" # ghcup-env

#export LANG="en_US.UTF-8"

# unsetopt XTRACE
# exec 2>&3 3>&-
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source /home/madhur/.gvm/scripts/gvm
export GOPATH="$GOPATH:/home/madhur/go"

#zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:default' menu yes select search
# all Tab widgets
zstyle ':autocomplete:*complete*:*' insert-unambiguous yes
#bindkey -M menuselect '\r' .accept-line


# place this after nvm initialization!
autoload -U add-zsh-hook

load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

add-zsh-hook chpwd load-nvmrc
load-nvmrc




# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

export EXA_COLORS="uu=0:gu=0"
eval "$(dircolors ~/.dir_colors)"
colorscript random