# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi


# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$HOME/scripts:$PATH"
fi
PATH="$PATH:$HOME/maven/bin:$HOME/gradle/bin"
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
export SYSTEMD_PAGER=

# User specific aliases and functions

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

export CLICOLOR=1

export LSCOLORS=GxFxCxDxBxegedabagaced


# HSTR configuration - add this to ~/.bashrc
alias hh=hstr                    # hh to be alias for hstr
export HSTR_CONFIG=hicolor       # get more colors
shopt -s histappend              # append new history items to .bash_history
export HISTCONTROL=ignorespace   # leading space hides commands from history
export HISTFILESIZE=10000        # increase history file size (default is 500)
export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)
# ensure synchronization between bash memory and history file
export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
# if this is interactive shell, then bind hstr to Ctrl-r (for Vi mode check doc)
if [[ $- =~ .*i.* ]]; then bind '"\C-r": "\C-a hstr -- \C-j"'; fi
# if this is interactive shell, then bind 'kill last command' to Ctrl-x k
if [[ $- =~ .*i.* ]]; then bind '"\C-xk": "\C-a hstr -k \C-j"'; fi


# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"



export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH=$ANDROID_HOME/platform-tools/bin:$PATHexport PATH=$ANDROID_HOME/tools:$PATH
export PATH=$ANDROID_HOME/tools/bin:$PATHexport PATH=$ANDROID_HOME/build-tools/32.0.0:$PATH
export PATH=$ANDROID_HOME/build-tools/32.0.0/bin:$PATH
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

export KUBECONFIG=~/.kube/config:~/.kube/eks-pt
export PATH=$ANDROID_HOME/bundle-tool:$PATH
export KUBECONFIG=~/.kube/config:~/.kube/eks-pt
export PATH=$ANDROID_HOME/bundle-tool:$PATH

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
#RPROMPT='%{$fg[blue]%}($ZSH_KUBECTL_PROMPT)%{$reset_color%}'

export NODE_ENV=development
export GLOBAL_AGENT_HTTP_PROXY=http://127.0.0.1:8888
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
export PATH=/usr/bin:$PATH:/usr/local/go/bin:$HOME/.cargo/bin


export PATH=$HOME/etcd:/usr/local/vitess/bin:${PATH}


#eval "$(starship init bash)"

source ~/.aliases
source ~/.functions

[[ -s "/home/madhur/.gvm/scripts/gvm" ]] && source "/home/madhur/.gvm/scripts/gvm"

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"
