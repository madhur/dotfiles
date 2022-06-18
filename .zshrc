export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="madhur"

autoload -Uz compinit
compinit

#source <(kubectl completion zsh)
plugins=(git zsh-syntax-highlighting zsh-autosuggestions autojump kubectl zsh-kubectl-prompt)

source $ZSH/oh-my-zsh.sh

source ~/kube-ps1.sh

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
PATH="$PATH:$HOME/maven/bin:$HOME/gradle/bin"
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
export SYSTEMD_PAGER=

# User specific aliases and functions

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

[ -z "$PS1" ] && return

KUBE_PS1_CTX_COLOR=yellow
KUBE_PS1_NS_COLOR=yellow

export CLICOLOR=1

export LSCOLORS=GxFxCxDxBxegedabagaced

alias gs='git status '
alias ga='git add .'
alias gb='git branch '
alias gc='git commit'
alias gma='git commit -am'
alias gd='git diff'
alias gp='git push'
alias gco='git checkout '
alias gk='gitk --all&'
alias gx='gitx --all'
alias ac='ac = !git add . && git commit -am'
alias acp='ac = !git add . && git commit -am "updated" && git push'
alias gp='git pull'
alias gst='git stash'
alias gcom='git checkout master'
alias gcor='git checkout release'
alias gl='git log'
alias glg='git log --graph --oneline --decorate --all'
alias gld='git log --pretty=format:"%h %ad %s" --date=short --all'
alias gst='git stash'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gstd='git stash drop'
alias gcl='git clone'
alias gpp='git pull && git push'
alias got='git '
alias get='git '
alias gpom='git pull origin master'
alias gpor='git pull origin release'
alias gfom='git fetch upstream master'
alias gfp='git fetch upstream master && git push'
alias gpum='git pull upstream master'
alias gpur='git pull upstream release'

alias fmvn='mvn clean package -DskipTests -Dspotbugs.skip=true -Dcheckstyle.skip=true -Djacoco.skip=true'

alias gbo='gradle bootrun'
alias gbi='gradle build install'
alias gcbi='gradle clean build install'
alias gb='gradle build'
alias gc='gradle clean'
alias gi='gradle install'

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ll="ls -lah"
alias la="ls -a"
alias grep='grep --color=auto'
alias k='kubectl'

alias prettyjson='python -m json.tool'

function perf {
  curl -o /dev/null -s -w "%{time_connect} + %{time_starttransfer} = %{time_total}\n" "$1"
}

extract () {
   if [ -f $1 ] ; then
       case $1 in
           *.tar.bz2)   tar xvjf $1    ;;
           *.tar.gz)    tar xvzf $1    ;;
           *.bz2)       bunzip2 $1     ;;
           *.rar)       unrar x $1       ;;
           *.gz)        gunzip $1      ;;
           *.tar)       tar xvf $1     ;;
           *.tbz2)      tar xvjf $1    ;;
           *.tgz)       tar xvzf $1    ;;
           *.zip)       unzip $1       ;;
           *.Z)         uncompress $1  ;;
           *.7z)        7z x $1        ;;
           *)           echo "don't know how to extract '$1'..." ;;
       esac
   else
       echo "'$1' is not a valid file!"
   fi
 }
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

function java11() {
sdk use java 11.0.12-open
 
}

function java8() {
  sdk use java 8.0.302-open
}

export ANDROID_HOME=/home/madhur/Android/Sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH=$ANDROID_HOME/platform-tools/bin:$PATHexport PATH=$ANDROID_HOME/tools:$PATH
export PATH=$ANDROID_HOME/tools/bin:$PATHexport PATH=$ANDROID_HOME/build-tools/32.0.0:$PATH
export PATH=$ANDROID_HOME/build-tools/32.0.0/bin:$PATH

export KUBECONFIG=~/.kube/config:~/.kube/eks-pt:~/.kube/eks-prod

export PATH=$ANDROID_HOME/bundle-tool:$PATH

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
RPROMPT='%{$fg[blue]%} (%T) ($ZSH_KUBECTL_PROMPT)%{$reset_color%}'

export NODE_ENV=development
export GLOBAL_AGENT_HTTP_PROXY=http://127.0.0.1:8888
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
export PATH=/usr/bin:$PATH:/usr/local/go/bin:/home/madhur/.cargo/bin
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/share/pkgconfig:/usr/share/wayland-protocols:/usr/local/include:/usr/local/include/libbamf3:/usr/local/share:/usr/local/share/vala/vapi

# handle ssh - agent and ssh-add
export $(gnome-keyring-daemon --daemonize --start)

alias jssh="ssh -J jump "
alias jscp="scp -o 'ProxyJump jump'"

[ -f "/home/madhur/.ghcup/env" ] && source "/home/madhur/.ghcup/env" # ghcup-env

export PATH=/home/madhur/etcd:/usr/local/vitess/bin:${PATH}
export _JAVA_AWT_WM_NONREPARENTING=1