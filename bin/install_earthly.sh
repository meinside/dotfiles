#!/usr/bin/env bash

# install_earthly.sh
#
# install pre-built Earthly binary from: https://github.com/earthly/earthly/releases
#
# created on : 2021.07.15.
# last update: 2021.09.10.
#
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

# colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

PLATFORM=`uname -m`	# armv7l, armv6l, ...

# x86_64 = x64, aarch64 = arm64
case "$PLATFORM" in
	x86_64) PLATFORM="amd64" ;;
	aarch64) PLATFORM="arm64" ;;
	armv7*) PLATFORM="arm7" ;;
esac

function install_linux {
	if [ -z $TERMUX_VERSION ]; then
		sudo /bin/sh -c "wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-${PLATFORM} -O /usr/local/bin/earthly && chmod +x /usr/local/bin/earthly && /usr/local/bin/earthly bootstrap --with-autocomplete"
	else
		echo "${RED}* earthly doesn't support termux yet.${RESET}"
	fi
}

function install_macos {
	brew install earthly/earthly/earthly && \
		earthly bootstrap
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

