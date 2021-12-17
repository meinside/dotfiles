#!/usr/bin/env bash

# install_ruby.sh
# 
# for setting up environment for ruby
# 
# last update: 2021.12.17.
# 
# by meinside@gmail.com


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


function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	info ">>> this script will help setting up rvm on this machine."
	info

	# install RVM for multi-users
	warn ">>> installing RVM and ruby locally..."
	warn
	curl -#L https://get.rvm.io | bash -s stable --autolibs=3 --ruby && \
	    sudo /usr/sbin/usermod -a -G rvm $USER

	# when stuck with permission problems, try:
	# $ rvmsudo rvm fix-permissions system

	# or retry after:
	# $ rvmsudo rvm cleanup all

	# re-login for loading rvm and installing ruby
	error
	error "*** logout, and login again for using ruby ***"
	error
    else  # termux
	pkg install ruby
    fi
}

case "$OSTYPE" in
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

