#!/usr/bin/env bash

# install_docker.sh
# 
# install docker and docker-compose
# 
# created on : 2018.08.02.
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
	# docker
	curl -sSL https://get.docker.com | bash && \
		sudo usermod -aG docker $USER && \
		echo -e "${GREEN}>>> Successfully installed docker!${RESET}" && \
		echo -e "${YELLOW}>>> Run: $ sudo systemctl enable docker && sudo systemctl start docker${RESET}"

	# docker-compose
	sudo apt-get install -y python-pip libffi-dev libssl-dev
	pip install docker-compose --user && \
		echo -e "${GREEN}>>> Successfully installed docker-compose${RESET}"
}

case "$OSTYPE" in
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

