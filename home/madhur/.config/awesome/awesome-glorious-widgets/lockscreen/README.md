## A Lockscreen Module with PAM Integration

This is a lockscreen module with PAM integration. 

**The PAM integration was made possible by [RMTT](https://github.com/RMTT/)!** 

Lua-PAM's [Source code](https://github.com/RMTT/lua-pam)! Consider giving him a :star:!

![screenshot](lockscreen.png)

Instructions:

0. Clone the repo:

	```bash
	$ git clone --depth 1 https://github.com/manilarome/awesome-glorious-widgets ~/.config/awesome/
	```

1. Require it in your `rc.lua`.

	```lua
	require('awesome-glorious-widgets.lockscreen')
	```

2. Add keybinding:

	```lua
	    awful.key({ modkey }, "l", function() awful.spawn("awesome-client '_G.show_lockscreen()'", false) end,
              {description = "show the menubar", group = "launcher"})
    ```


More configuration:

Open the `awesome-glorious-widgets/lockscreen/init.lua`. Then, edit the theme variables and file directories if you want to. You can also change the profile picture.

If you found some bugs, please consider reporting it.

### More info

- Features:
	- PAM Integration
	- Face Capture (Enabled by default)
	- Dynamic Background (Enabled by default)

- Optional Depends:
	- `ffmpeg`
	- a webcam

- Features:
	- **PAM Integration!!!** Thanks to [RMTT](https://github.com/RMTT)'s contribution, the lockscreen now supports PAM!
	- Using `ffmpeg`, it captures a picture using your webcam if the password is wrong. (Enabled by default)
		- Will store the images to `$HOME/Pictures/Intruder/` folder.

- Keyboard Binding:
	- <kbd>Super + l</kbd> - lock the screen
	- <kbd>Control + u</kbd> or <kbd>Escape</kbd> - clear the typed password
	- <kbd>Return</kbd> - validate password

- Background modes
	- `blur` method uses `imagemagick`'s `convert` to blur the background. 
		- There's also a dynamic background functionality like the one with the `dynamic-wallpaper` module. It changes the blurred background image based on time. This is enabled by default. If disabled, it will use the default wallpaper. Configure it in `awesome-glorious-widgets/lockscreen/wallpapers/`.

	- `root` uses the root background/wallpaper as the lockscreen's background image.
	- `background` use the `beautiful.background` color as the background image. Use it with blur and transparency to make it more beautiful.