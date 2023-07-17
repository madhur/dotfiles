tmux new-session -s config-portal -n config-dashboard -d
tmux send-keys -t config-portal 'cd /home/madhur/github/config-portal-dashboard' C-m
tmux send-keys -t config-portal 'yarn start' C-m

tmux new-window -n multilang -t config-portal
tmux send-keys -t config-portal:2 'cd /home/madhur/github/multilang-admin-portal' C-m
tmux send-keys -t config-portal:2 'npm run dev' C-m

tmux new-window -n reverie-admin-ui -t config-portal
tmux send-keys -t config-portal:3 'cd /home/madhur/github/reverie-admin-portal' C-m
tmux send-keys -t config-portal:3 'yarn start' C-m

tmux new-window -n reverie-customer-portal -t config-portal
tmux send-keys -t config-portal:4 'cd /home/madhur/github/reverie-customer-portal' C-m
tmux send-keys -t config-portal:4 'yarn start' C-m

tmux attach -t config-portal