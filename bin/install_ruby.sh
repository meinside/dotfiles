#!/usr/bin/env bash

# install_ruby.sh
# 
# for setting up environment for ruby
# 
# last update: 2020.02.01.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

function install_linux {
	echo -e "${GREEN}>>> This script will help setting up rvm on this Raspberry Pi${RESET}\n"

	# install RVM for multi-users
	echo -e "${YELLOW}>>> installing RVM and Ruby for multi-users..${RESET}\n"
	curl -#L https://get.rvm.io | sudo bash -s stable --autolibs=3 --ruby

	# setting up permissions
	sudo /usr/sbin/usermod -a -G rvm $USER
	sudo chown root.rvm /etc/profile.d/rvm.sh

	# when stuck with permission problems, try:
	# $ rvmsudo rvm fix-permissions system

	# or retry after:
	# $ rvmsudo rvm cleanup all

	# re-login for loading rvm and installing ruby
	echo
	echo -e "${RED}*** logout, and login again for using Ruby ***${RESET}"
	echo
}

case "$OSTYPE" in
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

