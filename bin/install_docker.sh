#!/usr/bin/env bash

# install_docker.sh
# 
# install docker and docker-compose
# 
# created on : 2018.08.02.
# last update: 2021.12.03.
# 
# by meinside@gmail.com

source ./common.sh

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

