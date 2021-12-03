#!/usr/bin/env bash

# install_docker.sh
# 
# install docker and docker-compose
# 
# created on : 2018.08.02.
# last update: 2021.12.03.
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
		# docker
		curl -sSL https://get.docker.com | bash && \
			sudo usermod -aG docker $USER && \
			info ">>> successfully installed docker!" && \
			warn ">>> now run: $ sudo systemctl enable docker && sudo systemctl start docker"

		# docker-compose
		sudo apt-get install -y python3-pip libffi-dev libssl-dev && \
			pip3 install docker-compose --user && \
			info ">>> successfully installed docker-compose"
	else  # termux
		error "* termux not supported yet."
	fi
}

case "$OSTYPE" in
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

