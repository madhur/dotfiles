
# Get the aliases and functions
PATH="$HOME/.local/bin:$HOME/bin:$HOME/scripts:$HOME/company:/home/madhur/.gem/ruby/3.0.0/bin:$PATH"
export PATH
#eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

alias jssh="ssh -J jump "
alias jscp="scp -o 'ProxyJump jump'"

#source ~/.zshrc

### START-Keychain ###
# Let  re-use ssh-agent and/or gpg-agent between logins
if ! pgrep -x "ssh-agent" > /dev/null
then
    export HOST=$(hostname)
    source ~/company/passwords.env
    #/usr/bin/keychain --quiet --nogui $HOME/.ssh/id_rsa
    /home/madhur/scripts/keyring.sh
fi
source $HOME/.keychain/$HOST-sh

### End-Keychain ###


## SDK Man 
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
##
