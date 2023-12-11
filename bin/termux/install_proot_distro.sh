#!/usr/bin/env bash

# bin/termux/install_proot_distro.sh
#
# Install proot-distro on Termux.
#
# created on : 2023.12.11.
# last update: 2023.12.11.


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


function print_usage {
	info "Usage:" && \
		info "-- install and setup --" && \
		info "$ pd install ubuntu" && \
		info "$ pd login ubuntu" && \
		info "$ useradd -U -m USERNAME" && \
		info "$ exit" && \
		info "-- login with options --" && \
		info "$ pd login --user USERNAME --termux-home --shared-tmp ubuntu"
}


if [ -z "$TERMUX_VERSION" ]; then
	error "* proot-distro requires Termux"
else  # termux
	pkg install proot-distro && \
		print_usage
fi

