# Reset the layout 
xrandr --output DP-0 --mode 3072x1728 --rotate left --left-of DP-2

sleep 1

# # Current scaling

sleep 1

~/.screenlayout/portrait-on-left.sh

# Restart awesomewm
echo 'awesome.restart()' | awesome-client

# Reset wallpaper
sleep 1

~/scripts/set_wallpaper.sh 
