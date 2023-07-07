#!/usr/bin/env bash

dfolder=$HOME/github/personal/dotfiles/home/madhur
guake --save-preferences ~/github/personal/dotfiles/home/madhur/myguakeprefs

cp ~/.config/conky/* $dfolder/.config/conky/
#cp -r ~/.config/dunst $dfolder/.config/
#cp -r ~/.config/gsimplecal $dfolder/.config/
cp -r ~/.config/gtk-{2,3,4}.0 $dfolder/.config/
#cp -r ~/.config/i3 $dfolder/.config/
#cp -r ~/.config/i3status-rust $dfolder/.config/
cp  ~/.config/jgmenu/* $dfolder/.config/jgmenu/
cp  ~/.config/cava/* $dfolder/.config/cava/
cp  ~/.config/zathura/* $dfolder/.config/zathura/
cp  ~/.config/viewnior/* $dfolder/.config/viewnior/
cp  ~/.config/micro/* $dfolder/.config/micro/
cp -r ~/.config/eg/ $dfolder/.config/
cp  ~/.config/kafkactl/* $dfolder/.config/kafkactl/
cp ~/.config/kitty/* $dfolder/.config/kitty/
cp -r ~/.config/neofetch $dfolder/.config/
cp -r ~/.config/picom $dfolder/.config/
#cp -r ~/.config/polybar $dfolder/.config/
#cp -r ~/.config/xmonad $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/xmonad $dfolder/.config/
#cp -r ~/.config/awesome $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/awesome $dfolder/.config/
cp -r ~/.config/qtile $dfolder/.config/
cp -r ~/.config/systemd $dfolder/.config/
# do not want rofi subfolder themes
cp ~/.config/rofi/* $dfolder/.config/rofi/
cp -r ~/.config/sxhkd $dfolder/.config/
cp -r ~/.config/eww $dfolder/.config/
cp -r ~/.config/starship.toml $dfolder/.config/
cp -r ~/.config/redshift.conf $dfolder/.config/
#cp -r ~/.config/betterlockscreenrc $dfolder/.config/
cp -r ~/.cache/wal $dfolder/.cache/
cp -r ~/.config/mimeapps.list $dfolder/.config/

#tmux contain company data
cp -r ~/tmux $dfolder/

#Scripts contain company data
rsync -avh --delete  ~/scripts ./home/madhur/
cp -r ~/.bashrc $dfolder/
cp -r ~/.zshrc $dfolder/
cp -r ~/.zprofile $dfolder/
cp -r ~/.zlogin $dfolder/
cp -r ~/.zshenv $dfolder/
cp -r ~/.xsettingsd $dfolder/
cp -r ~/.nanorc $dfolder/
cp -r ~/.vimrc $dfolder/
cp -r ~/.Xresources $dfolder/
cp -r ~/.tmux.conf $dfolder/
cp -r ~/Pictures/wallpapers $dfolder/Pictures/
#cp -r ~/.gitconfig $dfolder/
cp -r ~/.gtkrc-2.0 $dfolder/
#cp ~/.stalonetrayrc $dfolder/
cp ~/.dir_colors $dfolder/
cp ~/.aliases $dfolder/
cp ~/.functions $dfolder/


sudo cp /root/.bashrc $HOME/github/personal/dotfiles/root/
cp /etc/pacman.conf ./etc/pacman.conf
cp /etc/my.cnf ./etc/my.cnf
cp /etc/fstab ./etc/fstab

pacman -Qnqe > pacman.txt
pacman -Qqem > foreignpkglist.txt
