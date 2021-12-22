#!/usr/bin/env bash

# install_zig.sh
#
# Install zig from binaries (https://github.com/ziglang/zig/releases)
#
# NOTE: currently not working for non-nightly versions (bootstrapping needed)
#
# created on : 2021.03.17.
# last update: 2021.12.22.
#
# by meinside@gmail.com
#
# * To install nightly version:
#
# $ ./install_zig.sh --nightly


################################
#
# frequently updated values

# XXX - edit these for installing other versions
ZIG_VERSION="0.9.0"
ZLS_VERSION="0.1.0"


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


TEMP_DIR="/tmp"
INSTALLATION_DIR="/opt"

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

    if [ -z $TERMUX_VERSION ]; then
	if [[ $1 == "--nightly" ]]; then
	    ZIG_VERSION="master"

	    TAR_URL=$( curl -s https://ziglang.org/download/index.json | grep tarball | cut -d\" -f4 | grep linux | grep $PLATFORM | head -n 1 )
	else
	    TAR_URL="https://github.com/ziglang/zig/releases/download/${ZIG_VERSION}/zig-linux-${PLATFORM}-${ZIG_VERSION}.tar.xz"
	fi

	ZIG_DIR="${INSTALLATION_DIR}/zig-${ZIG_VERSION}"

	warn ">>> installing zig-${PLATFORM}-${ZIG_VERSION}..."

	# install the binary
	sudo mkdir -p "${ZIG_DIR}" && \
	    wget -qO- "$TAR_URL" | sudo tar -xv -J --strip-components=1 -C $ZIG_DIR && \
	    sudo chown -R "$USER" "${ZIG_DIR}" && \
	    sudo ln -sfn "${ZIG_DIR}" "${INSTALLATION_DIR}/zig" && \
	    info ">>> installed zig-${PLATFORM}-${ZIG_VERSION} on ${ZIG_DIR}"

	# install zls
	install_zls $1
    else  # termux
	error "* termux not supported yet."
    fi

}

# $1: nightly or not
function install_zls {

    ZLS_DIR="${INSTALLATION_DIR}/zls"

    if [[ $1 == "--nightly" ]]; then
	ZLS_VERSION="master"
    fi

    warn ">>> installing zls-${ZLS_VERSION}..."

    sudo rm -rf "${ZLS_DIR}" && \
	sudo mkdir -p "${ZLS_DIR}" && \
	sudo chown -R "$USER" "${ZLS_DIR}" && \
	git clone --recurse-submodules https://github.com/zigtools/zls "${ZLS_DIR}" && \
	cd "${ZLS_DIR}" && \
	git checkout ${ZLS_VERSION} && \
	$ZIG_BIN build -Drelease-safe && \
	${ZLS_DIR}/zig-out/bin/zls config && \
	info ">>> installed zls-${ZLS_VERSION} on ${ZLS_DIR}"

}

case "$OSTYPE" in
    darwin*) install_macos $1 ;;
    linux*) install_linux $1 ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

