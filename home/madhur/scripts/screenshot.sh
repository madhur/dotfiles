#!/usr/bin/env bash

# screenshots stuff
# TODO: docs

function help_and_exit {
    if [ -n "${1}" ]; then
        echo "${1}"
    fi
    cat <<-EOF
    Usage: scregcp [-h|-s] [<screenshots_base_folder>]

    Take screenshot of a whole screen or a specified region,
    save it to a specified folder (current folder is default)
    and copy it to a clipboard. 

       -h   - print help and exit
       -s   - take a screenshot of a screen region
EOF
    if [ -n "${1}" ]; then
        exit 1
    fi
    exit 0
}

if [ "${1}" == '-h'  ]; then
    help_and_exit
elif [ "${1:0:1}" == '-' ]; then
    if [ "${1}" != '-s' ]; then
        help_and_exit "error: unknown option ${1}"  
    fi
    base_folder="${2}"
else
    base_folder="${1}"
    params="-window root"
fi  

file_path=${base_folder}$( date '+%Y-%m-%d_%H-%M-%S' )_screenshot.png
import ${params} ${file_path}
xclip -selection clipboard -target image/png -i < ${file_path}

