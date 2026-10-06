# A Dynamic Wallpaper Module

## Change wallpaper based on time.

![workflow](https://github.com/manilarome/awesome-glorious-widgets/blob/master/dynamic-wallpaper/workflow.gif)

## Instructions:  

+ Clone the repo to your configuration

```bash
git clone --depth=1 https://github.com/manilarome/awesome-glorious-widgets ~/.config/awesome/awesome-glorious-widgets
```

+ `require` it in your `rc.lua`.

`require('awesome-glorious-widgets.dynamic-wallpaper')`  


## Default wallpaper directory is in:  

`$HOME/.config/awesome/awesome-glorious-widgets/dynamic-wallpaper/wallpapers/`  


### Note:  
+ The widget computes the time difference between the scheduled time when the wallpaper will change next and the current time.
+ The difference, in seconds, will be use as timeout in a `gears.timer`.
+ There's currently four scheduled time, which is midnight, day, noon, and night.