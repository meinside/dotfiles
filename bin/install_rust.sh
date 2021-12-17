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
# last update: 2021.12.17.
# 
# by meinside@gmail.com


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

