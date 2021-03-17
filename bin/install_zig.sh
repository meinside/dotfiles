#!/bin/bash

# install_zig.sh
#
# Install zig from binaries (https://github.com/ziglang/zig/releases)
#
# created on : 2021.03.17.
# last update: 2021.03.17.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TEMP_DIR="/tmp"
INSTALLATION_DIR="/opt"

# XXX - edit this for installing other versions
INSTALL_VERSION="0.7.1"

PLATFORM=`uname -m`     # armv7l, armv6l, ...
case "$PLATFORM" in
	armv7*) PLATFORM="armv7a" ;;
esac

function install_macos {

	xcode-select --install

	brew install zig

}

function install_linux {

	TAR_URL="https://github.com/ziglang/zig/releases/download/${INSTALL_VERSION}/zig-linux-${PLATFORM}-${INSTALL_VERSION}.tar.xz"
	ZIG_DIR="${INSTALLATION_DIR}/zig-${INSTALL_VERSION}"

	echo -e "${YELLOW}>>> Installing zig-${PLATFORM}-${INSTALL_VERSION}...${RESET}"

	# install the binary
	sudo mkdir -p "${ZIG_DIR}" && \
		wget -qO- "$TAR_URL" | sudo tar -xv -J --strip-components=1 -C $ZIG_DIR && \
		sudo ln -sfn "${ZIG_DIR}" "${INSTALLATION_DIR}/zig" && \
		echo -e "${GREEN}>>> Installed zig-${PLATFORM}-${INSTALL_VERSION} on ${ZIG_DIR} ${RESET}"

}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

