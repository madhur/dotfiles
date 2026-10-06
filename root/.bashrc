
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

PATH=$PATH:/usr/local/bin

# User specific aliases and functions

export CLICOLOR=1

export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

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
alias ll="ls -ltrah"
alias la="ls -a"
alias grep='grep --color=auto'
alias k='kubectl'
alias duh='du --all --human-readable --one-file-system --max-depth=1 | sort -h'

eval "$(starship init bash)"

