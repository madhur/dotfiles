#!/bin/bash

#todo:
# cancel for tile functions
# determine what windows are maximized and re-max after the "window select" function
# determine what windows are non-resizable by the user so that the script doesn't resize them
# cascade also shaded windows

# which workspace we're on
function get_workspace {
	if [[ "$DTOP" == "" ]] ; then
		DTOP=`xdotool get_desktop`
	fi
}

function is_desktop {
	xwininfo -id "$*" | grep '"Desktop"'
	return "$?"
}

function get_visible_window_ids {
	if (( ${#WDOWS[@]} == 0 )) ; then
		WDOWS=(`xdotool search --desktop $DTOP --onlyvisible "" 2>/dev/null`)
	fi
}

function get_desktop_dim {
	#desktop dimensions
	if (( ${#DIM[@]} == 0 )) ; then
		DIM=(`wmctrl -d | egrep "^0" | sed 's/.*DG: \([0-9]*x[0-9]*\).*/\1/g' | sed 's/x/ /g'`)
	fi
}

function win_showdesktop {
	get_workspace
	get_visible_window_ids

	command="search --desktop $DTOP \"\""

	if (( ${#WDOWS[@]} > 0 )) ; then
		command="$command windowminimize %@"
	else
		command="$command windowraise %@"
	fi

	echo "$command" | xdotool -
}

function win_tile_two {
	get_desktop_dim
	wid1=`xdotool selectwindow 2>/dev/null`

	is_desktop "$wid1" && return

	wid2=`xdotool selectwindow 2>/dev/null`

	is_desktop "$wid2" && return

	half_w=`expr ${DIM[0]} / 2`

	commands="windowsize $wid1 $half_w ${DIM[1]}"
	commands="$commands windowsize $wid2 $half_w ${DIM[1]}"
	commands="$commands windowmove $wid1 0 0"
	commands="$commands windowmove $wid2 $half_w 0"
	commands="$commands windowraise $wid1"
	commands="$commands windowraise $wid2"

	wmctrl -i -r $wid1 -b remove,maximized_vert,maximized_horz
	wmctrl -i -r $wid2 -b remove,maximized_vert,maximized_horz

	echo "$commands" | xdotool -
}

function win_tile {
	get_workspace
	get_visible_window_ids

	(( ${#WDOWS[@]} < 1 )) && return;

	get_desktop_dim

	# determine how many rows and columns we need
	cols=`echo "sqrt(${#WDOWS[@]})" | bc`
	rows=$cols
	wins=`expr $rows \* $cols`

	if (( "$wins" < "${#WDOWS[@]}" )) ; then
		cols=`expr $cols + 1`
		wins=`expr $rows \* $cols`
		if (( "$wins" < "${#WDOWS[@]}" )) ; then
	    rows=`expr $rows + 1`
	    wins=`expr $rows \* $cols`
		fi
	fi

	(( $cols < 1 )) && cols=1;
	(( $rows < 1 )) && rows=1;

	win_w=`expr ${DIM[0]} / $cols`
	win_h=`expr ${DIM[1]} / $rows`

	# do tiling
	x=0; y=0; commands=""
	for window in ${WDOWS[@]} ; do
		wmctrl -i -r $window -b remove,maximized_vert,maximized_horz

		commands="$commands windowsize $window $win_w $win_h"
		commands="$commands windowmove $window `expr $x \* $win_w` `expr $y \* $win_h`"

		x=`expr $x + 1`
		if (( $x > `expr $cols - 1` )) ; then
	    x=0
	    y=`expr $y + 1`
		fi
	done

	echo "$commands" | xdotool -
}

function win_cascade {
	get_workspace
	get_visible_window_ids

	(( ${#WDOWS[@]} < 1 )) && return;

	x=0; y=0; commands=""
	for window in ${WDOWS[@]} ; do
		wmctrl -i -r $window -b remove,maximized_vert,maximized_horz

		commands="$commands windowsize $window 640 480"
		commands="$commands windowmove $window $x $y"

		x=`expr $x + 22`
	  y=`expr $y + 22`
	done

	echo "$commands" | xdotool -
}

function win_select {
	get_workspace
	get_visible_window_ids

	(( ${#WDOWS[@]} < 1 )) && return;

	# store window positions and widths
	i=0
	for window in ${WDOWS[@]} ; do
		GEO=`xdotool getwindowgeometry $window | grep Geometry | sed 's/.* \([0-9].*\)/\1/g'`;
		height[$i]=`echo $GEO | sed 's/\(.*\)x.*/\1/g'`
		width[$i]=`echo $GEO | sed 's/.*x\(.*\)/\1/g'`

		# ( xwininfo gives position not ignoring titlebars and borders, unlike xdotool )
		POS=(`xwininfo -stats -id $window | grep 'geometry ' | sed 's/.*[-+]\([0-9]*[-+][0-9*]\)/\1/g' | sed 's/[+-]/ /g'`)
		posx[$i]=${POS[0]}
		posy[$i]=${POS[1]}

		i=`expr $i + 1`
	done

	# tile windows
	win_tile

	# select a window
	wid=`xdotool selectwindow 2>/dev/null`

	is_desktop "$wid" && return

	# restore window positions and widths
	i=0; commands=""
	for (( i=0; $i<${#WDOWS[@]}; i++ )) ; do
		commands="$commands windowsize ${WDOWS[i]} ${height[$i]} ${width[$i]}"
		commands="$commands windowmove ${WDOWS[i]} ${posx[$i]} ${posy[$i]}"
	done

	commands="$commands windowraise $wid"

	echo "$commands" | xdotool -
}

for command in ${@} ; do
	if [[ "$command" == "tile" ]] ; then
		win_tile
	elif [[ "$command" == "select" ]] ; then
		win_select
	elif [[ "$command" == "tiletwo" ]] ; then
		win_tile_two
	elif [[ "$command" == "cascade" ]] ; then
		win_cascade
	elif [[ "$command" == "showdesktop" ]] ; then
		win_showdesktop
	fi
done