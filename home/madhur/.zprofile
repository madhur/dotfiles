
# Get the aliases and functions
PATH="$HOME/.local/bin:$HOME/bin:$HOME/scripts:$PATH"
export PATH
#eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

alias jssh="ssh -J jump "
alias jscp="scp -o 'ProxyJump jump'"



### START-Keychain ###
# Let  re-use ssh-agent and/or gpg-agent between logins
/usr/bin/keychain --nogui $HOME/.ssh/id_rsa
source $HOME/.keychain/$HOST-sh
### End-Keychain ###
