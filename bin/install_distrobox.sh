#!/usr/bin/env bash

# bin/install_distrobox.sh
#
# Install distrobox (https://distrobox.it/#installation)
#
# * create containers with custom home directories:
#
#	$ distrobox create -n ubuntu -i ubuntu:22.04 -H /path/to/distrobox/home \
#		--additional-packages "git"
#
# * and enter the containers with those home directories:
#
#	$ distrobox enter -nw ubuntu
#
# * then run:
#
#	$ wget -O - "https://raw.githubusercontent.com/meinside/dotfiles/master/bin/prep.sh" | bash
#
# created on : 2023.12.11.
# last update: 2023.12.14.


################################
#
# common functions and variables

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# functions for pretty-printing
function error {
	echo -e "${RED}$1${RESET}"
}
function info {
	echo -e "${GREEN}$1${RESET}"
}
function warn {
	echo -e "${YELLOW}$1${RESET}"
}

#
################################


DISTROBOX_PREFIX="$HOME/.local"

function install_termux {
	error "* in termux: use proot-distro instead"
}

function install_linux {
	if [[ $1 == "--uninstall" ]]; then
		# uninstall
		curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/uninstall | sh -s -- --prefix "$DISTROBOX_PREFIX"
	else
		# install
		curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "$DISTROBOX_PREFIX"
	fi
}

case "$OSTYPE" in
	linux-android) install_termux ;;
	linux*) install_linux "$1" ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

