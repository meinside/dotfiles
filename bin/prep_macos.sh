#!/usr/bin/env bash

# prep_macos.sh
# 
# for setting up various things automatically in macOS
# (https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep_macos.sh)
# 
# last update: 2020.02.01.
# 
# by meinside@gmail.com

if [ `whoami` == 'meinside' ]; then
	REPOSITORY="git@github.com:meinside/dotfiles.git"
else
	REPOSITORY="git://github.com/meinside/dotfiles.git"
fi
TMP_DIR="$HOME/configs.tmp"

echo -e "\033[32mThis script will setup various things for macOS\033[0m"

# clone config files
echo -e "\033[33m>>> cloning config files...\033[0m"
rm -rf $TMP_DIR
git clone $REPOSITORY $TMP_DIR
shopt -s dotglob nullglob
mv $TMP_DIR/* $HOME/
rm -rf $TMP_DIR

# install Homebrew
echo -e "\033[33m>>> installing Homebrew...\033[0m"
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# re-login for loading configs
echo
echo -e "\033[31m*** logout, and login again for reloading configs ***\033[0m"

