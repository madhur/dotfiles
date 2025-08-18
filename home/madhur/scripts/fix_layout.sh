# Reset the layout 
xrandr --output DP-0 --mode 3840x2160 --rotate left --left-of DP-2

sleep 1

xrandr --output DP-0 --scale 0.8x0.8      # Current scaling

sleep 1

~/.screenlayout/portrait-on-left.sh

# Restart awesomewm
echo 'awesome.restart()' | awesome-client

# Reset wallpaper
sleep 1

~/scripts/set_wallpaper.sh 
