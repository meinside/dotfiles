#!/usr/bin/env bash

# prep.sh
# 
# for cloning config files from github, and setting up several things
#
# (https://raw.githubusercontent.com/meinside/rpi-configs/master/bin/prep.sh)
# 
# last update: 2021.09.08.
# 
# by meinside@gmail.com

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

if [ `whoami` == 'meinside' ]; then
	REPOSITORY="git@github.com:meinside/dotfiles.git"
else
	REPOSITORY="https://github.com/meinside/dotfiles.git"
fi
TMP_DIR="$HOME/configs.tmp"

echo -e "${GREEN}>>> This script will setup several things for you...${RESET}\n"

# authenticate for sudo if needed
sudo -l > /dev/null

# clone config files
if ! which git > /dev/null; then
	echo -e "${YELLOW}>>> installing git...${RESET}"
	sudo apt-get update
	sudo apt-get -y install git
fi
rm -rf $TMP_DIR
git clone $REPOSITORY $TMP_DIR

# move to $HOME directory
shopt -s dotglob nullglob
mv $TMP_DIR/* $HOME/
rm -rf $TMP_DIR

# install terminfos
~/bin/enable_italic_fonts.sh

# upgrade packages
echo -e "${YELLOW}>>> upgrading installed packages...${RESET}"
sudo apt-get update
sudo apt-get -y upgrade

# install other essential packages
echo -e "${YELLOW}>>> installing other essential packages...${RESET}"
sudo apt-get -y install zsh vim tmux mosh psmisc

# cleanup
echo -e "${YELLOW}>>> cleaning up...${RESET}"
sudo apt-get -y autoremove
sudo apt-get -y autoclean

# re-login for loading configs
echo
echo -e "${RED}*** logout, and login again for reloading configs ***${RESET}"
echo
