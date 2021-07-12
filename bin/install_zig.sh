#!/usr/bin/env bash

# install_zig.sh
#
# Install zig from binaries (https://github.com/ziglang/zig/releases)
#
# created on : 2021.03.17.
# last update: 2021.07.12.
#
# by meinside@gmail.com
#
# * To install nightly version:
#
# $ ./install_zig.sh --nightly

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

TEMP_DIR="/tmp"
INSTALLATION_DIR="/opt"

# XXX - edit these for installing other versions
ZIG_VERSION="0.7.1"
ZLS_VERSION="0.1.0"

PLATFORM=`uname -m`     # armv7l, armv6l, ...
case "$PLATFORM" in
	armv7*) PLATFORM="armv7a" ;;
esac

ZIG_BIN="${INSTALLATION_DIR}/zig/zig"
case "$OSTYPE" in
	darwin*) ZIG_BIN="/usr/local/bin/zig" ;;
esac

# $1: nightly or not
function install_macos {

	xcode-select --install

	if [[ $1 == "--nightly" ]]; then
		brew install zig --HEAD
	else
		brew install zig
	fi

	# install zls
	install_zls $1

}

# $1: nightly or not
function install_linux {

	if [[ $1 == "--nightly" ]]; then
		ZIG_VERSION="master"

		TAR_URL=$( curl -s https://ziglang.org/download/index.json | grep tarball | cut -d\" -f4 | grep linux | grep $PLATFORM | head -n 1 )
	else
		TAR_URL="https://github.com/ziglang/zig/releases/download/${ZIG_VERSION}/zig-linux-${PLATFORM}-${ZIG_VERSION}.tar.xz"
	fi

	ZIG_DIR="${INSTALLATION_DIR}/zig-${ZIG_VERSION}"

	echo -e "${YELLOW}>>> Installing zig-${PLATFORM}-${ZIG_VERSION}...${RESET}"

	# install the binary
	sudo mkdir -p "${ZIG_DIR}" && \
		wget -qO- "$TAR_URL" | sudo tar -xv -J --strip-components=1 -C $ZIG_DIR && \
		sudo chown -R "$USER" "${ZIG_DIR}" && \
		sudo ln -sfn "${ZIG_DIR}" "${INSTALLATION_DIR}/zig" && \
		echo -e "${GREEN}>>> Installed zig-${PLATFORM}-${ZIG_VERSION} on ${ZIG_DIR} ${RESET}"

	# install zls
	install_zls $1

}

# $1: nightly or not
function install_zls {

	ZLS_DIR="${INSTALLATION_DIR}/zls"

	if [[ $1 == "--nightly" ]]; then
		ZLS_VERSION="master"
	fi

	echo -e "${YELLOW}>>> Installing zls-${ZLS_VERSION}...${RESET}"

	sudo rm -rf "${ZLS_DIR}" && \
		sudo mkdir -p "${ZLS_DIR}" && \
		sudo chown -R "$USER" "${ZLS_DIR}" && \
		git clone --recurse-submodules https://github.com/zigtools/zls "${ZLS_DIR}" && \
		cd "${ZLS_DIR}" && \
		git checkout ${ZLS_VERSION} && \
		$ZIG_BIN build -Drelease-safe && \
		${ZLS_DIR}/zig-out/bin/zls config && \
		echo -e "${GREEN}>>> Installed zls-${ZLS_VERSION} on ${ZLS_DIR} ${RESET}"

}

case "$OSTYPE" in
	darwin*) install_macos $1 ;;
	linux*) install_linux $1 ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

