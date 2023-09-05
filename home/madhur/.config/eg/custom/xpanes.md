Ssh into vagrant
    xpanes -t -c 'vagrant ssh vttablet{}' 1 2 3

A mini multiple websocket connector
    xpanes -t -c 'wscat -c ws://localhost:8080' 1 2 3 4 5 6 7 8 9

SSh into multiple hosts
    xpanes  -t -c 'ssh vagrant@{}' 192.168.56.21 192.168.56.22 192.168.56.23 192.168.56.24 192.168.56.25

SSH into multiple hosts
    xpanes  -t -c 'prod {}' 10.200.102.132 10.200.105.7

Generate sequences
    xpanes -c 'seq {}' 1 2 3 4

Simple multiple ssh
     xpanes -t -c 'ssh {}' 10.24.196.97 10.24.196.97

Run multiple monitor
    xpanes  -e "top" "vmstat 1" "watch -n 1 df"
