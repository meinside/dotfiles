#!/usr/bin/env bash

# install_rust.sh
# 
# Install Rust and its toolchain from rustup.rs.
#
# For rust-analyzer, (https://rust-analyzer.github.io/manual.html#installation)
#
# $ git clone https://github.com/rust-analyzer/rust-analyzer.git
# $ cd rust-analyzer/
# $ cargo xtask install --server
#
# created on : 2019.02.18.
# last update: 2021.12.03.
# 
# by meinside@gmail.com

source ./common.sh

function install_linux {
    if [ -z $TERMUX_VERSION ]; then
	curl https://sh.rustup.rs -sSf | sh
    else  # termux
	pkg install rust
    fi
}

function install_macos {
    brew install rustup-init
}

case "$OSTYPE" in
    darwin*) install_macos ;;
    linux*) install_linux ;;
    *) error "* not supported yet: $OSTYPE" ;;
esac

