#!/usr/bin/env bash

# Colors
B='\033[1m'        # bold
C='\033[36m'       # cyan
Y='\033[33m'       # yellow
G='\033[32m'       # green
R='\033[0m'        # reset
DIM='\033[2m'      # dim

print_cheatsheet() {
    clear
    echo -e "${B}${Y}  ZELLIJ CHEATSHEET ${R}"
    echo -e "${DIM}  ─────────────────────────────────────${R}"

    echo -e "\n${B}${C}  TABS${R}"
    echo -e "  ${G}Alt 1-9${R}      go to tab"
    echo -e "  ${G}Ctrl t → n${R}   new tab"
    echo -e "  ${G}Ctrl t → x${R}   close tab"
    echo -e "  ${G}Ctrl t → r${R}   rename tab"
    echo -e "  ${G}Alt i / o${R}    move tab left/right"

    echo -e "\n${B}${C}  PANES${R}"
    echo -e "  ${G}Ctrl p → r${R}   split right"
    echo -e "  ${G}Ctrl p → d${R}   split down"
    echo -e "  ${G}Ctrl p → x${R}   close pane"
    echo -e "  ${G}Ctrl p → f${R}   fullscreen"
    echo -e "  ${G}Ctrl p → w${R}   toggle floating"
    echo -e "  ${G}Ctrl p → e${R}   embed/float pane"
    echo -e "  ${G}Alt n${R}         new pane"
    echo -e "  ${G}Alt f${R}         toggle floating"

    echo -e "\n${B}${C}  NAVIGATION${R}"
    echo -e "  ${G}Alt h/j/k/l${R}  move between panes"
    echo -e "  ${G}Alt ←/→${R}      move focus or tab"

    echo -e "\n${B}${C}  RESIZE${R}"
    echo -e "  ${G}Ctrl n${R}        enter resize mode"
    echo -e "  ${G}h/j/k/l${R}      resize pane"
    echo -e "  ${G}H/J/K/L${R}      shrink pane"
    echo -e "  ${G}Alt +/-${R}       resize (anywhere)"

    echo -e "\n${B}${C}  SCROLL${R}"
    echo -e "  ${G}Alt s${R}         enter scroll mode"
    echo -e "  ${G}j / k${R}         scroll down/up"
    echo -e "  ${G}d / u${R}         half page down/up"
    echo -e "  ${G}Ctrl f/b${R}      full page down/up"
    echo -e "  ${G}s${R}             search"
    echo -e "  ${G}e${R}             open in editor"

    echo -e "\n${B}${C}  SESSION${R}"
    echo -e "  ${G}Ctrl o → w${R}   session manager"
    echo -e "  ${G}Ctrl o → d${R}   detach"
    echo -e "  ${G}Ctrl g${R}        lock mode"
    echo -e "  ${DIM}(Ctrl q unbound — conflicts with micro)${R}"

    echo -e "\n${DIM}  ─────────────────────────────────────${R}"
    echo -e "${DIM}  modes: Esc/Enter to exit${R}\n"
}

# Redraw on terminal resize
trap 'print_cheatsheet' WINCH

print_cheatsheet

# Keep pane alive
while true; do sleep 60; done
