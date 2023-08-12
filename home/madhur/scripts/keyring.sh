#!/usr/bin/expect -f

set timeout 5
set keypass "$env(SSH_KEY_PASSWORD)"
set home "$env(HOME)"
set host "$env(HOST)"

spawn /usr/bin/keychain --quiet --nogui $home/.ssh/id_rsa
expect "Enter passphrase"
send "$keypass\r"
interact
