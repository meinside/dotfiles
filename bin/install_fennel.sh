#!/usr/bin/env bash

# install_fennel.sh
#
# Install fennel script or binary.
#
# created on : 2021.11.24.
# last update: 2021.11.24.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# XXX - edit for different version
VERSION="1.0.0"

INSTALLATION_PATH="/usr/local/bin/fennel"

# prep for linux
function prep_linux {
	# install essential packages
	echo -e "${YELLOW}>>> Installing essential packages...${RESET}"

	sudo apt-get install -y luajit
}

# install
function install {
	machine=$(uname -m)
	case $machine in
		aarch64) # install script
			sudo wget "https://fennel-lang.org/downloads/fennel-${VERSION}" -O $INSTALLATION_PATH && \
				sudo chmod +x $INSTALLATION_PATH
			;;
		armv7*) # install binary
			sudo wget "https://fennel-lang.org/downloads/fennel-${VERSION}-arm32" -O $INSTALLATION_PATH && \
				sudo chmod +x $INSTALLATION_PATH
			;;
		x86_64) # install binary
			sudo wget "https://fennel-lang.org/downloads/fennel-${VERSION}-x86_64" -O $INSTALLATION_PATH && \
				sudo chmod +x $INSTALLATION_PATH
			;;
		*) echo "* Not supported yet: $machine" ;;
	esac

	if [ -x $INSTALLATION_PATH ]; then
		echo -e "${GREEN}>>> Successfully installed fennel at: ${INSTALLATION_PATH}${RESET}"
	fi
}

# for macOS
function install_macos {
	brew install fennel
}

# for linux
function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		prep_linux && install
	else  # termux
		echo "* Termux not supported yet."
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

