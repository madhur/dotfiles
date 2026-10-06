#!/usr/bin/env bash

## pending
# nodejs, python, ruby, jekyll, java, Golang, docker is running
# copy id_rsa, id_rsa.pub to .ssh ..done
# export copyq preferences, not data
#verify drive mounting, service restart using polkit
# add sync method to sync configs
#verify java, add java installations
#verify rofi calculator
# setup jekyllss
#verify nginx and configs
#setup mongo and mysql

# Though we end up copying .gitconfig, we need this to perform git operations before copying .gitconfig
git config --global user.email ahuja.madhur@gmail.com
git config --global user.name "Madhur Ahuja"

# if username is other than `madhur`, replace in all relevant configs
find etc/polkit-1/localauthority/50-local.d/ -type f -exec sed -i "s/madhur/$USER/g" {} +
find etc/polkit-1/rules.d/ -type f -exec sed -i "s/madhur/$USER/g" {} +
find etc/systemd/system/ -type f -exec sed -i "s/madhur/$USER/g" {} +
find etc/lightdm/ -type f -exec sed -i "s/madhur/$USER/g" {} +
sed -i "s/madhur/$USER/g" home/madhur/.config/i3/config home/madhur/.config/jgmenu/custom.csv home/madhur/.config/conky/launch.sh 

#add user to wheel group
sudo usermod -a -G wheel $USER

#do not ask password for sudo
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER

timedatectl set-timezone Asia/Kolkata

# I really do not need ipv6, some apps dont work well with it
if [[ -f "/etc/sysctl.d/40-disable-ipv6.conf" ]]; then
    echo "sysctl exist"
else
    sudo cp etc/sysctl.d/* /etc/sysctl.d/
  
fi

if [[ ! -f "/etc/polkit-1/rules.d/50-default.rules" ]]; then
    sudo cp etc/polkit-1/rules.d/* /etc/polkit-1/rules.d/
else
   echo "polkit exist"
fi

if [[ ! -f "/etc/polkit-1/localauthority/50-local.d/10-mount-without-password.pkla" ]]; then
    sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
    sudo cp etc/polkit-1/localauthority/50-local.d/* /etc/polkit-1/localauthority/50-local.d/
else
    echo "localauthority exist"
fi


if [[ -f "/etc/redhat-release" ]]; then
    ./fedora_setup.sh
else
    ./arch_setup.sh
fi


# install oh my zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"  
else
    echo "oh my zsh exists"
fi

if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting exists"
fi

if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then    
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions exists"
fi


# Copy all config files and wallpapers
_config=${HOME}/.config/
home=${HOME}/
srcdir=home/madhur/.
#mkdir -p "$_config"
mkdir -p ${HOME}/bin
mkdir -p ${HOME}/logs
mkdir -p ${HOME}/scripts14
mkdir -p $home/Pictures/wallpapers
cp -r ${srcdir}     "$home"
sudo cp -r ./root/.bashrc		/root/
sudo chmod +x "$HOME"/bin/*


# Restore guake preferences
guake --restore-preferences ~/myguakeprefs 


# Setup look and feel, i3 bar, GTK themes and icons
mkdir -p $HOME/github/personal
mkdir -p $HOME/github/personal/site
cd $HOME/github/personal
git clone git@gitlab.com:cursors/simp1e.git
git clone git@github.com:greshake/i3status-rust.git
git clone git@github.com:jnsh/arc-theme.git
git clone git@github.com:vinceliuice/Qogir-theme.git
git clone git@github.com:vinceliuice/Qogir-icon-theme.git
git clone git@github.com:DeemOpen/zkui.git
git clone git@github.com:madhur/i3scripts.git
git clone -b source git@github.com:madhur/madhur.github.com.git

# Pillow is needed to build themes
python3 -m pip install --upgrade Pillow

cd ~/github/personal
cd i3status-rust
if [[ ! -f "$HOME/bin/i3status-rs" ]]; then
    cargo build
    cp target/debug/i3status-rs ~/bin/
else
    echo "i3status already installed"
fi

cd ~/github/personal
cd Qogir-theme
if [[ ! -d "$HOME/.themes/Qogir-Dark" ]]; then
    ./install.sh
else
    echo "Theme already installed"
fi
cd ~/github/personal
cd Qogir-icon-theme
if [[ ! -d "$HOME/.local/share/icons/Qogir-dark" ]]; then
    ./install.sh
else
    echo "Icon theme already installed"
fi
cd ~/github/personal
cd simp1e
if [[ ! -d "$HOME/.icons/Simp1e" ]]; then
    ./build.sh
    cp -r built_themes/ ~/.icons/
else
    echo "Cursor theme already installed"
fi

if [[ ! -f "~/github/personal/zkui/target/zkui-2.0-SNAPSHOT-jar-with-dependencies.jar" ]]; then
    cd ~/github/personal/zkui
    mvn clean package

else
    echo "zkui jar built"
fi

cd ~/github/personal

# Set default theme settings for gnome apps,  the same is reflected in gtk config files
gsettings set org.gnome.desktop.interface cursor-theme 'Simp1e-Tokyo-Night'
gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans 11'


# Install flatpak apps, mostly electron based gui apps
flatpak install -y com.belmoussaoui.Authenticator  com.getpostman.Postman com.github.finefindus.eyedropper  com.github.hluk.copyq  com.jetbrains.IntelliJ-IDEA-Community com.jetbrains.IntelliJ-IDEA-Ultimate com.jgraph.drawio.desktop com.simplenote.Simplenote com.slack.Slack com.sublimemerge.App io.dbeaver.DBeaverCommunity  io.github.peazip.PeaZip io.github.seadve.Kooha nl.hjdskes.gcolor3  org.apache.jmeter  org.apache.jmeter.Help org.flameshot.Flameshot  org.kde.kruler  org.qbittorrent.qBittorrent org.videolan.VLC 
sudo flatpak override --filesystem=$HOME/.themes
# Dark theme looks very bad on dbeaver
sudo flatpak override --env=GTK_THEME=Qogir-Light io.dbeaver.DBeaverCommunity
flatpak override --user --env=GTK_THEME=Qogir-Light io.dbeaver.DBeaverCommunity

# Install snap apps, which are not present in flathub
sudo snap install notion-snap trello-desktop sdlpop
sudo snap install sublime-merge --classic

# Install favorite dev tools
cd ~


curl -s "https://get.sdkman.io" | bash

# install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash

# install rvm
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable

# install starship
curl -sS https://starship.rs/install.sh | sh

#install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# note -  source will not work here
. ~/.bash_profile

sdk install java 8.0.302-open
sdk install java 11.0.12-open
nvm install --lts
rvm use ruby-2.7.2

sudo useradd zookeeper
sudo useradd prometheus
sudo useradd nginx

if [[ ! -d "$HOME/kafka_2.11-2.2." ]]; then 

    wget https://archive.apache.org/dist/kafka/2.2.1/kafka_2.11-2.2.1.tgz
    tar xvf kafka_2.11-2.2.1.tgz
    #sudo cp -r kafka_2.11-2.2.1 /opt/
    ln -s  kafka_2.11-2.2.1 kafka
else
    echo "kafka installed"
fi

if [[ ! -d "$HOME/apache-cassandra-3.11.14-bin" ]]; then

    rm -rf apache-cassandra-*
    wget https://dlcdn.apache.org/cassandra/3.11.14/apache-cassandra-3.11.11-bin.tar.gz
    tar xvf apache-cassandra-3.11.11-bin.tar.gz
    ln -s  apache-cassandra-3.11.11=bin cassandra
else
    echo "Cassandra installed"
fi

if [[ ! -d "$HOME/apache-tomcat-8.5.83" ]]; then
    rm -rf apache-tomcat-*
    wget https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.83/bin/apache-tomcat-8.5.83.tar.gz
    tar xvf apache-tomcat-8.5.83.tar.gz
    ln -s  apache-tomcat-8.5.83 tomcat8
else
    echo "Tomcat8 installed"
fi

if [[ ! -d "$HOME/prometheus-2.40.1.linux-amd64" ]]; then
    rm -rf prometheus-*
    wget https://github.com/prometheus/prometheus/releases/download/v2.40.1/prometheus-2.40.1.linux-amd64.tar.gz
    tar xvf prometheus-2.40.1.linux-amd64.tar.gz
    #sudo cp -r prometheus-2.40.1.linux-amd64 /opt/
    #sudo cp opt/prometheus/prometheus.yml /opt/prometheus/
    #sudo chown -R prometheus:prometheus /opt/prometheus-2.40.1.linux-amd64
    ln -s  prometheus-2.40.1.linux-amd64 prometheus
else
    echo "Prometheus installed"
fi


if [[ ! -d "/opt/apache-zookeeper-3.7.1-bin" ]]; then
    rm -rf apache-zookeeper-*
    wget https://dlcdn.apache.org/zookeeper/zookeeper-3.7.1/apache-zookeeper-3.7.1-bin.tar.gz
    tar xvf apache-zookeeper-3.7.1-bin.tar.gz
    #sudo cp -r apache-zookeeper-3.7.1-bin /opt/
    #sudo cp ~/github/personal/dotfiles/opt/zookeeper/conf/zoo.cfg /opt/apache-zookeeper-3.7.1-bin/conf/
    #sudo chown -R zookeeper:zookeeper /opt/apache-zookeeper-3.7.1-bin
    ln -s apache-zookeeper-3.7.1-bin  zookeeper
    sudo mkdir -p /var/zookeeper
    sudo chown -R madhur:madhur /var/zookeeper
else
    echo "Zookeeper installed"
fi

if [[ ! -d "$HOME/maven" ]]; then

    wget https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
    tar xvf apache-maven-3.6.3-bin.tar.gz
    ln -s apache-maven-3.6.3 maven
else
    echo "Maven installed"
fi

# create virtual pythonenv day to day usage
virtualenv ~/pyenv3 -p python3
source ~/pyenv3/bin/activate
pip3 install -r ~/github/personal/dotfiles/requirements.txt

# copy systemd files and other config files
cd ~/github/personal/dotfiles
sudo cp -r etc/systemd/system/. /etc/systemd/system/

sudo cp -r etc/nginx/. /etc/nginx/

# since we copied systemd files, we need to reload systemd
systemctl daemon-reload

# Enable dev services
systemctl enable nginx
systemctl enable zookeeper --user
systemctl enable prometheus --user
systemctl enable kafka --user
systemctl enable zkui --user

# Start services 
systemctl start nginx
systemctl start zookeeper --user
systemctl start prometheus --user
systemctl start kafka --user
systemctl start zkui --user

# Enable docker
sudo groupadd docker
sudo gpasswd -a $USER docker
sudo systemctl enable docker
sudo systemctl start docker

# Networking stuff
sudo systemctl disable firewalld
sudo systemctl disable NetworkManager-wait-online

# Enable lightdm
sudo cp -r etc/lightdm/. /etc/lightdm/
systemctl enable lightdm 
systemctl set-default graphical.target 

# increase amount of inotify watchers
sudo sh -c "echo fs.inotify.max_user_watches=524288 >> /etc/sysctl.conf"
sudo sysctl -p


sudo chmod +x "$HOME"/scripts/*

sudo chsh -s $(which zsh) $(whoami)




