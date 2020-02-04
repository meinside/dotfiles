#!/usr/bin/env bash

# install_rust.sh
# 
# Install Rust and its toolchain from rustup.rs
#
# * Add `export PATH=$PATH:$HOME/.cargo/bin` to the rc file.
# 
# created on : 2019.02.18.
# last update: 2020.02.04.
# 
# by meinside@gmail.com

# XXX - for making newly created files/directories less restrictive
umask 0022

function install_linux {
	curl https://sh.rustup.rs -sSf | sh
}

function install_macos {
	brew install rust
}

case "$OSTYPE" in
	darwin*) install_macos ;;
	linux*) install_linux ;;
	*) echo "* Unsupported os type: $OSTYPE" ;;
esac

