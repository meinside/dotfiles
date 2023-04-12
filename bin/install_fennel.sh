#!/usr/bin/env bash

# bin/install_fennel.sh
#
# Install fennel script or binary.
#
# created on : 2021.11.24.
# last update: 2023.04.12.
#
# by meinside@duck.com


################################
#
# frequently updated values

# https://fennel-lang.org/setup#downloading-the-fennel-script
VERSION="1.3.0"	# XXX - edit for different version


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


INSTALLATION_PATH="/usr/local/bin/fennel"

# prep for linux
function prep_linux {
	# install essential packages
	if ! [ -x "$(which lua)" ]; then
		warn ">>> Installing essential packages..."

		if [ -x /usr/bin/apt-get ]; then
			sudo apt-get install -y lua5.3
		else
			error "* distro not supported"
		fi
	fi
}

# prep for termux
function prep_termux {
	# install essential packages
	warn ">>> Installing essential packages..."

	pkg install lua53
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
		*) error "* not supported yet: $machine" ;;
	esac

	if [ -x $INSTALLATION_PATH ]; then
		info ">>> successfully installed fennel at: ${INSTALLATION_PATH}"
	fi
}

# install for termux
function install_termux {
	# install script, and prepend shebang
	INSTALLATION_PATH="/data/data/com.termux/files/home/bin/fennel"
	wget "https://fennel-lang.org/downloads/fennel-${VERSION}" -O $INSTALLATION_PATH && \
		chmod +x $INSTALLATION_PATH && \
		sed -i 's/#!\/usr\/bin\/env/#!\/data\/data\/com.termux\/files\/usr\/bin\/env/' $INSTALLATION_PATH
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
		prep_termux && install_termux
	fi
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) error "* not supported yet: $OSTYPE" ;;
esac

