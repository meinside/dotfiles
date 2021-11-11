#!/usr/bin/env bash

# install_ruby.sh
# 
# for setting up environment for ruby
# 
# last update: 2021.11.11.
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
	if [ -z $TERMUX_VERSION ]; then
		echo -e "${GREEN}>>> This script will help setting up rvm on this machine.${RESET}\n"

		# install RVM for multi-users
		echo -e "${YELLOW}>>> Installing RVM and Ruby for multi-users..${RESET}\n"
		curl -#L https://get.rvm.io | bash -s stable --autolibs=3 --ruby && \
			sudo /usr/sbin/usermod -a -G rvm $USER

		# when stuck with permission problems, try:
		# $ rvmsudo rvm fix-permissions system

		# or retry after:
		# $ rvmsudo rvm cleanup all

		# re-login for loading rvm and installing ruby
		echo
		echo -e "${RED}*** logout, and login again for using Ruby ***${RESET}"
		echo
	else  # termux
		pkg install ruby
	fi
}

case "$OSTYPE" in
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

