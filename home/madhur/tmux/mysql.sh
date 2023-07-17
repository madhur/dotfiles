tmux new-session -s mysql -d
tmux send-keys -t mysql '/home/madhur/bin/mysql.sh' C-m
tmux attach -t mysql