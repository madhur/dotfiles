## Hot-corners module

Execute a command by moving your cursor to the screen edges.

![workflow](https://github.com/manilarome/awesome-glorious-widgets/blob/master/hot-corners/workflow.gif)

Instructions:

1. Create the hot-corners. Add it after your `wibar` or `wibox`

	```
	require('awesome-glorious-widgets.hot-corners')
	```

	> Why after `wibar`/`wibox`?

	So the hot-corners will be on top of them. Otherwise, your `wibar`/`wibox` will cover the hot-corners. But maybe you don't have to because I added I hack/workaround to fix this issue.

2. Change the execute time. Execute time is the time(in seconds) before executing the callback. Default is `0.50` seconds.

	```lua
	local execute_time = 0.50
	```

3. Change the callback for every hot-corners. You can leave them blank.

	```lua

	-- Add a callback for each hot-corner
	local tl_callback = function()
		naughty.notification({title = 'hot-corner', message='top left'})
	end

	local tr_callback = function()
		naughty.notification({title = 'hot-corner', message='top left'})
	end

	local br_callback = function()
		naughty.notification({title = 'hot-corner', message='top left'})
	end

	local bl_callback = function()
		naughty.notification({title = 'hot-corner', message='top left'})
	end
	```
