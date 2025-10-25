# Reset the layout 
#xrandr --output DP-0 --mode 1728x3072 --rotate left --left-of DP-2
# xrandr --output DP-0 --mode 3840x2160 --rotate left --left-of DP-2
# sleep 2
# #xrandr --output DP-2 --mode 3072x1728 
# xrandr --output DP-2 --mode 3840x2160

# # # Current scaling

# sleep 1

# #~/.screenlayout/portrait-on-left.sh

# # Restart awesomewm
# echo 'awesome.restart()' | awesome-client

# # Reset wallpaper
# sleep 1

~/.screenlayout/portrait-on-right.sh

sleep 2

~/scripts/set_wallpaper.sh 

~/.config/conky/launch.sh --all