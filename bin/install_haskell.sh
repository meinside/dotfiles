#!/usr/bin/env bash

# install_haskell.sh
#
# Install haskell and its tools.
# 
# created on : 2021.07.12.
# last update: 2021.07.12.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

function install_linux {
	# TODO: not working ok on aarch64
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

function install_macos {
	brew install haskell-stack

	stack update && stack upgrade
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

