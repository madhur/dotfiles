#!/usr/bin/env bash

sudo cp etc/yum.repos.d/kubernetes.repo /etc/yum.repos.d/
sudo cp etc/yum.repos.d/virtualbox.repo /etc/yum.repos.d/

sudo dnf -y install dnf-plugins-core

sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

sudo dnf install -y \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm && \
        echo "Added Non-Free Fedora Repositories"
 
   sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo  &&  \
        echo "Added Docker Repository"

sudo dnf -y groupinstall "Development Tools"
sudo dnf -y install direnv iftop ncdu exa arc-theme python3-pip nginx python3-virtualenv docker-ce docker-ce-cli containerd.io docker-compose-plugin zsh snapd picom conky i3-gaps rofi keychain  guake sxhkd thunar geany polybar dunst jgmenu feh xclip hddtemp  xsettingsd lxappearance sshpass stress lm_sensors cmake ansible gcc-c++ libXdamage-devel ncurses-devel freetype-devel  libXft-devel lua imlib2-devel lua-devel libcurl-devel telnet kernel-tools docker-compose docker  java-1.8.0-openjdk-headless.x86_64 postfix vsftpd redhat-lsb-core xset nvme-cli.x86_64 iotop seahorse htop startup-notification-devel xcb-util-devel xcb-util-cursor-devel  xcb-util-keysyms-devel  xcb-util-wm-devel xcb-util-xrm-devel libxkbcommon-devel libxkbcommon-x11-devel yajl-devel cairo-devel pango-devel perl-devel xclip expect python3-pip fzf autoconf automake gtk3-devel tmux  redshift-gtk jetbrains-mono-fonts --allowerasing --skip-broken

sudo dnf update --refresh -y

# dnf install lightdm -y 
 #   systemctl enable lightdm >> /tmp/install/graphic.logs
 #   systemctl set-default graphical.target >> /tmp/install/graphic.logs

echo "Installing Java Development Kit 1.8/11/latest"
sudo dnf install -y java-1.8.0-openjdk-devel.x86_64 java-11-openjdk-devel.x86_64 maven

sudo dnf install fedora-workstation-repositories
sudo dnf config-manager --set-enabled google-chrome

sudo dnf install google-chrome-stable

