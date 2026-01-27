#!/usr/bin/env bash

dfolder=$HOME/gitpersonal/dotfiles/home/madhur

# guake is deprecated
#guake --save-preferences ~/github/personal/dotfiles/home/madhur/myguakeprefs

rsync -avh --delete --exclude='.git/' ~/.config/conky $dfolder/.config/
#cp ~/.config/conky/* $dfolder/.config/conky/
cp -r ~/.config/dunst $dfolder/.config/
#cp -r ~/.config/gsimplecal $dfolder/.config/
cp -r ~/.config/gtk-{2,3,4}.0 $dfolder/.config/
#cp -r ~/.config/i3 $dfolder/.config/
#cp -r ~/.config/i3status-rust $dfolder/.config/
cp  ~/.config/jgmenu/* $dfolder/.config/jgmenu/
cp  ~/.config/cava/* $dfolder/.config/cava/
cp  ~/.config/zathura/* $dfolder/.config/zathura/
#cp  ~/.config/viewnior/* $dfolder/.config/viewnior/
#cp  ~/.config/micro/* $dfolder/.config/micro/
#rsync -avh --delete --exclude='.git/' ~/.config/eg $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/cheat/cheatsheets/personal $dfolder/.config/cheat/cheatsheets/personal/

cp  ~/.config/kafkactl/* $dfolder/.config/kafkactl/
cp ~/.config/kitty/* $dfolder/.config/kitty/
#cp -r ~/.config/neofetch $dfolder/.config/
cp -r ~/.config/picom $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/awesome $dfolder/.config/
#cp -r ~/.config/qtile $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/systemd $dfolder/.config/
#cp -r ~/.config/systemd $dfolder/.config/
# do not want rofi subfolder themes
rsync -avh --delete --exclude='.git/' ~/.config/rofi $dfolder/.config/
cp -r ~/.config/sxhkd $dfolder/.config/
rsync -avh --delete --exclude='.git/' ~/.config/eww $dfolder/.config/
cp -r ~/.config/qimgv $dfolder/.config/
cp -r ~/.config/ripgrep $dfolder/.config/
cp -r ~/.config/bat $dfolder/.config/
#cp -r ~/.config/btop $dfolder/.config/
cp -r ~/.config/mpv $dfolder/.config/
#cp -r ~/.config/newsboat $dfolder/.config/
cp -r ~/.config/Thunar $dfolder/.config/
cp -r ~/.config/autorandr $dfolder/.config/
cp -r ~/.config/glow $dfolder/.config/

rsync -avh --delete --exclude='.git/.' ~/.config/nvim $dfolder/.config/
rsync -avh --delete --exclude='.git/.' ~/.config/fontconfig $dfolder/.config/

cp -r ~/.config/starship.toml $dfolder/.config/
cp -r ~/.config/redshift.conf $dfolder/.config/

cp -r ~/.cache/wal $dfolder/.cache/
cp -r ~/.config/mimeapps.list $dfolder/.config/
cp ~/.config/nnn/config $dfolder/.config/nnn/
cp ~/.config/lazygit/config.yml $dfolder/.config/lazygit/

cp -r ~/.config/hypr $dfolder/.config/
cp -r ~/.config/nwg-look $dfolder/.config/
cp -r ~/.config/waybar $dfolder/.config/
cp
cp -r ~/.config/waypaper $dfolder/.config/
cp  ~/.rednotebook/configuration.cfg $dfolder/.rednotebook/configuration.cfg
cp -r ~/.rednotebook/templates $dfolder/.rednotebook/

cp -r ~/.task $dfolder/

#tmux contains company data
#cp -r ~/tmux $dfolder/

#Scripts contain company data
rsync -avh --delete  ~/scripts ./home/madhur/
cp -r ~/.bashrc $dfolder/
cp -r ~/.zshrc $dfolder/
cp -r ~/.zprofile $dfolder/
cp -r ~/.zlogin $dfolder/
cp -r ~/.xsettingsd $dfolder/
cp -r ~/.nanorc $dfolder/
cp -r ~/.taskrc $dfolder/
cp -r ~/.vimrc $dfolder/
cp -r ~/.Xresources $dfolder/
cp -r ~/.tmux.conf $dfolder/
cp -r ~/.gitconfig $dfolder/
cp -r ~/.gtkrc-2.0 $dfolder/
#cp ~/.stalonetrayrc $dfolder/
cp ~/.dir_colors $dfolder/
cp ~/.aliases $dfolder/
cp ~/.functions $dfolder/
# Backup user-level .desktop files
rsync -avh --delete --exclude='.git/' ~/.local/share/applications/ $dfolder/.local/share/applications/
# Backup flatpak user-level .desktop files
rsync -avh --delete --exclude='.git/' ~/.local/share/flatpak/exports/share/applications/ $dfolder/.local/share/flatpak/exports/share/applications/ 2>/dev/null || true


sudo cp /root/.bashrc $HOME/gitpersonal/dotfiles/root/
cp /etc/pacman.conf ./etc/pacman.conf
cp /etc/my.cnf ./etc/my.cnf
cp /etc/fstab ./etc/fstab
cp /etc/hosts ./etc/hosts
cp /etc/rc.local ./etc/rc.local
sudo cp /etc/default/* ./etc/default/
sudo cp /etc/ssh/sshd_config.d/* ./etc/ssh/sshd_config.d/
sudo cp /boot/grub/grub.cfg ./boot/grub/grub.cfg
sudo cp /etc/exports.d/* ./etc/exports.d/
sudo cp /etc/grafana.inci ./etc/grafana.ini
sudo cp -r /etc/X11/* ./etc/X11/
sudo cp -r /etc/conf.d/* ./etc/conf.d/
sudo cp -r /etc/lightdm/* ./etc/lightdm/
sudo cp /etc/logrotate.d/* ./etc/logrotate.d/
sudo cp /etc/doas.conf ./etc/doas.conf
#cp /etc/dnsmasq.conf ./etc/dnsmasq.conf
#cp /etc/resolvconf.conf ./etc/resolvconf.conf
#cp /etc/resolv.conf ./etc/resolv.conf

pacman -Qnqe > packages/pacman.txt
pacman -Qqem > packages/foreignpkglist.txt
snap list > packages/snap.txt
flatpak list > packages/flatpak.txt
dconf dump / > backups/dconf-backup.txt
gsettings list-recursively > backups/gsettings.txt

sudo chown -R madhur:madhur .

# echo "Encrypting sensitive files..."
# git add .gitattributes
# git-crypt lock
